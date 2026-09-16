import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _downloadImage(BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'image',
                style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
      }
    }
  }

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
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Download button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
                onPressed: () => _downloadImage(context),
                tooltip: 'Télécharger',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
