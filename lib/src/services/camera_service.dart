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
      // Set focus mode to auto for continuous autofocus
      await cameraController!.setFocusMode(FocusMode.auto);
      // Wait a bit to ensure focus mode is applied
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('[initialize] Focus mode set to auto');
    } catch (e) {
      debugPrint('[initialize] Error setting focus mode: $e');
      // Try one more time
      try {
        await cameraController!.setFocusMode(FocusMode.auto);
        debugPrint('[initialize] Retry: Focus mode set to auto');
      } catch (e2) {
        debugPrint('[initialize] Error retrying focus mode: $e2');
      }
    }

    // Note: Macro mode (close-up photography) is typically handled automatically
    // by the camera hardware when focusing on close objects. Some devices may
    // support manual macro mode through FocusMode, but this is device-dependent.

    try {
      await cameraController!.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('[initialize] Error setting exposure mode: $e');
    }

    try {
      // Set zoom level to 2x
      await cameraController!.setZoomLevel(2.0);
      debugPrint('[initialize] Zoom level set to 2.0x(ズームレベルを2.0倍に設定)');
    } catch (e) {
      debugPrint('[initialize] Error setting zoom level: $e(ズームレベルの設定に失敗しました)');
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
      'minZoomLevel': value.minZoomLevel,
      'maxZoomLevel': value.maxZoomLevel,
      'zoomLevel': value.zoomLevel,
      'hasError': value.hasError,
      'deviceOrientation': value.deviceOrientation.toString(),
      'lockedCaptureOrientation': value.lockedCaptureOrientation?.toString(),
      'recordingOrientation': value.recordingOrientation?.toString(),
      'isPreviewPaused': value.isPreviewPaused,
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

    // Log zoom level specifically for front camera (selfie camera)
    if (description.lensDirection == LensDirection.front) {
      debugPrint('[$context] Front Camera (Selfie) Zoom Level: ${value.zoomLevel} (min: ${value.minZoomLevel}, max: ${value.maxZoomLevel})(セルフィーカメラのズームレベル: ${value.zoomLevel} (最小: ${value.minZoomLevel}, 最大: ${value.maxZoomLevel}))');
    }
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
        debugPrint('[setMacroMode] Macro mode enabled(有効) (if supported)');
      } else {
        // Return to auto focus mode
        await cameraController!.setFocusMode(FocusMode.auto);
        debugPrint('[setMacroMode] Macro mode disabled(無効), returning to auto focus(自動焦点に戻る)');
      }
    } catch (e) {
      debugPrint('[setMacroMode] Error setting macro mode: $e(マクロモードの設定に失敗しました)');
      debugPrint('[setMacroMode] Note: Macro mode may not be supported on this device(このデバイスではマクロモードがサポートされていない可能性があります: $e)');
      // Fallback to auto focus
      try {
        await cameraController!.setFocusMode(FocusMode.auto);
        debugPrint('[setMacroMode] Auto focus mode set(自動焦点モードに設定)');
      } catch (e2) {
        debugPrint('[setMacroMode] Error setting auto focus: $e2(自動焦点モードの設定に失敗しました)');
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
    debugPrint('[triggerAutoFocus] Focus mode before: $beforeFocus(焦点モードの前)');
    debugPrint('[triggerAutoFocus] Focus point supported: ${value.focusPointSupported}(焦点ポイントがサポートされています)');

    // Try to set focus point if supported
    if (value.focusPointSupported) {
      try {
        // Focus at the specified point or center if not provided
        final point = focusPoint ?? const Offset(0.5, 0.5);
        debugPrint('[triggerAutoFocus] Setting focus point to: ($point)(焦点ポイントを設定: $point)');

        await cameraController!.setFocusPoint(point);

        // Wait a bit for focus to update
        await Future.delayed(const Duration(milliseconds: 100));

        _logCameraProperties('After triggerAutoFocus(トリガー自動焦点の後)');
        return;
      } catch (e) {
        debugPrint('[triggerAutoFocus] Error setting focus point: $e(焦点ポイントの設定に失敗しました)');
        debugPrint('[triggerAutoFocus] Falling back to continuous auto focus mode(連続自動焦点モードに戻る)');
      }
    } else {
      debugPrint('[triggerAutoFocus] Focus point not supported, using continuous auto focus(焦点ポイントがサポートされていないため、連続自動焦点モードを使用します)');
    }

    // Fallback: Ensure auto focus mode is set (continuous auto focus)
    // Re-set focus mode to auto to ensure autofocus is active
    // Note: Some devices don't support setFocusMode, so we only try if focus mode is not already auto
    try {
      if (value.focusMode != FocusMode.auto) {
        debugPrint('[triggerAutoFocus] Setting focus mode to auto(焦点モードを自動に設定)');
        await cameraController!.setFocusMode(FocusMode.auto);
        await Future.delayed(const Duration(milliseconds: 100));
        debugPrint('[triggerAutoFocus] Focus mode set to auto(焦点モードを自動に設定)');
        _logCameraProperties('After setting focus mode to auto(焦点モードを自動に設定の後)');
      } else {
        debugPrint('[triggerAutoFocus] Focus mode is already auto - camera should auto-focus continuously(焦点モードはすでに自動であり、カメラは連続的に自動焦点を行う必要があります)');
        // Even if already auto, try to re-set to ensure it's active
        try {
          await cameraController!.setFocusMode(FocusMode.auto);
          await Future.delayed(const Duration(milliseconds: 100));
          debugPrint('[triggerAutoFocus] Re-set focus mode to auto to ensure activation(焦点モードを自動に再設定してアクティベーションを確実にする)');
        } catch (e) {
          debugPrint('[triggerAutoFocus] Note: Focus mode re-set failed (may not be supported), but mode is already auto: $e(焦点モードの再設定に失敗しました(サポートされていない可能性があります)、ただしモードはすでに自動です: $e)');
        }
      }
    } catch (e) {
      debugPrint('[triggerAutoFocus] Error setting focus mode: $e(焦点モードの設定に失敗しました)');
      debugPrint('[triggerAutoFocus] Note: This device may not support setFocusMode, but FocusMode.auto should still work(このデバイスではsetFocusModeがサポートされていない可能性がありますが、FocusMode.autoは依然として動作する必要があります)');
    }
  }

  Future<String> captureImage() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized(カメラが初期化されていません)');
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
