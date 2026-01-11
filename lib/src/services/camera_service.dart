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

    // Set auto modes for optimal image quality
    try {
      await cameraController!.setFlashMode(FlashMode.auto);
    } catch (e) {
      debugPrint('[initialize] Error setting flash mode: $e');
    }

    try {
      await cameraController!.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint('[initialize] Error setting focus mode: $e');
    }

    try {
      await cameraController!.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('[initialize] Error setting exposure mode: $e');
    }

    // Log camera properties after initialization
    _logCameraProperties('After initialization');
  }

  /// Log camera properties for debugging
  /// Displays all camera properties in a compact format
  void _logCameraProperties(String context) {
    if (cameraController == null) {
      debugPrint('[$context] CameraController is null');
      return;
    }

    final value = cameraController!.value;

    // Log all properties in a compact format
    final properties = <String, dynamic>{
      'isInitialized': value.isInitialized,
      'isRecordingVideo': value.isRecordingVideo,
      'flashMode': value.flashMode.toString(),
      'exposureMode': value.exposureMode.toString(),
      'focusMode': value.focusMode.toString(),
      'exposurePointSupported': value.exposurePointSupported,
      'focusPointSupported': value.focusPointSupported,
      'previewSize': '${value.previewSize?.width}x${value.previewSize?.height}',
      'hasError': value.hasError,
    };

    if (value.hasError) {
      properties['errorDescription'] = value.errorDescription;
    }

    // Display properties in a compact format
    debugPrint('[$context] Camera Properties: ${properties.toString()}');
  }

  /// Triggers auto focus at the specified point (normalized coordinates 0.0-1.0)
  /// If no point is provided, focuses at the center (0.5, 0.5)
  /// Falls back to continuous auto focus if focus point setting is not supported
  Future<void> triggerAutoFocus([Offset? focusPoint]) async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      debugPrint('[triggerAutoFocus] Camera not initialized');
      return;
    }

    final value = cameraController!.value;
    final beforeFocus = value.focusMode;
    debugPrint('[triggerAutoFocus] Focus mode before: $beforeFocus');
    debugPrint('[triggerAutoFocus] Focus point supported: ${value.focusPointSupported}');

    // Try to set focus point if supported
    if (value.focusPointSupported) {
      try {
        // Focus at the specified point or center if not provided
        final point = focusPoint ?? const Offset(0.5, 0.5);
        debugPrint('[triggerAutoFocus] Setting focus point to: ($point)');

        await cameraController!.setFocusPoint(point);

        // Wait a bit for focus to update
        await Future.delayed(const Duration(milliseconds: 100));

        _logCameraProperties('After triggerAutoFocus');
        return;
      } catch (e) {
        debugPrint('[triggerAutoFocus] Error setting focus point: $e');
        debugPrint('[triggerAutoFocus] Falling back to continuous auto focus mode');
      }
    } else {
      debugPrint('[triggerAutoFocus] Focus point not supported, using continuous auto focus');
    }

    // Fallback: Ensure auto focus mode is set (continuous auto focus)
    // The camera will automatically focus continuously when in auto mode
    try {
      if (value.focusMode != FocusMode.auto) {
        debugPrint('[triggerAutoFocus] Setting focus mode to auto');
        await cameraController!.setFocusMode(FocusMode.auto);
        await Future.delayed(const Duration(milliseconds: 100));
        _logCameraProperties('After setting focus mode to auto');
      } else {
        debugPrint('[triggerAutoFocus] Focus mode is already auto, camera should auto-focus continuously');
        _logCameraProperties('Current camera state');
      }
    } catch (e) {
      debugPrint('[triggerAutoFocus] Error setting focus mode: $e');
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
