import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
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
  }

  /// Triggers auto focus at the center of the frame
  Future<void> triggerAutoFocus() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Focus at the center point (0.5, 0.5)
      await cameraController!.setFocusPoint(const Point<double>(0.5, 0.5));
    } catch (e) {
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

    final filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final picture = await cameraController!.takePicture();
    await picture.saveTo(filePath);

    return filePath;
  }

  void dispose() {
    cameraController?.dispose();
    cameraController = null;
  }
}
