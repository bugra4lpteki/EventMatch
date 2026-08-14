import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';

class ImageScaleDialog extends StatefulWidget {
  final dynamic imageInput;

  const ImageScaleDialog({
    super.key,
    required this.imageInput,
  });

  static Future<XFile?> show(BuildContext context, dynamic imageInput) {
    return showDialog<XFile>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageScaleDialog(imageInput: imageInput),
    );
  }

  @override
  State<ImageScaleDialog> createState() => _ImageScaleDialogState();
}

class _ImageScaleDialogState extends State<ImageScaleDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  
  final BoxFit _selectedFit = BoxFit.cover;
  int _rotationQuarterTurns = 0;
  bool _isSaving = false;

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetTransform() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _rotationQuarterTurns = 0;
    });
  }

  Future<void> _captureAndSave() async {
    setState(() => _isSaving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Kırpma alanı yakalanamadı');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Görüntü veriye dönüştürülemedi');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final String fileName = 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.png';

      final XFile croppedFile = XFile.fromData(
        pngBytes,
        name: fileName,
        mimeType: 'image/png',
      );

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf kaydedilirken hata oluştu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildImageWidget() {
    Widget img;
    final input = widget.imageInput;

    if (input is XFile) {
      if (kIsWeb) {
        img = Image.network(input.path, fit: _selectedFit, errorBuilder: (c, e, s) => _errorWidget());
      } else {
        img = Image.file(File(input.path), fit: _selectedFit, errorBuilder: (c, e, s) => _errorWidget());
      }
    } else if (input is File) {
      img = Image.file(input, fit: _selectedFit, errorBuilder: (c, e, s) => _errorWidget());
    } else if (input is Uint8List) {
      img = Image.memory(input, fit: _selectedFit, errorBuilder: (c, e, s) => _errorWidget());
    } else if (input is String) {
      if (input.startsWith('http') || input.startsWith('blob:')) {
        img = Image.network(input, fit: _selectedFit, errorBuilder: (c, e, s) => _errorWidget());
      } else {
        img = Image.file(File(input), fit: _selectedFit, errorBuilder: (c, e, s) => _errorWidget());
      }
    } else {
      img = _errorWidget();
    }

    if (_rotationQuarterTurns != 0) {
      img = RotatedBox(
        quarterTurns: _rotationQuarterTurns,
        child: img,
      );
    }

    return img;
  }

  Widget _errorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          const Text('Fotoğraf yüklenemedi', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double maxAvailableHeight = screenSize.height * 0.55;
    final double frameWidth = (screenSize.width * 0.7).clamp(200.0, 280.0);
    final double frameHeight = (frameWidth * 1.3).clamp(240.0, maxAvailableHeight);

    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.crop, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Fotoğrafı Kırp',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ],
              ),
              Text(
                'Yakınlaştırıp sürükleyerek kırpma alanını ayarlayın.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Interactive Crop Box
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.8), width: 2),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          key: _cropKey,
                          child: Container(
                            color: Colors.black,
                            child: InteractiveViewer(
                              transformationController: _transformationController,
                              minScale: 0.5,
                              maxScale: 4.0,
                              clipBehavior: Clip.hardEdge,
                              child: Center(
                                child: _buildImageWidget(),
                              ),
                            ),
                          ),
                        ),
                        // Quick Action Icon Overlay (Rotate & Reset)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _rotateClockwise,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(Icons.rotate_right, color: Colors.white, size: 18),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _resetTransform,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                  ),
                                  child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _captureAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text(
                              'Kullan',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
