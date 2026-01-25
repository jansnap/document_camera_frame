import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessingService {
  String cropImageToFrame(
    String filePath,
    double frameWidth,
    double frameHeight,
    int effectiveDisplayWidth,
    int effectiveDisplayHeight, {
    int sensorOrientation = 0,
    int? previewWidth,
    int? previewHeight,
  }) {
    final File imageFile = File(filePath);
    final img.Image originalImage = img.decodeImage(
      imageFile.readAsBytesSync(),
    )!;

    debugPrint('[cropImageToFrame] Original image: ${originalImage.width}x${originalImage.height}(元の画像: ${originalImage.width}x${originalImage.height})');
    debugPrint('[cropImageToFrame] Sensor orientation: $sensorOrientation(センサー方向: $sensorOrientation)');

    // Step 1: Determine the correct analysis dimensions based on sensor orientation.
    // ML Kit returns bounding boxes in a coordinate system that accounts for sensor rotation.
    // When sensorOrientation is 90 or 270, ML Kit uses a rotated coordinate system.
    // The saved image file has pixel data in the original orientation (not rotated).
    final bool isSensorRotated = sensorOrientation == 90 || sensorOrientation == 270;
    // If the captured image is already portrait, the pixel data is upright,
    // so we should not apply an extra rotation mapping.
    final bool isCapturedPortrait = originalImage.height >= originalImage.width;
    final bool isImageRotated = isSensorRotated && !isCapturedPortrait;
    final int analysisWidth = isImageRotated
        ? originalImage.height
        : originalImage.width;
    final int analysisHeight = isImageRotated
        ? originalImage.width
        : originalImage.height;

    debugPrint('[cropImageToFrame] Analysis dimensions: ${analysisWidth}x${analysisHeight}, isRotated: $isImageRotated(分析 dimensions: ${analysisWidth}x${analysisHeight}, 回転: $isImageRotated)');
    debugPrint('[cropImageToFrame] Capture orientation check: isSensorRotated=$isSensorRotated, isCapturedPortrait=$isCapturedPortrait(回転判定: センサー回転=$isSensorRotated, 撮影画像縦=$isCapturedPortrait)');

    // Step 2: Calculate the crop area in the same coordinate system as document detection.
    // Adjust for preview letterboxing/cropping by using the fitted preview height.
    final double displayWidthDouble = effectiveDisplayWidth.toDouble();
    final double displayHeightDouble = effectiveDisplayHeight.toDouble();
    final double previewAspectRatio = (previewWidth != null && previewHeight != null)
        ? (previewHeight / previewWidth)
        : (analysisHeight / analysisWidth);
    final double fittedPreviewHeight = displayWidthDouble / previewAspectRatio;
    final double verticalOffset = (fittedPreviewHeight - displayHeightDouble) / 2;
    debugPrint(
      '[cropImageToFrame] Preview mapping: preview=${previewWidth ?? 0}x${previewHeight ?? 0}, '
      'aspectRatio=${previewAspectRatio.toStringAsFixed(4)}, '
      'fittedH=${fittedPreviewHeight.toStringAsFixed(1)}, '
      'offsetY=${verticalOffset.toStringAsFixed(1)}, '
      'display=${displayWidthDouble.toStringAsFixed(1)}x${displayHeightDouble.toStringAsFixed(1)}',
    );

    // Keep crop strictly within the frame (no margin expansion).
    const double marginFactor = 0.0;
    final int baseCropWidth =
        (frameWidth / displayWidthDouble * analysisWidth).round();
    final int baseCropHeight =
        (frameHeight / fittedPreviewHeight * analysisHeight).round();

    // Expand width and height by adding margins
    final int cropWidth = (baseCropWidth * (1 + marginFactor * 2)).round();
    final int cropHeight = (baseCropHeight * (1 + marginFactor * 2)).round();

    // Adjust position to center the expanded crop area
    // Ensure crop area doesn't exceed image bounds
    final int maxCropWidth = analysisWidth;
    final int maxCropHeight = analysisHeight;
    final int finalCropWidth = cropWidth > maxCropWidth ? maxCropWidth : cropWidth;
    final int finalCropHeight = cropHeight > maxCropHeight ? maxCropHeight : cropHeight;

    final int cropX = (analysisWidth - finalCropWidth) ~/ 2;
    final double frameTopOnScreen = (displayHeightDouble - frameHeight) / 2;
    final double frameTopOnPreview = frameTopOnScreen + verticalOffset;
    final int cropY = ((frameTopOnPreview / fittedPreviewHeight) * analysisHeight).round();

    // No extra expansion beyond the frame.
    const double verticalExpandFactor = 0.0;
    const double horizontalExpandFactor = 0.0;
    final int extraTopPixels = (finalCropHeight * verticalExpandFactor).round();
    final int extraBottomPixels =
        (finalCropHeight * verticalExpandFactor).round();
    final int extraLeftPixels = (finalCropWidth * horizontalExpandFactor).round();
    final int extraRightPixels =
        (finalCropWidth * horizontalExpandFactor).round();

    final int expandedCropY = (cropY - extraTopPixels) < 0
        ? 0
        : (cropY - extraTopPixels);
    final int expandedCropX = (cropX - extraLeftPixels) < 0
        ? 0
        : (cropX - extraLeftPixels);

    final int maxExpandedHeight = maxCropHeight - expandedCropY;
    final int maxExpandedWidth = maxCropWidth - expandedCropX;
    final int expandedCropHeight =
        (finalCropHeight + extraTopPixels + extraBottomPixels) >
                maxExpandedHeight
            ? maxExpandedHeight
            : (finalCropHeight + extraTopPixels + extraBottomPixels);
    final int expandedCropWidth =
        (finalCropWidth + extraLeftPixels + extraRightPixels) >
                maxExpandedWidth
            ? maxExpandedWidth
            : (finalCropWidth + extraLeftPixels + extraRightPixels);

    debugPrint('[cropImageToFrame] Crop area (analysis coords): x=$expandedCropX, y=$expandedCropY, w=$expandedCropWidth, h=$expandedCropHeight(クロップ領域(分析座標): x=$expandedCropX, y=$expandedCropY, w=$expandedCropWidth, h=$expandedCropHeight)');

    // Step 3: Convert coordinates from analysis coordinate system to original image coordinate system.
    // ML Kit returns bounding boxes in the rotated coordinate system (analysis coordinates).
    // We need to convert back to the original image pixel coordinates.
    final int actualCropX;
    final int actualCropY;
    final int actualCropWidth;
    final int actualCropHeight;

    if (isImageRotated) {
      // For rotated images, convert analysis coordinates to original image coordinates.
      // ML Kit returns bounding boxes in the rotated coordinate system (analysis coordinates).
      // The saved image file has pixel data in the original orientation (not rotated).
      //
      // When image is rotated 90 degrees clockwise (sensorOrientation 90):
      // - Analysis coordinate (x, y) maps to Original coordinate (y, originalHeight - x - width)
      // - Analysis width/height swap to Original height/width
      //
      // When image is rotated 270 degrees (sensorOrientation 270):
      // - Analysis coordinate (x, y) maps to Original coordinate (originalWidth - y - height, x)
      // - Analysis width/height swap to Original height/width

      if (sensorOrientation == 90) {
        // 90-degree clockwise rotation
        // Analysis coordinate system: (0,0) at top-left of rotated view
        // Original image: pixel data is not rotated
        // Analysis (cropX, cropY) -> Original (cropY, analysisHeight - cropX - finalCropWidth)
        // Note: analysisHeight = originalImage.width when rotated
        actualCropX = expandedCropY;
        actualCropY = originalImage.height - expandedCropX - expandedCropWidth;
        actualCropWidth = expandedCropHeight;
        actualCropHeight = expandedCropWidth;
      } else if (sensorOrientation == 270) {
        // 270-degree counter-clockwise rotation
        // Analysis (cropX, cropY) -> Original (analysisWidth - cropY - finalCropHeight, cropX)
        // Note: analysisWidth = originalImage.height when rotated
        actualCropX = originalImage.width - expandedCropY - expandedCropHeight;
        actualCropY = expandedCropX;
        actualCropWidth = expandedCropHeight;
        actualCropHeight = expandedCropWidth;
      } else {
        // Default: assume 90-degree rotation (most common)
        // Use analysis dimensions for coordinate conversion
        actualCropX = expandedCropY;
        actualCropY = originalImage.height - expandedCropX - expandedCropWidth;
        actualCropWidth = expandedCropHeight;
        actualCropHeight = expandedCropWidth;
      }
    } else {
      // No rotation: coordinates are the same
      actualCropX = expandedCropX;
      actualCropY = expandedCropY;
      actualCropWidth = expandedCropWidth;
      actualCropHeight = expandedCropHeight;
    }

    debugPrint('[cropImageToFrame] Crop area (original coords): x=$actualCropX, y=$actualCropY, w=$actualCropWidth, h=$actualCropHeight(クロップ領域(元の座標): x=$actualCropX, y=$actualCropY, w=$actualCropWidth, h=$actualCropHeight)');

    // Ensure crop coordinates are within image bounds
    final int safeCropX = actualCropX.clamp(0, originalImage.width - 1);
    final int safeCropY = actualCropY.clamp(0, originalImage.height - 1);
    final int safeCropWidth = actualCropWidth.clamp(1, originalImage.width - safeCropX);
    final int safeCropHeight = actualCropHeight.clamp(1, originalImage.height - safeCropY);

    if (safeCropX != actualCropX || safeCropY != actualCropY ||
        safeCropWidth != actualCropWidth || safeCropHeight != actualCropHeight) {
      debugPrint('[cropImageToFrame] Warning: Crop coordinates adjusted to fit image bounds(警告: クロップ座標が画像境界に合わせて調整されました)');
      debugPrint('[cropImageToFrame]   Original: x=$actualCropX, y=$actualCropY, w=$actualCropWidth, h=$actualCropHeight');
      debugPrint('[cropImageToFrame]   Adjusted: x=$safeCropX, y=$safeCropY, w=$safeCropWidth, h=$safeCropHeight');
    }

    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: safeCropX,
      y: safeCropY,
      width: safeCropWidth,
      height: safeCropHeight,
    );

    debugPrint('[cropImageToFrame] Cropped image: ${croppedImage.width}x${croppedImage.height}(クロップ後の画像: ${croppedImage.width}x${croppedImage.height})');

    // Replace file extension with .png for lossless image quality
    final int lastDotIndex = filePath.lastIndexOf('.');
    final String basePath = lastDotIndex >= 0
        ? filePath.substring(0, lastDotIndex)
        : filePath;
    final String croppedFilePath = '${basePath}_cropped.png';
    // Use PNG format for lossless image quality (no compression artifacts)
    File(croppedFilePath).writeAsBytesSync(img.encodePng(croppedImage));

    return croppedFilePath;
  }
}
