import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;

  const VideoPlayerScreen({Key? key, required this.filePath}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showOverlay = false;
  Timer? _overlayTimer;
  bool _fileExists = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final permission = await Permission.storage.request();
    if (!permission.isGranted) {
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
      _controller = VideoPlayerController.file(file);
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.play(); // Auto play
    } catch (e) {
      print("Error initializing video: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load video")),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _showOverlay = true;
    });

    _overlayTimer?.cancel();
    _overlayTimer = Timer(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  void shareOnWhatsApp() {
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
          : _isInitialized
              ? GestureDetector(
                  onTap: togglePlayPause,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                      if (_showOverlay)
                        Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.deepPurple,
                          size: 80,
                        ),
                    ],
                  ),
                )
              : Center(child: CircularProgressIndicator()),
      floatingActionButton: _fileExists
          ? InkWell(
              onTap: shareOnWhatsApp,
              child: CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.share_rounded, color: Colors.white),
              ),
            )
          : null,
    );
  }
}
