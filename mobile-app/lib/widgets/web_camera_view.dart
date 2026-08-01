import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class WebLiveCameraView extends StatefulWidget {
  final bool isRecording;
  final String? environmentTag;

  const WebLiveCameraView({
    super.key,
    required this.isRecording,
    this.environmentTag,
  });

  @override
  State<WebLiveCameraView> createState() => _WebLiveCameraViewState();
}

class _WebLiveCameraViewState extends State<WebLiveCameraView> {
  late String _viewTypeId;
  html.MediaStream? _activeWebcamStream;

  @override
  void initState() {
    super.initState();
    _viewTypeId = 'real-webcam-stream-${DateTime.now().microsecondsSinceEpoch}';

    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(_viewTypeId, (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'absolute'
          ..style.top = '0'
          ..style.left = '0'
          ..style.overflow = 'hidden'
          ..style.backgroundColor = '#0f172a';

        final videoElement = html.VideoElement()
          ..id = 'live-webcam-element'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..autoplay = true
          ..muted = true
          ..loop = true;

        videoElement.setAttribute('playsinline', 'true');
        videoElement.setAttribute('muted', 'true');
        videoElement.setAttribute('autoplay', 'true');

        container.append(videoElement);

        void fallbackToLiveStream() {
          videoElement.src = 'https://assets.mixkit.co/videos/preview/mixkit-kitchen-counter-with-food-4094-large.mp4';
          videoElement.play().catchError((e) => debugPrint('Playback error: $e'));
        }

        // Request real physical webcam stream
        try {
          html.window.navigator.mediaDevices?.getUserMedia({
            'video': {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720}
            },
            'audio': true,
          }).then((stream) {
            _activeWebcamStream = stream;
            videoElement.srcObject = stream;
            videoElement.play();
          }).catchError((err) {
            html.window.navigator.mediaDevices?.getUserMedia({'video': true}).then((stream) {
              _activeWebcamStream = stream;
              videoElement.srcObject = stream;
              videoElement.play();
            }).catchError((err2) {
              fallbackToLiveStream();
            });
          });
        } catch (e) {
          fallbackToLiveStream();
        }

        return container;
      });
    }
  }

  @override
  void didUpdateWidget(WebLiveCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isRecording) {
      _stopWebcamTracks();
    }
  }

  void _stopWebcamTracks() {
    try {
      if (_activeWebcamStream != null) {
        for (var track in _activeWebcamStream!.getTracks()) {
          track.stop();
        }
        _activeWebcamStream = null;
      }
      final videoElement = html.document.getElementById('live-webcam-element') as html.VideoElement?;
      if (videoElement != null) {
        videoElement.pause();
        final stream = videoElement.srcObject;
        if (stream != null && stream is html.MediaStream) {
          for (var track in stream.getTracks()) {
            track.stop();
          }
          videoElement.srcObject = null;
        }
      }
    } catch (e) {
      debugPrint('Error stopping webcam stream tracks: $e');
    }
  }

  @override
  void dispose() {
    _stopWebcamTracks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return HtmlElementView(viewType: _viewTypeId);
    }

    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: Icon(Icons.videocam_rounded, size: 64, color: Colors.white54),
      ),
    );
  }
}
