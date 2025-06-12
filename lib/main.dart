import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File; // for mobile platforms only

import 'package:demoisolate/videoplayer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:google_fonts/google_fonts.dart';

import 'web_download_helper_stub.dart'
    if (dart.library.html) 'web_download_helper.dart';

/// Define VideoItem class to handle both web and mobile video sources
class VideoItem {
  final String? localPath; // for mobile downloaded file path
  final String? networkUrl; // for web direct URL
  final Uint8List? thumbnail; // thumbnail bytes

  VideoItem({this.localPath, this.networkUrl, this.thumbnail});
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final MaterialColor primarySwatch = Colors.deepPurple;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Instagram Video Downloader',
      theme: ThemeData(
        primarySwatch: primarySwatch,
        scaffoldBackgroundColor: Colors.grey.shade100,
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primarySwatch,
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),
      home: VideoDownloaderPage(),
    );
  }
}

class VideoDownloaderPage extends StatefulWidget {
  @override
  _VideoDownloaderPageState createState() => _VideoDownloaderPageState();
}

class _VideoDownloaderPageState extends State<VideoDownloaderPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';

  // Use VideoItem list for both web and mobile
  List<VideoItem> _videos = [];
  Map<String, Uint8List?> _thumbnailCache = {};

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadDownloadedVideosOrUrls();

    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  /// Load videos differently for Web vs Mobile
  Future<void> _loadDownloadedVideosOrUrls() async {
    if (kIsWeb) {
      // On web, no local videos - clear list
      setState(() {
        _videos = [];
        _thumbnailCache.clear();
      });
    } else {
      // On mobile, load videos from local storage directory
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.mp4'))
          .toList();

      setState(() {
        _videos = files.map((file) => VideoItem(localPath: file.path)).toList();
        _thumbnailCache.clear();
      });

      await _generateThumbnails();
    }
  }

  /// Generate thumbnails only for mobile local files (video_thumbnail package)
  Future<void> _generateThumbnails() async {
    for (var video in _videos) {
      if (video.localPath != null &&
          !_thumbnailCache.containsKey(video.localPath!)) {
        final thumb = await VideoThumbnail.thumbnailData(
          video: video.localPath!,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 75,
        );
        setState(() {
          _thumbnailCache[video.localPath!] = thumb;
        });
      }
    }
    _fadeController.forward();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      _urlController.text = data.text!;
    }
  }

  Future<void> extractVideoUrl(String postUrl) async {
    try {
      final response = await http.post(
        Uri.parse(
            "https://web-production-96da.up.railway.app/download_instagram"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"url": postUrl}),
      );

      if (response.statusCode != 200) {
        var result = jsonDecode(response.body);
        throw Exception(
            'HTTP error ${response.statusCode} ${result['error'] ?? ''}');
      }

      var result = jsonDecode(response.body);
      String videoUrl = result['video_url'].toString();

      if (kIsWeb) {
        // On web: DO NOT add video to _videos list to avoid playback or listing
        setState(() {
          _statusMessage = 'Video URL extracted, starting download...';
          _urlController.clear();
        });
        await downloadVideo(
          videoUrl,
          "insta_${DateTime.now().microsecondsSinceEpoch.toString()}",
        );
      } else {
        // On mobile: download video file locally
        await downloadVideo(
          videoUrl,
          "insta_${DateTime.now().microsecondsSinceEpoch.toString()}",
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = e.toString();
      });
      print("Error extracting video URL: $e");
    }
  }

  /// Download video function supporting both mobile and web

  Future<void> downloadVideo(String videoUrl, String fileName) async {
    if (kIsWeb) {
      // Web download
      try {
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode != 200) {
          setState(() {
            _statusMessage = "Failed to fetch video for download.";
          });
          return;
        }
        final bytes = response.bodyBytes;
        await downloadFileWeb(bytes, fileName);

        setState(() {
          _statusMessage = "Download started: $fileName.mp4";
          _urlController.clear();
        });
      } catch (e) {
        setState(() {
          _statusMessage = "Download failed: $e";
        });
      }
    } else {
      // Mobile platforms download
      final dio = Dio();
      final dir = await getApplicationDocumentsDirectory();
      final filePath = "${dir.path}/$fileName.mp4";

      try {
        await dio.download(videoUrl, filePath, onReceiveProgress: (rec, total) {
          if (total != -1) {
            setState(() {
              _statusMessage =
                  "Downloading: ${(rec / total * 100).toStringAsFixed(0)}%";
            });
          }
        });
        setState(() {
          _statusMessage = "Download completed: $fileName.mp4";
          _urlController.clear();
        });
        await _loadDownloadedVideosOrUrls();
      } on DioError catch (e) {
        setState(() {
          _statusMessage = "Download failed: ${e.message}";
        });
      }
    }
  }

  Future<void> handleDownload() async {
    final inputUrl = _urlController.text.trim();
    if (inputUrl.isEmpty || !inputUrl.startsWith('http')) {
      setState(() {
        _statusMessage = 'Please enter a valid URL.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting download...';
    });
    try {
      await extractVideoUrl(inputUrl);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildUrlInputField() {
    return TextField(
      controller: _urlController,
      decoration: InputDecoration(
        labelText: 'Instagram Post URL',
        suffixIcon: IconButton(
          icon: Icon(Icons.paste),
          tooltip: "Paste from clipboard",
          onPressed: _pasteFromClipboard,
        ),
        hintText: 'Paste Instagram video/reel URL here',
      ),
      keyboardType: TextInputType.url,
      autofillHints: [AutofillHints.url],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Instagram Video Downloader',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _buildUrlInputField(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : handleDownload,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _isLoading
                      ? SizedBox(
                          key: ValueKey('loader'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Download Video',
                          style: TextStyle(color: Colors.white),
                          key: ValueKey('text'),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.deepPurple.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _videos.isEmpty
                  ? Center(
                      child: Text(
                        kIsWeb
                            ? 'Downloaded videos are saved in your browser\'s Downloads folder.'
                            : 'No downloaded videos yet.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 9 / 16,
                        ),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          Uint8List? thumb;
                          if (kIsWeb) {
                            // On web: no videos shown, so this won't be called
                            thumb = null;
                          } else {
                            thumb = video.localPath != null
                                ? _thumbnailCache[video.localPath!]
                                : null;
                          }

                          return GestureDetector(
                            onTap: () {
                              if (kIsWeb) {
                                // Do nothing on web tap - no playback
                                setState(() {
                                  _statusMessage =
                                      "Video playback is not supported on web in this app.";
                                });
                                return;
                              } else {
                                // Mobile: play video if local path exists
                                if (video.localPath != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VideoPlayerScreen(
                                        filePath: video.localPath!,
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade300,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: thumb != null
                                    ? Image.memory(
                                        thumb,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          size: 48,
                                          color: Colors.deepPurple.shade300,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
