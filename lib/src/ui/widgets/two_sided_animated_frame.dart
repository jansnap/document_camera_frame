import 'package:document_camera_frame/document_camera_frame.dart';
import 'package:flutter/material.dart';
import '../../core/app_constants.dart';

class TwoSidedAnimatedFrame extends StatefulWidget {
  final double frameHeight;
  final double frameWidth;
  final double outerFrameBorderRadius;
  final double innerCornerBroderRadius;
  final Duration frameFlipDuration;
  final Curve frameFlipCurve;
  final BoxBorder? border;
  final ValueNotifier<DocumentSide>? currentSideNotifier;
  final bool isDocumentAligned;

  const TwoSidedAnimatedFrame({
    super.key,
    required this.frameHeight,
    required this.frameWidth,
    required this.outerFrameBorderRadius,
    required this.innerCornerBroderRadius,
    required this.frameFlipDuration,
    required this.frameFlipCurve,
    this.border,
    this.currentSideNotifier,
    required this.isDocumentAligned,
  });

  @override
  State<TwoSidedAnimatedFrame> createState() => _TwoSidedAnimatedFrameState();
}

class _TwoSidedAnimatedFrameState extends State<TwoSidedAnimatedFrame>
    with TickerProviderStateMixin {
  double _frameHeight = 0;
  double _cornerBorderBoxHeight = 0;

  late AnimationController _flipAnimationController;
  late Animation<double> _flipAnimation;

  DocumentSide? _previousSide;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();

    _flipAnimationController = AnimationController(
      duration: widget.frameFlipDuration,
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _flipAnimationController,
        curve: widget.frameFlipCurve,
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
      _frameHeight =
          widget.frameHeight + AppConstants.bottomFrameContainerHeight;
      _cornerBorderBoxHeight =
          widget.frameHeight + AppConstants.bottomFrameContainerHeight / 2 - 34;
    });
  }

  // void _closeFrame() {
  //   setState(() {
  //     _frameHeight = 0;
  //     _cornerBorderBoxHeight = 0;
  //   });
  // }

  double _getAnimatedFrameHeight() {
    if (!_isFlipping) return _frameHeight;

    if (_flipAnimation.value <= 0.5) {
      return _frameHeight * (1 - (_flipAnimation.value * 2));
    } else {
      return _frameHeight * ((_flipAnimation.value - 0.5) * 2);
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
    milliseconds: (widget.frameFlipDuration.inMilliseconds / 2).round(),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final animatedFrameHeight = _getAnimatedFrameHeight();
        final animatedCornerHeight = _getAnimatedCornerHeight();
        final topOffset = 100.0; // フレームを下に移動するオフセット
        final screenHeight = 1.sh(context);
        final frameTotalHeight = widget.frameHeight + AppConstants.bottomFrameContainerHeight;
        // 上下中央に配置するためのbottom位置を計算
        final bottomPosition = (screenHeight - frameTotalHeight - topOffset) / 2 - 100.0; // 白枠を100px下に移動
        // 角のボックス位置の微調整オフセット（固定値）
        const cornerBoxOffset = 17.0;

        return Stack(
          children: [
            /// Animated Camera Frame Overlay
            if (false)
              Positioned.fill(
                child: CustomPaint(
                  painter: AnimatedDocumentCameraFramePainter(
                    isFlipping: _isFlipping,
                    frameWidth: widget.frameWidth,
                    frameMaxHeight: _frameHeight,
                    animatedFrameHeight: animatedFrameHeight,
                    bottomPosition: bottomPosition,
                    borderRadius: widget.outerFrameBorderRadius,
                    context: context,
                  ),
                ),
              ),

            /// Border of the document frame
            Positioned(
              bottom: bottomPosition,
              right: (1.sw(context) - widget.frameWidth) / 2,
              child: AnimatedContainer(
                width: widget.frameWidth,
                height: animatedFrameHeight,
                duration: _isFlipping ? Duration.zero : animatedFrameDuration,
                curve: widget.frameFlipCurve,
                decoration: BoxDecoration(
                  // 外側の枠線は削除（角丸の枠のみ表示）
                  borderRadius: BorderRadius.circular(
                    widget.innerCornerBroderRadius,
                  ),
                ),
              ),
            ),

            /// CornerBorderBox of the document frame
            Positioned(
              // 白枠の中央に角丸の枠を配置（高さが半分なので、白枠の中央から高さの1/4上に配置）
              // 100px上に移動（bottomの値を増やすと上に移動）
              bottom: bottomPosition + animatedFrameHeight / 4 + cornerBoxOffset - 100.0 + 100.0,
              left: 0,
              right: 0,
              child: Align(
                child: AnimatedContainer(
                  height: animatedFrameHeight / 2, // 角丸の枠の高さを半分に
                  width:
                      widget.frameWidth -
                      AppConstants.kCornerBorderBoxHorizontalPadding,
                  duration: _isFlipping ? Duration.zero : animatedFrameDuration,
                  curve: widget.frameFlipCurve,
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
              ),
            ),
          ],
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
              ? BorderSide(color: borderColor, width: 2)
              : BorderSide.none,
          left: topLeft || bottomLeft
              ? BorderSide(color: borderColor, width: 2)
              : BorderSide.none,
          right: topRight || bottomRight
              ? BorderSide(color: borderColor, width: 2)
              : BorderSide.none,
          bottom: bottomLeft || bottomRight
              ? BorderSide(color: borderColor, width: 2)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: topLeft
              ? Radius.circular(widget.innerCornerBroderRadius)
              : Radius.zero,
          topRight: topRight
              ? Radius.circular(widget.innerCornerBroderRadius)
              : Radius.zero,
          bottomLeft: bottomLeft
              ? Radius.circular(widget.innerCornerBroderRadius)
              : Radius.zero,
          bottomRight: bottomRight
              ? Radius.circular(widget.innerCornerBroderRadius)
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
  final double frameWidth;
  final double frameMaxHeight;
  final double animatedFrameHeight;
  final double bottomPosition;
  final double borderRadius;
  final BuildContext context;
  final bool isFlipping;

  AnimatedDocumentCameraFramePainter({
    required this.isFlipping,
    required this.frameWidth,
    required this.frameMaxHeight,
    required this.animatedFrameHeight,
    required this.bottomPosition,
    required this.borderRadius,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    if (animatedFrameHeight > 0) {
      final double top =
          bottomPosition + (frameMaxHeight - animatedFrameHeight);

      final clearRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (size.width - frameWidth) / 2,
          top,
          frameWidth,
          animatedFrameHeight,
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
      return oldDelegate.frameWidth != frameWidth ||
          oldDelegate.bottomPosition != bottomPosition ||
          oldDelegate.animatedFrameHeight != animatedFrameHeight ||
          oldDelegate.frameMaxHeight != frameMaxHeight ||
          oldDelegate.borderRadius != borderRadius;
    }
    return true;
  }
}
