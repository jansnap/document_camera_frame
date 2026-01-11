import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? cameraController;

  bool get isInitialized =>
      cameraController != null && cameraController!.value.isInitialized;

  Future<void> initialize(
    CameraDescription camera, {
    ImageFormatGroup? imageFormatGroup,
  }) async {
    if (cameraController != null) {
      await cameraController!.dispose(); // Dispose only if it's already running
    }

    cameraController = CameraController(
      camera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup: imageFormatGroup,
    );

    await cameraController!.initialize();

    // Optional: Set flash mode
    await cameraController!.setFlashMode(FlashMode.auto);

    // Set auto focus mode
    await cameraController!.setFocusMode(FocusMode.auto);

    // Log camera properties after initialization
    _logCameraProperties('After initialization');
  }

  /// Log camera properties for debugging
  void _logCameraProperties(String context) {
    if (cameraController == null) {
      debugPrint('[$context] CameraController is null');
      return;
    }

    final value = cameraController!.value;
    debugPrint('[$context] Camera Properties:');
    debugPrint('  - isInitialized: ${value.isInitialized}');
    debugPrint('  - isRecordingVideo: ${value.isRecordingVideo}');
    debugPrint('  - flashMode: ${value.flashMode}');
    debugPrint('  - exposureMode: ${value.exposureMode}');
    debugPrint('  - focusMode: ${value.focusMode}');
    debugPrint('  - exposurePointSupported: ${value.exposurePointSupported}');
    debugPrint('  - focusPointSupported: ${value.focusPointSupported}');
    debugPrint('  - previewSize: ${value.previewSize}');
    debugPrint('  - hasError: ${value.hasError}');
    if (value.hasError) {
      debugPrint('  - errorDescription: ${value.errorDescription}');
    }
  }

  /// Triggers auto focus at the specified point (normalized coordinates 0.0-1.0)
  /// If no point is provided, focuses at the center (0.5, 0.5)
  Future<void> triggerAutoFocus([Offset? focusPoint]) async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      debugPrint('[triggerAutoFocus] Camera not initialized');
      return;
    }

    try {
      // Focus at the specified point or center if not provided
      final point = focusPoint ?? const Offset(0.5, 0.5);
      debugPrint('[triggerAutoFocus] Setting focus point to: ($point)');

      final beforeFocus = cameraController!.value.focusMode;
      debugPrint('[triggerAutoFocus] Focus mode before: $beforeFocus');
      debugPrint('[triggerAutoFocus] Focus point supported: ${cameraController!.value.focusPointSupported}');

      await cameraController!.setFocusPoint(point);

      // Wait a bit for focus to update
      await Future.delayed(const Duration(milliseconds: 100));

      _logCameraProperties('After triggerAutoFocus');
    } catch (e) {
      debugPrint('[triggerAutoFocus] Error setting focus point: $e');
      // Ignore errors if focus point setting is not supported
    }
  }

  Future<String> captureImage() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    final extDir = await getApplicationDocumentsDirectory();
    final dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);

    // Capture image and save as PNG to avoid JPEG compression quality loss
    final picture = await cameraController!.takePicture();
    final imageBytes = await picture.readAsBytes();

    // Decode the image (may be JPEG from camera) and save as PNG
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode captured image');
    }

    final filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.png';
    File(filePath).writeAsBytesSync(img.encodePng(decodedImage));

    return filePath;
  }

  void dispose() {
    cameraController?.dispose();
    cameraController = null;
  }
}
