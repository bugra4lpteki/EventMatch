import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/security_screen_service.dart';

/// Tek Seferlik (View-Once) Fotoğraf Görüntüleyici Ekranı.
/// Ekran görüntüsü ve ekran kaydını sistem düzeyinde (FLAG_SECURE) engeller,
/// uygulama arka plana alındığında ekranı karartır ve kapatıldığında fotoğrafı
/// geri dönülemez şekilde "Açıldı" olarak işaretler.
class ViewOnceViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String senderName;
  final String? caption;
  final VoidCallback onViewCompleted;

  const ViewOnceViewerScreen({
    super.key,
    required this.imageUrl,
    required this.senderName,
    this.caption,
    required this.onViewCompleted,
  });

  @override
  State<ViewOnceViewerScreen> createState() => _ViewOnceViewerScreenState();
}

class _ViewOnceViewerScreenState extends State<ViewOnceViewerScreen> with WidgetsBindingObserver {
  bool _isBackgrounded = false;
  bool _hasTriggeredCompletion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 1. Sistem düzeyinde ekran görüntüsü ve video kaydını engelle
    SecurityScreenService.instance.enableSecure();

    // 2. Fotoğraf görüntülendiği an geri dönülemez olarak açıldı sayılır
    _triggerCompletion();
  }

  void _triggerCompletion() {
    if (!_hasTriggeredCompletion) {
      _hasTriggeredCompletion = true;
      widget.onViewCompleted();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana veya çoklu görev (App Switcher) ekranına geçerse
    // ekran görüntüsü alınamaması için ekranı derhal gizle / kapat
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (mounted) {
        setState(() => _isBackgrounded = true);
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  void dispose() {
    _triggerCompletion();
    WidgetsBinding.instance.removeObserver(this);
    // Ekran korumasını kapat
    SecurityScreenService.instance.disableSecure();
    super.dispose();
  }

  Widget _buildImageWidget(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white60, size: 54),
            SizedBox(height: 12),
            Text('Fotoğraf yüklenemedi', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    } else if (trimmed.startsWith('data:image') || trimmed.startsWith('data:')) {
      try {
        final b64 = trimmed.contains(',') ? trimmed.split(',').last.trim() : trimmed;
        return Image.memory(base64Decode(b64), fit: BoxFit.contain);
      } catch (_) {
        return const Icon(Icons.broken_image_rounded, color: Colors.white60, size: 54);
      }
    } else {
      if (!kIsWeb) {
        try {
          final f = File(trimmed);
          if (f.existsSync()) {
            return Image.file(f, fit: BoxFit.contain);
          }
        } catch (_) {}
      }
      return const Icon(Icons.broken_image_rounded, color: Colors.white60, size: 54);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBackgrounded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Güvenlik nedeniyle gizlendi', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Fotoğraf Alanı (Pinch to Zoom destekli)
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: _buildImageWidget(widget.imageUrl),
              ),
            ),

            // Üst Kontrol ve Bilgi Çubuğu
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '①',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Tek Seferlik',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.senderName,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Alt Bilgi & Açıklama Çubuğu
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.caption != null && widget.caption!.trim().isNotEmpty && widget.caption != 'Tek Seferlik Fotoğraf')
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        widget.caption!,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Ekran görüntüsü ve kayıt engeli aktif',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
