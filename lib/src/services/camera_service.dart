import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? cameraController;
  double _zoomLevel = 1.0;
  double get zoomLevel => _zoomLevel;

  // Store initialization settings for logging
  ResolutionPreset _resolutionPreset = ResolutionPreset.max;
  ImageFormatGroup? _imageFormatGroup;
  bool _enableAudio = false;

  // Track if focus point setting failed previously to avoid repeated attempts
  // Note: Disabled because focus point setting is not used
  // bool _focusPointSettingFailed = false;

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
    // Prefer the largest available resolution to better match portrait aspect
    _resolutionPreset = ResolutionPreset.max;
    _imageFormatGroup = imageFormatGroup;
    _enableAudio = false;
    // Reset focus point setting failure flag on re-initialization
    // Note: Disabled because focus point setting is not used
    // _focusPointSettingFailed = false;

    cameraController = CameraController(
      camera,
      _resolutionPreset,
      enableAudio: _enableAudio,
      imageFormatGroup: _imageFormatGroup,
    );

    await cameraController!.initialize();

    // Lock capture orientation to portrait to align preview with portrait layout
    try {
      await cameraController!
          .lockCaptureOrientation(DeviceOrientation.portraitUp);
      debugPrint('[initialize] Capture orientation locked to portrait');
    } catch (e) {
      debugPrint('[initialize] Error locking capture orientation: $e');
    }

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

    // macro mode を設定(moto g05 では動作しないのでコメントアウト)
    // await setMacroMode(true);

    try {
      await cameraController!.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('[initialize] Error setting exposure mode: $e');
    }

    try {
      // Set zoom level to 1x (no zoom)
      const zoomLevel = 1.0;
      await cameraController!.setZoomLevel(zoomLevel);
      _zoomLevel = zoomLevel;
      debugPrint('[initialize] Zoom level set to 1.0x(ズームレベルを1.0倍に設定)');
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

    // Add lensType if available (may be unknown on some devices)
    if (description.lensType != CameraLensType.unknown) {
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
    // Check if it's a front camera by comparing lensDirection string representation
    if (description.lensDirection.toString().contains('front')) {
      try {
        // Try to get zoom levels from CameraController if available
        // Note: CameraValue may not have zoom properties in camera 0.11.2
        debugPrint('[$context] Front Camera (Selfie) detected(セルフィーカメラが検出されました)');
      } catch (e) {
        debugPrint('[$context] Error logging front camera zoom: $e');
      }
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

    // Note: Focus point setting is disabled because many devices report support
    // but actually don't support metering points (AF/AE/AWB MeteringPoints).
    // Using continuous auto focus mode instead.
    /*
    // Try to set focus point if supported and not previously failed
    if (value.focusPointSupported && !_focusPointSettingFailed) {
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
        // Mark that focus point setting failed to avoid repeated attempts
        _focusPointSettingFailed = true;
        debugPrint('[triggerAutoFocus] Error setting focus point: $e(焦点ポイントの設定に失敗しました)');
        debugPrint('[triggerAutoFocus] Focus point setting will be skipped in future attempts(今後の試行では焦点ポイント設定をスキップします)');
        debugPrint('[triggerAutoFocus] Falling back to continuous auto focus mode(連続自動焦点モードに戻る)');
      }
    } else {
      if (_focusPointSettingFailed) {
        debugPrint('[triggerAutoFocus] Focus point setting previously failed, skipping attempt(焦点ポイント設定が以前に失敗したため、試行をスキップします)');
      } else {
        debugPrint('[triggerAutoFocus] Focus point not supported, using continuous auto focus(焦点ポイントがサポートされていないため、連続自動焦点モードを使用します)');
      }
    }
    */

    debugPrint('[triggerAutoFocus] Using continuous auto focus mode(連続自動焦点モードを使用します)');

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

    debugPrint('[captureImage] Starting image capture(画像キャプチャを開始します)');

    try {
      final extDir = await getApplicationDocumentsDirectory();
      final dirPath = '${extDir.path}/Pictures/flutter_test';
      await Directory(dirPath).create(recursive: true);

      debugPrint('[captureImage] Taking picture from camera(カメラから写真を撮影します)');
      // Capture image and save as PNG to avoid JPEG compression quality loss
      final picture = await cameraController!.takePicture();
      debugPrint('[captureImage] Picture taken, reading bytes(写真を撮影しました。バイトを読み取ります)');

      final imageBytes = await picture.readAsBytes();
      debugPrint('[captureImage] Image bytes read: ${imageBytes.length} bytes(画像バイトを読み取りました: ${imageBytes.length}バイト)');

      // Decode the image (may be JPEG from camera) and save as PNG
      debugPrint('[captureImage] Decoding image(画像をデコードします)');
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode captured image');
      }
      debugPrint('[captureImage] Image decoded: ${decodedImage.width}x${decodedImage.height}(画像をデコードしました: ${decodedImage.width}x${decodedImage.height})');

      final filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.png';
      debugPrint('[captureImage] Saving image to: $filePath(画像を保存します: $filePath)');
      File(filePath).writeAsBytesSync(img.encodePng(decodedImage));
      debugPrint('[captureImage] Image capture completed successfully(画像キャプチャが正常に完了しました)');

      return filePath;
    } catch (e) {
      debugPrint('[captureImage] Error during image capture: $e(画像キャプチャ中にエラーが発生しました: $e)');
      rethrow;
    }
  }

  /// Release camera resources (pause preview and stop image stream)
  /// This can be called after capture completion or when camera is no longer needed
  Future<void> releaseCamera() async {
    if (cameraController == null) {
      debugPrint('[releaseCamera] CameraController is already null(カメラコントローラーは既にnullです)');
      return;
    }

    try {
      debugPrint('[releaseCamera] Starting camera release(カメラの解放を開始します)');

      // Stop image stream if active
      if (cameraController!.value.isStreamingImages) {
        try {
          await cameraController!.stopImageStream();
          debugPrint('[releaseCamera] Image stream stopped(画像ストリームを停止しました)');
        } catch (e) {
          debugPrint('[releaseCamera] Error stopping image stream: $e(画像ストリームの停止中にエラーが発生しました: $e)');
        }
      } else {
        debugPrint('[releaseCamera] Image stream is not active, skipping stop(画像ストリームはアクティブではないため、停止をスキップします)');
      }

      // Pause preview if active
      if (!cameraController!.value.isPreviewPaused) {
        try {
          await cameraController!.pausePreview();
          debugPrint('[releaseCamera] Preview paused(プレビューを一時停止しました)');
        } catch (e) {
          debugPrint('[releaseCamera] Error pausing preview: $e(プレビューの一時停止中にエラーが発生しました: $e)');
        }
      } else {
        debugPrint('[releaseCamera] Preview is already paused, skipping(プレビューは既に一時停止されているため、スキップします)');
      }

      // Dispose controller to fully release camera resources
      try {
        await cameraController!.dispose();
        cameraController = null;
        debugPrint('[releaseCamera] Camera controller disposed(カメラコントローラーを破棄しました)');
      } catch (e) {
        debugPrint('[releaseCamera] Error disposing camera controller: $e(カメラコントローラーの破棄中にエラーが発生しました: $e)');
      }

      debugPrint('[releaseCamera] Camera released successfully(カメラの解放が正常に完了しました)');
    } catch (e) {
      debugPrint('[releaseCamera] Error releasing camera: $e(カメラの解放中にエラーが発生しました: $e)');
    }
  }

  void dispose() {
    debugPrint('[dispose] Disposing camera controller(カメラコントローラーを破棄します)');
    cameraController?.dispose();
    cameraController = null;
    debugPrint('[dispose] Camera controller disposed(カメラコントローラーを破棄しました)');
  }
}
