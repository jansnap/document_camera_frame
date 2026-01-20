import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import 'image_converter_service.dart';

class DocumentDetectionService {
  /// Optional callback to report image processing errors.
  final void Function(Object error)? onError;

  DocumentDetectionService({this.onError});

  late final ObjectDetector _objectDetector;
  bool _isDetectorInitialized = false;

  /// Initializes the object detector.
  /// Must be called before `processImage`.
  void initialize() {
    if (_isDetectorInitialized) return;
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: false,
      multipleObjects: false,
    );
    _objectDetector = ObjectDetector(options: options);
    _isDetectorInitialized = true;
  }

  /// Processes a single camera image to detect if a document is aligned within the given frame.
  ///
  /// Returns `true` if a document is detected and well-aligned, otherwise `false`.

  Future<bool> processImage({
    required CameraImage image,
    required CameraController cameraController,
    required BuildContext context,
    required double frameWidth,
    required double frameHeight,
    required int screenWidth,
    required int screenHeight,
    ValueChanged<String>? onStatusUpdated,
  }) async {
    if (!_isDetectorInitialized) {
      return false;
    }

    final inputImage = cameraImageToInputImage(image, cameraController);
    if (inputImage == null) {
      const errorMsg = 'Failed to convert CameraImage to InputImage.';
      onError?.call(Exception(errorMsg));
      return false;
    }

    try {
      final List<DetectedObject> objects = await _objectDetector.processImage(
        inputImage,
      );

      if (objects.isEmpty) {
        onStatusUpdated?.call('ドキュメントが見つかりません');
        return false;
      }

      final detectedObject = objects.first;
      final boundingBox = detectedObject.boundingBox;

      // Step 1: Determine the correct analysis dimensions based on image rotation.
      // We assume a portrait UI, so if the image buffer is wider than it is tall, it's been rotated.
      final bool isImageRotated = image.width > image.height;
      final int analysisWidth = isImageRotated
          ? image.height
          : image.width; // Should be 2160
      final int analysisHeight = isImageRotated
          ? image.width
          : image.height; // Should be 3840

      // Step 2: Calculate the crop area in the *same coordinate system* as the ML Kit output.
      // Adjust for preview letterboxing/cropping using the fitted preview height.
      final previewSize = cameraController.value.previewSize;
      final double previewAspectRatio = previewSize != null
          ? (previewSize.height / previewSize.width)
          : (analysisHeight / analysisWidth);
      final double displayWidth = screenWidth.toDouble();
      final double displayHeight = screenHeight.toDouble();
      final double fittedPreviewHeight = displayWidth / previewAspectRatio;
      final double verticalOffset = (fittedPreviewHeight - displayHeight) / 2;

      final int cropWidth =
          (frameWidth / displayWidth * analysisWidth).round();
      final int cropHeight =
          (frameHeight / fittedPreviewHeight * analysisHeight).round();

      final int cropX = (analysisWidth - cropWidth) ~/ 2;
      final double frameTopOnScreen = (displayHeight - frameHeight) / 2;
      final double frameTopOnPreview = frameTopOnScreen + verticalOffset;
      final int cropY =
          ((frameTopOnPreview / fittedPreviewHeight) * analysisHeight).round();

      // Step 3: Perform alignment checks in the consistent analysis coordinate system.
      final double objectArea = boundingBox.width * boundingBox.height;
      final double frameArea = (cropWidth * cropHeight)
          .toDouble(); // Use the calculated crop area

      // Size Alignment Check
      // Thresholds: lower bound 70% (was 60%), upper bound 98% (was 95%)
      final bool sizeAligned =
          objectArea > (0.70 * frameArea) && objectArea < (0.98 * frameArea);

      // Optional: give 5-10% tolerance
      final double frameTolerance = 0.05;

      final double relaxedFrameTop = cropY * (1 - frameTolerance);
      final double relaxedFrameBottom = (cropY + cropHeight) * (1 + frameTolerance);

      // Position Alignment Check
      final bool positionAligned =
          boundingBox.left >= cropX &&
          boundingBox.top >= relaxedFrameTop &&
          boundingBox.right <= (cropX + cropWidth) &&
          boundingBox.bottom <= relaxedFrameBottom;

      final bool isAligned = sizeAligned && positionAligned;

      // Log detection details
      final double sizeRatio = (objectArea / frameArea * 100);
      final double expectedLeft = cropX.toDouble();
      final double expectedTop = cropY.toDouble();
      final double expectedRight = (cropX + cropWidth).toDouble();
      final double expectedBottom = (cropY + cropHeight).toDouble();
      // debugPrint('[processImage] Document detection details(ドキュメント検出の詳細):');
      // debugPrint('[processImage]   Position: left=${boundingBox.left.toStringAsFixed(1)}, top=${boundingBox.top.toStringAsFixed(1)}, right=${boundingBox.right.toStringAsFixed(1)}, bottom=${boundingBox.bottom.toStringAsFixed(1)}(位置: left=${boundingBox.left.toStringAsFixed(1)}, top=${boundingBox.top.toStringAsFixed(1)}, right=${boundingBox.right.toStringAsFixed(1)}, bottom=${boundingBox.bottom.toStringAsFixed(1)})');
      debugPrint('[processImage]   Size: boundingBox.width=${boundingBox.width.toStringAsFixed(1)}, height=${boundingBox.height.toStringAsFixed(1)}, area=${objectArea.toStringAsFixed(1)}(サイズ: width=${boundingBox.width.toStringAsFixed(1)}, height=${boundingBox.height.toStringAsFixed(1)}, area=${objectArea.toStringAsFixed(1)})');
      // debugPrint('[processImage]   Frame: x=$cropX, y=$cropY, width=$cropWidth, height=$cropHeight, area=${frameArea.toStringAsFixed(1)}(フレーム: x=$cropX, y=$cropY, width=$cropWidth, height=$cropHeight, area=${frameArea.toStringAsFixed(1)})');
      debugPrint('[processImage]   Size ratio: ${sizeRatio.toStringAsFixed(1)}% (threshold: 70-98%)(サイズ比率: ${sizeRatio.toStringAsFixed(1)}% (閾値: 70-98%))');
      debugPrint('[processImage]   Size aligned: $sizeAligned, Position aligned: $positionAligned(サイズが合っている: $sizeAligned, 位置が合っている: $positionAligned)');
      debugPrint(
        '[processImage]   Expected position: '
        'left=${expectedLeft.toStringAsFixed(1)}, '
        'top=${expectedTop.toStringAsFixed(1)}, '
        'right=${expectedRight.toStringAsFixed(1)}, '
        'bottom=${expectedBottom.toStringAsFixed(1)}'
        '(期待位置)',
      );
      debugPrint(
        '[processImage]   Actual position: '
        'left=${boundingBox.left.toStringAsFixed(1)}, '
        'top=${boundingBox.top.toStringAsFixed(1)}, '
        'right=${boundingBox.right.toStringAsFixed(1)}, '
        'bottom=${boundingBox.bottom.toStringAsFixed(1)}'
        '(実際位置)',
      );
      // debugPrint('[processImage]   Result: ${isAligned ? "ALIGNED" : "NOT ALIGNED"}(結果: ${isAligned ? "位置が合っている" : "位置が合っていない"})');

      // Log adjustment directions if position is not aligned
      if (!positionAligned) {
        final List<String> adjustments = [];
        if (boundingBox.left < cropX) {
          adjustments.add('もっと右に');
        }
        if (boundingBox.right > (cropX + cropWidth)) {
          adjustments.add('もっと左に');
        }
        final bool isOverTop = boundingBox.top < relaxedFrameTop;
        final bool isOverBottom = boundingBox.bottom > (cropY + cropHeight);
        if (isOverTop && isOverBottom) {
          adjustments.add('上下どちらにもはみ出し');
        } else if (isOverTop) {
          adjustments.add('もっと下に');
        }
        if (!isOverTop && isOverBottom) {
          adjustments.add('もっと上に');
        }
        // if (adjustments.isNotEmpty) {
        //   debugPrint(
        //     '[processImage]   Adjustment needed(調整が必要): ${adjustments.join(', ')}',
        //   );
        // }
        _updateDetectionStatus(
          onStatusUpdated,
          isAligned: isAligned,
          adjustments: adjustments,
          sizeAligned: sizeAligned,
          objectArea: objectArea,
          frameArea: frameArea,
        );
      }

      // Log size adjustment directions if size is not aligned
      if (!sizeAligned) {
        if (objectArea < (0.70 * frameArea)) {
          debugPrint('[processImage]   Size adjustment needed(サイズ調整が必要): もっと近づけて');
        } else if (objectArea > (0.98 * frameArea)) {
          debugPrint('[processImage]   Size adjustment needed(サイズ調整が必要): もっと遠ざけて');
        }
      }

      if (positionAligned) {
        _updateDetectionStatus(
          onStatusUpdated,
          isAligned: isAligned,
          adjustments: const [],
          sizeAligned: sizeAligned,
          objectArea: objectArea,
          frameArea: frameArea,
        );
      }

      return isAligned;
    } catch (e) {
      onError?.call(e);
      return false;
    }
  }

  /// Closes the object detector and releases its resources.
  void dispose() {
    if (_isDetectorInitialized) {
      _objectDetector.close();
      _isDetectorInitialized = false;
    }
  }
}

void _updateDetectionStatus(
  ValueChanged<String>? onStatusUpdated, {
  required bool isAligned,
  required List<String> adjustments,
  required bool sizeAligned,
  required double objectArea,
  required double frameArea,
}) {
  if (onStatusUpdated == null) return;

  if (isAligned) {
    onStatusUpdated('位置が合っています');
    return;
  }

  String? sizeMessage;
  if (!sizeAligned) {
    if (objectArea < (0.70 * frameArea)) {
      sizeMessage = 'もっと近づけて';
    } else if (objectArea > (0.98 * frameArea)) {
      sizeMessage = 'もっと遠ざけて';
    }
  }

  final List<String> parts = [];
  if (adjustments.isNotEmpty) {
    parts.add('位置: ${adjustments.join('、')}');
  }
  if (sizeMessage != null) {
    parts.add('サイズ: $sizeMessage');
  }

  onStatusUpdated(parts.isEmpty ? '位置を調整してください' : parts.join(' / '));
}
