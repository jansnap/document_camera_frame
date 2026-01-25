import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

class CapturedImagePreview extends StatelessWidget {
  final ValueNotifier<String> capturedImageNotifier;
  final double detectionFrameWidth;
  final double detectionFrameHeight;

  final double borderRadius;
  const CapturedImagePreview({
    super.key,
    required this.capturedImageNotifier,
    required this.detectionFrameWidth,
    required this.detectionFrameHeight,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: capturedImageNotifier,
      builder: (context, imagePath, child) {
        if (imagePath.isEmpty) {
          return const SizedBox.shrink();
        }

        const previewScale = 2.0;
        final scaledFrameWidth = detectionFrameWidth * previewScale;
        final scaledFrameHeight = detectionFrameHeight * previewScale;
        final previewHeight = scaledFrameHeight +
            AppConstants.bottomFrameContainerHeight * previewScale;
        debugPrint('----------------------------------');
        debugPrint(
          '[CapturedImagePreview] Widget size: ${scaledFrameWidth.toStringAsFixed(0)} x ${previewHeight.toStringAsFixed(0)}',
        );
        debugPrint(
          '[CapturedImagePreview] Preview size: ${scaledFrameWidth.toStringAsFixed(0)} x ${scaledFrameHeight.toStringAsFixed(0)}',
        );
        debugPrint('----------------------------------');

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: scaledFrameWidth,
            height: previewHeight,
            child: Stack(
              children: [
                // Black background for padding
                Container(
                  width: scaledFrameWidth,
                  height: previewHeight,
                  color: Colors.black,
                ),
                // Image with centered alignment
                Positioned(
                  top: 6,
                  left: 6,
                  right: 6,
                  child: Center(
                    child: Container(
                      width: scaledFrameWidth,
                      height: scaledFrameHeight,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(File(imagePath)),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
