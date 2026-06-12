import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../data/live_chat_download_service.dart';

class LiveChatVideoScreen extends StatefulWidget {
  final String url;
  final String fileName;
  final String downloadDirectory;

  const LiveChatVideoScreen({
    super.key,
    required this.url,
    required this.fileName,
    this.downloadDirectory = '',
  });

  @override
  State<LiveChatVideoScreen> createState() => _LiveChatVideoScreenState();
}

class _LiveChatVideoScreenState extends State<LiveChatVideoScreen> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<String>? _errorSubscription;
  bool _downloading = false;
  bool _isLoading = true;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _errorSubscription = _player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _playbackError = 'Không thể phát video: $error';
        });
      }
    });
    unawaited(_initializePlayer());
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.open(Media(widget.url), play: false);
    } catch (error) {
      _playbackError = 'Không thể phát video: $error';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    unawaited(_errorSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final path = await const LiveChatDownloadService().download(
        url: widget.url.endsWith('/download')
            ? widget.url
            : '${widget.url}/download',
        fileName: widget.fileName,
        directory: widget.downloadDirectory,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã tải video: $path')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tải video thất bại: $error')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(widget.fileName),
        actions: [
          IconButton(
            tooltip: 'Tải video',
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _playbackError != null
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Text(
                  _playbackError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : Video(controller: _controller, controls: AdaptiveVideoControls),
      ),
    );
  }
}
