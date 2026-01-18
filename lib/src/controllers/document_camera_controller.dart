import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../services/camera_service.dart';
import '../services/image_processing_service.dart';

class DocumentCameraController {
  final CameraService _cameraService = CameraService();
  final ImageProcessingService _imageProcessingService =
      ImageProcessingService();
  String _imagePath = '';

  String get imagePath => _imagePath;
  int _currentCameraIndex = 0; // Track the current camera

  CameraController? get cameraController => _cameraService.cameraController;
  List<CameraDescription> cameras = [];

  ImageFormatGroup? _imageFormatGroup;

  Future<void> initialize(
    int cameraIndex, {
    ImageFormatGroup? imageFormatGroup,
  }) async {
    _imageFormatGroup = imageFormatGroup;

    cameras = await availableCameras(); // Load cameras only once
    if (cameras.isNotEmpty) {
      _currentCameraIndex = cameraIndex;
      await _cameraService.initialize(
        cameras[cameraIndex],
        imageFormatGroup: _imageFormatGroup,
      );
      // Trigger auto focus after initialization
      await _cameraService.triggerAutoFocus();
    }
  }

  Future<void> switchCamera() async {
    // Ensure multiple cameras exist
    if (cameras.isEmpty || cameras.length == 1) {
      return;
    }

    _currentCameraIndex =
        (_currentCameraIndex + 1) % cameras.length; // Toggle between cameras

    // Smooth transition: Pause before switching
    await cameraController?.pausePreview();
    await _cameraService.initialize(
      cameras[_currentCameraIndex],
      imageFormatGroup: _imageFormatGroup,
    );
    // Trigger auto focus after camera switch
    await _cameraService.triggerAutoFocus();
    await cameraController?.resumePreview(); // Resume after switching
  }

  /// Triggers auto focus at the specified point (normalized coordinates 0.0-1.0)
  /// If no point is provided, focuses at the center (0.5, 0.5)
  Future<void> triggerAutoFocus([Offset? focusPoint]) async {
    await _cameraService.triggerAutoFocus(focusPoint);
  }

  /// Sets macro mode for close-up photography (if supported by device)
  /// Note: Not all devices support manual macro mode. The camera may automatically
  /// switch to macro mode when focusing on close objects.
  Future<void> setMacroMode(bool enabled) async {
    await _cameraService.setMacroMode(enabled);
  }

  bool get isInitialized => _cameraService.isInitialized;

  Future<void> takeAndCropPicture(
    double frameWidth,
    double frameHeight,
    int screenWidth,
    int screenHeight,
  ) async {
    if (!_cameraService.isInitialized) {
      debugPrint('[takeAndCropPicture] Camera service not initialized(カメラサービスが初期化されていません)');
      return;
    }

    debugPrint('[takeAndCropPicture] Starting capture and crop(キャプチャとクロップを開始します)');
    debugPrint('[takeAndCropPicture] Frame: ${frameWidth}x${frameHeight}, Screen: ${screenWidth}x${screenHeight}(フレーム: ${frameWidth}x${frameHeight}, 画面: ${screenWidth}x${screenHeight})');

    try {
      final filePath = await _cameraService.captureImage();
      debugPrint('[takeAndCropPicture] Image captured, starting crop(画像をキャプチャしました。クロップを開始します)');

      _imagePath = _imageProcessingService.cropImageToFrame(
        filePath,
        frameWidth,
        frameHeight,
        screenWidth,
        screenHeight,
      );
      debugPrint('[takeAndCropPicture] Image cropped successfully(画像のクロップが正常に完了しました)');
    } catch (e) {
      debugPrint('[takeAndCropPicture] Error during capture and crop: $e(キャプチャとクロップ中にエラーが発生しました: $e)');
      rethrow;
    }
  }

  String saveImage() => imagePath;

  void retakeImage() => _imagePath = '';

  void resetImage() => _imagePath = '';

  /// Release camera resources (pause preview and stop image stream)
  /// This can be called after capture completion or when camera is no longer needed
  Future<void> releaseCamera() async {
    await _cameraService.releaseCamera();
  }

  void dispose() => _cameraService.dispose();
}
