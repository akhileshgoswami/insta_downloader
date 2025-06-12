import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;

  const VideoPlayerScreen({Key? key, required this.filePath}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _fileExists = true;
  bool _showOverlay = false;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Storage permission denied")),
      );
      return;
    }

    final file = File(widget.filePath);
    if (!file.existsSync()) {
      setState(() {
        _fileExists = false;
      });
      return;
    }

    try {
      _videoController = VideoPlayerController.file(file);
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: false, // We'll use custom overlay
      );
      setState(() {});
    } catch (e) {
      print("Error initializing video: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load video")),
      );
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void togglePlayPause() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
    setState(() {
      _showOverlay = true;
    });
    _overlayTimer?.cancel();
    _overlayTimer = Timer(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  void shareVideo() {
    Share.shareXFiles(
      [XFile(widget.filePath)],
      text: 'Check out this video!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Video Player", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: !_fileExists
          ? Center(child: Text("File not found"))
          : _chewieController != null &&
                  _chewieController!.videoPlayerController.value.isInitialized
              ? GestureDetector(
                  onTap: togglePlayPause,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Chewie(controller: _chewieController!),
                      if (_showOverlay)
                        SafeArea(
                          child: Icon(
                            _videoController.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: Colors.deepPurple,
                            size: 80,
                          ),
                        ),
                    ],
                  ),
                )
              : Center(child: CircularProgressIndicator()),
      floatingActionButton: _fileExists
          ? FloatingActionButton(
              onPressed: shareVideo,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.share),
            )
          : null,
    );
  }
}
