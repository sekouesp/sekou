import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Affiche une photo en plein écran, zoomable (pincer) et fermable au tap.
/// Optionnellement animée via un Hero (même tag que la miniature source).
Future<void> showFullScreenPhoto(
  BuildContext context,
  String url, {
  String? heroTag,
}) {
  if (url.isEmpty) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _PhotoViewerPage(url: url, heroTag: heroTag),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _PhotoViewerPage extends StatelessWidget {
  final String url;
  final String? heroTag;
  const _PhotoViewerPage({required this.url, this.heroTag});

  @override
  Widget build(BuildContext context) {
    Widget image = InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
      ),
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(child: image),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
