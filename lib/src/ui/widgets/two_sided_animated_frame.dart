import 'package:document_camera_frame/document_camera_frame.dart';
import 'package:flutter/material.dart';
import '../../core/app_constants.dart';

class TwoSidedAnimatedFrame extends StatefulWidget {
  final double detectionFrameHeight;
  final double detectionFrameWidth;
  final double detectionFrameOuterBorderRadius;
  final double detectionFrameInnerCornerBorderRadius;
  final Duration detectionFrameFlipDuration;
  final Curve detectionFrameFlipCurve;
  final BoxBorder? border;
  final ValueNotifier<DocumentSide>? currentSideNotifier;
  final bool isDocumentAligned;

  const TwoSidedAnimatedFrame({
    super.key,
    required this.detectionFrameHeight,
    required this.detectionFrameWidth,
    required this.detectionFrameOuterBorderRadius,
    required this.detectionFrameInnerCornerBorderRadius,
    required this.detectionFrameFlipDuration,
    required this.detectionFrameFlipCurve,
    this.border,
    this.currentSideNotifier,
    required this.isDocumentAligned,
  });

  @override
  State<TwoSidedAnimatedFrame> createState() => _TwoSidedAnimatedFrameState();
}

class _TwoSidedAnimatedFrameState extends State<TwoSidedAnimatedFrame>
    with TickerProviderStateMixin {
  double _detectionFrameHeight = 0;
  double _cornerBorderBoxHeight = 0;

  late AnimationController _flipAnimationController;
  late Animation<double> _flipAnimation;

  DocumentSide? _previousSide;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();

    _flipAnimationController = AnimationController(
      duration: widget.detectionFrameFlipDuration,
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _flipAnimationController,
        curve: widget.detectionFrameFlipCurve,
      ),
    );

    widget.currentSideNotifier?.addListener(_onSideChanged);
    _previousSide = widget.currentSideNotifier?.value;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openFrame();
    });
  }

  void _onSideChanged() {
    final currentSide = widget.currentSideNotifier?.value;

    if (_previousSide != null && _previousSide != currentSide && !_isFlipping) {
      _triggerFlipAnimation();
    }

    _previousSide = currentSide;
  }

  void _triggerFlipAnimation() async {
    if (_isFlipping) return;

    setState(() {
      _isFlipping = true;
    });

    await _flipAnimationController.forward();
    _flipAnimationController.reset();

    setState(() {
      _isFlipping = false;
    });
  }

  void _openFrame() {
    setState(() {
      _detectionFrameHeight =
          widget.detectionFrameHeight + AppConstants.bottomFrameContainerHeight;
      _cornerBorderBoxHeight =
          widget.detectionFrameHeight +
          AppConstants.bottomFrameContainerHeight / 2 -
          34;
    });
  }

  // void _closeFrame() {
  //   setState(() {
  //     _frameHeight = 0;
  //     _cornerBorderBoxHeight = 0;
  //   });
  // }

  double _getAnimatedFrameHeight() {
    if (!_isFlipping) return _detectionFrameHeight;

    if (_flipAnimation.value <= 0.5) {
      return _detectionFrameHeight * (1 - (_flipAnimation.value * 2));
    } else {
      return _detectionFrameHeight * ((_flipAnimation.value - 0.5) * 2);
    }
  }

  double _getAnimatedCornerHeight() {
    if (!_isFlipping) return _cornerBorderBoxHeight;

    if (_flipAnimation.value <= 0.5) {
      return _cornerBorderBoxHeight * (1 - (_flipAnimation.value * 2));
    } else {
      return _cornerBorderBoxHeight * ((_flipAnimation.value - 0.5) * 2);
    }
  }

  Duration get animatedFrameDuration => Duration(
    milliseconds: (widget.detectionFrameFlipDuration.inMilliseconds / 2).round(),
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final animatedFrameHeight = _getAnimatedFrameHeight();
            final animatedCornerHeight = _getAnimatedCornerHeight();
            final parentHeight = constraints.maxHeight;
            final parentWidth = constraints.maxWidth;
            final detectionFrameTotalHeight = widget.detectionFrameHeight;
            final double fullFrameWidth =
                widget.detectionFrameWidth > parentWidth
                    ? parentWidth
                    : widget.detectionFrameWidth;
            const double guideScale = 0.75;
            final double guideWidth = fullFrameWidth * guideScale;
            final double guideHeight = detectionFrameTotalHeight * guideScale;
            final double guideAnimatedHeight = animatedFrameHeight * guideScale;
            // 角の枠線の高さ（画像領域の高さに合わせる）
            final cornerBoxHeight = widget.detectionFrameHeight;
            final bool isGuideWiderThanFrame = guideWidth >= fullFrameWidth;
            final bool isFrameWiderThanParent = fullFrameWidth > parentWidth;

            debugPrint('------------------------------');
            debugPrint(
              '[DetectionFrame] parentW=${parentWidth.toStringAsFixed(1)} '
              'parentH=${parentHeight.toStringAsFixed(1)} '
              'frameW=${fullFrameWidth.toStringAsFixed(1)} '
              'frameH=${widget.detectionFrameHeight.toStringAsFixed(1)} '
              'animFrameH=${animatedFrameHeight.toStringAsFixed(1)} '
              'guideW=${guideWidth.toStringAsFixed(1)} '
              'guideH=${guideHeight.toStringAsFixed(1)} '
              'cornerH=${cornerBoxHeight.toStringAsFixed(1)} '
              'reverse=${isGuideWiderThanFrame ? "NG" : "OK"} '
              'overflow=${isFrameWiderThanParent ? "NG" : "OK"}',
            );
            debugPrint('------------------------------');

            return SizedBox.expand(
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: fullFrameWidth,
                  height: detectionFrameTotalHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      /// Animated Camera Frame Overlay
                      if (false)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: AnimatedDocumentCameraFramePainter(
                              isFlipping: _isFlipping,
                              detectionFrameWidth: widget.detectionFrameWidth,
                              detectionFrameMaxHeight: _detectionFrameHeight,
                              animatedDetectionFrameHeight: animatedFrameHeight,
                              bottomPosition: 0,
                              borderRadius:
                                  widget.detectionFrameOuterBorderRadius,
                              context: context,
                            ),
                          ),
                        ),

                      /// Detection frame border (outer frame - full width)
                      AnimatedContainer(
                        height: cornerBoxHeight,
                        width: fullFrameWidth,
                        duration:
                            _isFlipping ? Duration.zero : animatedFrameDuration,
                        curve: widget.detectionFrameFlipCurve,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.detectionFrameInnerCornerBorderRadius,
                          ),
                          border: Border.all(
                            color: widget.isDocumentAligned
                                ? Colors.green.shade400
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),

                      /// Border of the guide frame (80% of detection width - inner)
                      AnimatedContainer(
                        width: guideWidth,
                        height: guideAnimatedHeight,
                        duration:
                            _isFlipping ? Duration.zero : animatedFrameDuration,
                        curve: widget.detectionFrameFlipCurve,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            widget.detectionFrameInnerCornerBorderRadius,
                          ),
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
                        ),
                        child: animatedCornerHeight > 0
                            ? Stack(
                                children: [
                                  // Top-left corner
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: _cornerBox(topLeft: true),
                                  ),

                                  // Top-right corner
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: _cornerBox(topRight: true),
                                  ),

                                  // Bottom-left corner
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: _cornerBox(bottomLeft: true),
                                  ),

                                  // Bottom-right corner
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: _cornerBox(bottomRight: true),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _cornerBox({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    final Color borderColor = _isFlipping
        ? Colors.white
        : (widget.isDocumentAligned ? Colors.green.shade400 : Colors.white);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: topLeft || topRight
              ? BorderSide(color: borderColor, width: 4) // 角丸の枠の線を太く
              : BorderSide.none,
          left: topLeft || bottomLeft
              ? BorderSide(color: borderColor, width: 4) // 角丸の枠の線を太く
              : BorderSide.none,
          right: topRight || bottomRight
              ? BorderSide(color: borderColor, width: 4) // 角丸の枠の線を太く
              : BorderSide.none,
          bottom: bottomLeft || bottomRight
              ? BorderSide(color: borderColor, width: 4) // 角丸の枠の線を太く
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: topLeft
              ? Radius.circular(widget.detectionFrameInnerCornerBorderRadius)
              : Radius.zero,
          topRight: topRight
              ? Radius.circular(widget.detectionFrameInnerCornerBorderRadius)
              : Radius.zero,
          bottomLeft: bottomLeft
              ? Radius.circular(widget.detectionFrameInnerCornerBorderRadius)
              : Radius.zero,
          bottomRight: bottomRight
              ? Radius.circular(widget.detectionFrameInnerCornerBorderRadius)
              : Radius.zero,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flipAnimationController.dispose();
    widget.currentSideNotifier?.removeListener(_onSideChanged);
    super.dispose();
  }
}

class AnimatedDocumentCameraFramePainter extends CustomPainter {
  final double detectionFrameWidth;
  final double detectionFrameMaxHeight;
  final double animatedDetectionFrameHeight;
  final double bottomPosition;
  final double borderRadius;
  final BuildContext context;
  final bool isFlipping;

  AnimatedDocumentCameraFramePainter({
    required this.isFlipping,
    required this.detectionFrameWidth,
    required this.detectionFrameMaxHeight,
    required this.animatedDetectionFrameHeight,
    required this.bottomPosition,
    required this.borderRadius,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    if (animatedDetectionFrameHeight > 0) {
      final double top =
          bottomPosition +
          (detectionFrameMaxHeight - animatedDetectionFrameHeight);

      final clearRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (size.width - detectionFrameWidth) / 2,
          top,
          detectionFrameWidth,
          animatedDetectionFrameHeight,
        ),
        Radius.circular(borderRadius),
      );

      final path = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(clearRect)
        ..fillType = PathFillType.evenOdd;

      canvas.drawPath(path, paint);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is AnimatedDocumentCameraFramePainter) {
      return oldDelegate.detectionFrameWidth != detectionFrameWidth ||
          oldDelegate.bottomPosition != bottomPosition ||
          oldDelegate.animatedDetectionFrameHeight !=
              animatedDetectionFrameHeight ||
          oldDelegate.detectionFrameMaxHeight != detectionFrameMaxHeight ||
          oldDelegate.borderRadius != borderRadius;
    }
    return true;
  }
}
