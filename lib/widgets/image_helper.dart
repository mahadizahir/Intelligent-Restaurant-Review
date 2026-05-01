// image_helper.dart
// ─────────────────────────────────────────────────────────────────────────────
// Picks images as Uint8List bytes — works on Web AND Mobile.
// KEY FIX: uses a Completer so the bottom sheet result is properly returned
// even after Navigator.pop() closes it.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageHelper {
  static final _picker = ImagePicker();

  // ── Core pick method — always returns bytes ────────────────────────────────
  static Future<Uint8List?> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return await picked.readAsBytes();
    } catch (e) {
      debugPrint('ImageHelper._pick error: $e');
      return null;
    }
  }

  // ── Public: pick from gallery (web + mobile) ───────────────────────────────
  static Future<Uint8List?> pickFromGallery() =>
      _pick(ImageSource.gallery);

  // ── Public: pick from camera (mobile only, web falls back to gallery) ──────
  static Future<Uint8List?> pickFromCamera() =>
      _pick(ImageSource.camera);

  // ── Show picker bottom sheet ───────────────────────────────────────────────
  // FIXED: uses Completer so the async result is captured correctly after
  // the sheet is dismissed.
  static Future<Uint8List?> showPickerSheet(BuildContext context) async {
    // On web, image_picker only supports gallery — show directly
    if (kIsWeb) {
      return await pickFromGallery();
    }

    // On mobile — show a sheet with Gallery / Camera options
    final completer = Completer<Uint8List?>();

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Photo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF0F0F0),
                child: Icon(Icons.photo_library_outlined,
                    color: Colors.black87),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx); // close sheet first
                pickFromGallery().then((bytes) {
                  if (!completer.isCompleted) completer.complete(bytes);
                });
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF0F0F0),
                child:
                    Icon(Icons.camera_alt_outlined, color: Colors.black87),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                pickFromCamera().then((bytes) {
                  if (!completer.isCompleted) completer.complete(bytes);
                });
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).then((_) {
      // If user dismissed without choosing, complete with null
      if (!completer.isCompleted) completer.complete(null);
    });

    return completer.future;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BytesImage widget
// Displays an image from Uint8List bytes with optional placeholder + border radius
// ─────────────────────────────────────────────────────────────────────────────
class BytesImage extends StatelessWidget {
  final Uint8List? bytes;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const BytesImage({
    super.key,
    required this.bytes,
    this.width = 70,
    this.height = 70,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (bytes != null && bytes!.isNotEmpty) {
      child = Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: fit,
        // Show placeholder while decoding
        frameBuilder: (ctx, img, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return img;
          return _buildPlaceholder();
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      child = _buildPlaceholder();
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: width, height: height, child: child),
      );
    }
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFF2F2F2),
          child: const Icon(Icons.restaurant_menu,
              color: Colors.grey, size: 30),
        );
  }
}