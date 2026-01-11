import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? cameraController;

  // Store initialization settings for logging
  ResolutionPreset _resolutionPreset = ResolutionPreset.ultraHigh;
  ImageFormatGroup? _imageFormatGroup;
  bool _enableAudio = false;

  bool get isInitialized =>
      cameraController != null && cameraController!.value.isInitialized;

  Future<void> initialize(
    CameraDescription camera, {
    ImageFormatGroup? imageFormatGroup,
  }) async {
    if (cameraController != null) {
      await cameraController!.dispose(); // Dispose only if it's already running
    }

    // Store initialization settings
    _resolutionPreset = ResolutionPreset.ultraHigh;
    _imageFormatGroup = imageFormatGroup;
    _enableAudio = false;

    cameraController = CameraController(
      camera,
      _resolutionPreset,
      enableAudio: _enableAudio,
      imageFormatGroup: _imageFormatGroup,
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

    // Note: Macro mode (close-up photography) is typically handled automatically
    // by the camera hardware when focusing on close objects. Some devices may
    // support manual macro mode through FocusMode, but this is device-dependent.

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
    final description = cameraController!.description;

    // Log CameraValue object completely
    debugPrint('[$context] CameraValue (complete): $value');

    // Log all properties in a compact format
    final properties = <String, dynamic>{
      'isInitialized': value.isInitialized,
      'isRecordingVideo': value.isRecordingVideo,
      'isStreamingImages': value.isStreamingImages,
      'flashMode': value.flashMode.toString(),
      'exposureMode': value.exposureMode.toString(),
      'focusMode': value.focusMode.toString(),
      'exposurePointSupported': value.exposurePointSupported,
      'focusPointSupported': value.focusPointSupported,
      'previewSize': '${value.previewSize?.width}x${value.previewSize?.height}',
      'hasError': value.hasError,
      'deviceOrientation': value.deviceOrientation.toString(),
      'lockedCaptureOrientation': value.lockedCaptureOrientation?.toString(),
      'recordingOrientation': value.recordingOrientation?.toString(),
      'isPreviewPaused': value.isPreviewPaused,
      'previewPausedOrientation': value.previewPausedOrientation?.toString(),
      // Camera description properties
      'cameraName': description.name,
      'lensDirection': description.lensDirection.toString(),
      'sensorOrientation': description.sensorOrientation,
    };

    // Add lensType if available (may not exist on all devices)
    if (description.lensType != null) {
      properties['lensType'] = description.lensType.toString();
    }

    // Add initialization settings
    properties['resolutionPreset'] = _resolutionPreset.toString();
    properties['enableAudio'] = _enableAudio;
    if (_imageFormatGroup != null) {
      properties['imageFormatGroup'] = _imageFormatGroup.toString();
    }

    if (value.hasError) {
      properties['errorDescription'] = value.errorDescription;
    }

    // Display properties in a compact format
    debugPrint('[$context] Camera Properties: ${properties.toString()}');
  }

  /// Sets macro mode for close-up photography (if supported by device)
  /// Note: Not all devices support manual macro mode. The camera may automatically
  /// switch to macro mode when focusing on close objects.
  Future<void> setMacroMode(bool enabled) async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      debugPrint('[setMacroMode] Camera not initialized');
      return;
    }

    try {
      // Try to set focus mode to locked for macro photography
      // Some devices may support this, but it's device-dependent
      if (enabled) {
        // Attempt to lock focus for close-up photography
        // This may not work on all devices
        await cameraController!.setFocusMode(FocusMode.locked);
        debugPrint('[setMacroMode] Macro mode enabled (if supported)');
      } else {
        // Return to auto focus mode
        await cameraController!.setFocusMode(FocusMode.auto);
        debugPrint('[setMacroMode] Macro mode disabled, returning to auto focus');
      }
    } catch (e) {
      debugPrint('[setMacroMode] Error setting macro mode: $e');
      debugPrint('[setMacroMode] Note: Macro mode may not be supported on this device');
      // Fallback to auto focus
      try {
        await cameraController!.setFocusMode(FocusMode.auto);
      } catch (e2) {
        debugPrint('[setMacroMode] Error setting auto focus: $e2');
      }
    }
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
