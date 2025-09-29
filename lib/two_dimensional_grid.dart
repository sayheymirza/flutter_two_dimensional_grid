// ignore_for_file: deprecated_member_use

import 'package:flutter/widgets.dart';

typedef TwoDimensionalItemBuilder =
    Widget Function(
      BuildContext context,
      int index,
      bool isCenter,
      VoidCallback snapToCenter,
    );

class TwoDimensionalGrid extends StatefulWidget {
  const TwoDimensionalGrid({
    super.key,
    required this.count,
    required this.builder,
    this.crossAxisCount = 6,
    this.itemWidth = 200,
    this.itemHeight = 260,
    this.spacing = 4,
    this.padding = 4,
    this.scale = 1.4,
    this.scaleJump = 0.2,
    this.animationDuration = const Duration(milliseconds: 300),
    this.rtl = false,
    this.snapThresholdX = 50.0,
    this.snapThresholdY = 100.0,
    this.animation = true,
  });

  final int count;
  final TwoDimensionalItemBuilder builder;
  final int crossAxisCount;
  final double itemWidth;
  final double itemHeight;
  final double spacing;
  final double padding;
  final double scale;
  final double scaleJump;
  final bool animation;
  final Duration animationDuration;
  final bool rtl;
  final double snapThresholdX;
  final double snapThresholdY;

  @override
  State<TwoDimensionalGrid> createState() => _TwoDimensionalGridState();
}

class _TwoDimensionalGridState extends State<TwoDimensionalGrid>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animController;
  Animation<double>? _scaleAnimation;
  Size? _viewportSize;
  bool _centeredOnce = false;

  final nearestTileNotifier = ValueNotifier<int>(0);

  // accumulated deltas used for fling/drag-end logic
  double _accumDragDy = 0.0;
  double _accumDragDx = 0.0;

  // accumulators for immediate snapping while dragging
  double _accumSnapDy = 0.0;
  double _accumSnapDx = 0.0;

  // fields for simultaneous pan + jump
  Matrix4? _beginMatrix;
  int? _animTargetIndex;

  // pointer-based velocity estimate
  Offset? _lastPointerPos;
  int? _lastPointerTimeMillis;
  Offset? _prevPointerPos;
  int? _prevPointerTimeMillis;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this)
      ..addListener(() {
        final t = _animController.value;
        if (_beginMatrix == null ||
            _animTargetIndex == null ||
            _scaleAnimation == null) {
          _updateNearestTile();
          return;
        }

        final s = _scaleAnimation!.value;

        final targetMatrix = _matrixForTile(
          _animTargetIndex!,
          scaleOverride: s,
        );

        final current = Matrix4Tween(
          begin: _beginMatrix!,
          end: targetMatrix,
        ).evaluate(AlwaysStoppedAnimation(t));

        _controller.value = current;
        _updateNearestTile();
      });
    _controller.addListener(_updateNearestTile);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    nearestTileNotifier.dispose();
    super.dispose();
  }

  double get gridWidth =>
      widget.crossAxisCount * widget.itemWidth +
      (widget.crossAxisCount - 1) * widget.spacing +
      2 * widget.padding;

  double get gridHeight {
    final rows = (widget.count / widget.crossAxisCount).ceil();
    return rows * widget.itemHeight +
        (rows - 1) * widget.spacing +
        2 * widget.padding;
  }

  Offset _tileCenter(int pos) {
    final col = pos % widget.crossAxisCount;
    final row = pos ~/ widget.crossAxisCount;

    return Offset(
      widget.padding +
          col * (widget.itemWidth + widget.spacing) +
          widget.itemWidth / 2,
      widget.padding +
          row * (widget.itemHeight + widget.spacing) +
          widget.itemHeight / 2,
    );
  }

  Offset _viewportCenter() => _viewportSize == null
      ? Offset.zero
      : Offset(_viewportSize!.width / 2, _viewportSize!.height / 2);

  Offset _sceneToViewport(Offset point) =>
      MatrixUtils.transformPoint(_controller.value, point);

  double _currentScale() => _controller.value.getMaxScaleOnAxis();

  int _computeNearestTile() {
    if (_viewportSize == null) return 0;
    final vpCenter = _viewportCenter();
    int nearestIndex = 0;
    double minDist = double.infinity;
    for (int pos = 0; pos < widget.count; pos++) {
      final dist = (_sceneToViewport(_tileCenter(pos)) - vpCenter).distance;
      if (dist < minDist) {
        minDist = dist;
        nearestIndex = pos;
      }
    }
    return nearestIndex;
  }

  void _updateNearestTile() {
    final nearest = _computeNearestTile();
    if (nearestTileNotifier.value != nearest) {
      nearestTileNotifier.value = nearest;
    }
  }

  Matrix4 _matrixForTile(int pos, {double? scaleOverride}) {
    final sceneCenter = _tileCenter(pos);
    final vpCenter = _viewportCenter();
    final scale = scaleOverride ?? _currentScale();
    final dx = vpCenter.dx - sceneCenter.dx * scale;
    final dy = vpCenter.dy - sceneCenter.dy * scale;
    return Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale, 1);
  }

  void _stopAnimationIfRunning() {
    if (_animController.isAnimating) {
      _animController.stop(canceled: true);
    }
    _scaleAnimation = null;
    _beginMatrix = null;
    _animTargetIndex = null;
  }

  void _snapToTileWithAnimation(int pos) {
    _stopAnimationIfRunning();
    _animTargetIndex = pos;
    _beginMatrix = Matrix4.copy(_controller.value);

    final base = widget.scale;
    final dip = (widget.scale - widget.scaleJump).clamp(0.1, base);
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: base,
          end: dip,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: dip,
          end: base,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_animController);

    _animController
      ..duration = widget.animationDuration
      ..value = 0.0;

    _animController.forward().whenComplete(() {
      _controller.value = _matrixForTile(pos, scaleOverride: widget.scale);
      _scaleAnimation = null;
      _beginMatrix = null;
      _animTargetIndex = null;
      _updateNearestTile();
    });
  }

  void _snapToTileImmediate(int pos) {
    _stopAnimationIfRunning();
    _controller.value = _matrixForTile(pos, scaleOverride: widget.scale);
    nearestTileNotifier.value = pos;
  }

  void _snapToTile(int pos) {
    final clamped = pos.clamp(0, widget.count - 1);
    if (widget.animation) {
      _snapToTileWithAnimation(clamped);
    } else {
      _snapToTileImmediate(clamped);
    }
  }

  // helpers for changing row/col by steps (pos-based)
  void _changeRowBy(int rows) {
    _stopAnimationIfRunning();
    final current = nearestTileNotifier.value;
    final target = (current + rows * widget.crossAxisCount).clamp(
      0,
      widget.count - 1,
    );
    _snapToTile(target);
  }

  // direction: +1 => next pos, -1 => previous pos
  void _changeColBy(int direction) {
    _stopAnimationIfRunning();
    final current = nearestTileNotifier.value;
    final target = (current + direction).clamp(0, widget.count - 1);
    _snapToTile(target);
  }

  void _handleSwipeVertical({
    required double primaryVelocity,
    required double dragDy,
  }) {
    final current = nearestTileNotifier.value;
    int target = current;
    const velocityThreshold = 250.0;
    const dragThreshold = 50.0;
    double effective = 0.0;
    if (primaryVelocity.abs() >= velocityThreshold) {
      effective = -primaryVelocity;
    } else {
      effective = -dragDy;
    }
    if (effective > dragThreshold) {
      target = (current + widget.crossAxisCount).clamp(0, widget.count - 1);
    } else if (effective < -dragThreshold) {
      target = (current - widget.crossAxisCount).clamp(0, widget.count - 1);
    } else {
      target = current;
    }
    _snapToTile(target);
  }

  void _handleSwipeHorizontal({
    required double primaryVelocity,
    required double dragDx,
  }) {
    final current = nearestTileNotifier.value;
    int target = current;
    const velocityThreshold = 250.0;
    const dragThreshold = 40.0;
    double effective = 0.0;
    if (primaryVelocity.abs() >= velocityThreshold) {
      effective = primaryVelocity;
    } else {
      effective = dragDx;
    }

    if (effective < -dragThreshold) {
      target = (current + 1).clamp(0, widget.count - 1);
    } else if (effective > dragThreshold) {
      target = (current - 1).clamp(0, widget.count - 1);
    } else {
      target = current;
    }

    _snapToTile(target);
  }

  int _displayIndexForPos(int pos) {
    if (!widget.rtl) return pos;
    final col = pos % widget.crossAxisCount;
    final row = pos ~/ widget.crossAxisCount;
    final mirroredCol = widget.crossAxisCount - 1 - col;
    final mirrored = row * widget.crossAxisCount + mirroredCol;
    // clamp فقط جهت ایمنی
    return mirrored.clamp(0, widget.count - 1);
  }

  // Pointer-based handlers to support simultaneous X and Y dragging
  void _onPointerDown(PointerDownEvent event) {
    _stopAnimationIfRunning();
    _accumDragDx = 0.0;
    _accumDragDy = 0.0;
    _accumSnapDx = 0.0;
    _accumSnapDy = 0.0;
    _prevPointerPos = null;
    _prevPointerTimeMillis = null;
    _lastPointerPos = event.position;
    _lastPointerTimeMillis = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // update history for velocity estimation
    _prevPointerPos = _lastPointerPos;
    _prevPointerTimeMillis = _lastPointerTimeMillis;
    _lastPointerPos = event.position;
    _lastPointerTimeMillis = now;

    final dx = event.delta.dx;
    final dy = event.delta.dy;

    _accumDragDx += dx;
    _accumDragDy += dy;

    _accumSnapDx += dx;
    _accumSnapDy += dy;

    final thrX = widget.snapThresholdX.abs();
    final thrY = widget.snapThresholdY.abs();

    // process horizontal snaps (based on pos order)
    while (_accumSnapDx.abs() >= thrX && thrX > 0) {
      if (_accumSnapDx <= -thrX) {
        _changeColBy(1); // drag left => next pos
        _accumSnapDx += thrX;
      } else if (_accumSnapDx >= thrX) {
        _changeColBy(-1); // drag right => prev pos
        _accumSnapDx -= thrX;
      }
    }

    // process vertical snaps (based on pos order)
    while (_accumSnapDy.abs() >= thrY && thrY > 0) {
      if (_accumSnapDy <= -thrY) {
        _changeRowBy(1); // up drag => next row
        _accumSnapDy += thrY;
      } else if (_accumSnapDy >= thrY) {
        _changeRowBy(-1); // down drag => prev row
        _accumSnapDy -= thrY;
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    // estimate velocities in px/s using the last two recorded positions (if available)
    double vx = 0.0;
    double vy = 0.0;

    if (_prevPointerPos != null &&
        _prevPointerTimeMillis != null &&
        _lastPointerPos != null &&
        _lastPointerTimeMillis != null) {
      final dtMillis = (_lastPointerTimeMillis! - _prevPointerTimeMillis!)
          .clamp(1, 1000);
      final dd = _lastPointerPos! - _prevPointerPos!;
      vx = dd.dx / (dtMillis / 1000.0);
      vy = dd.dy / (dtMillis / 1000.0);
    }

    _handleSwipeHorizontal(primaryVelocity: vx, dragDx: _accumDragDx);
    _handleSwipeVertical(primaryVelocity: vy, dragDy: _accumDragDy);

    _accumDragDx = 0.0;
    _accumDragDy = 0.0;
    _accumSnapDx = 0.0;
    _accumSnapDy = 0.0;
    _lastPointerPos = null;
    _lastPointerTimeMillis = null;
    _prevPointerPos = null;
    _prevPointerTimeMillis = null;
  }

  @override
  Widget build(BuildContext context) {
    _viewportSize ??= MediaQuery.of(context).size;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_centeredOnce && _viewportSize != null) {
        // startIndex بر اساس pos است (بدون mirror)
        final middlePos =
            (widget.count / 2).floor().clamp(0, widget.count - 1) +
            (widget.crossAxisCount / 2).toInt();
        final startPos = middlePos.clamp(0, widget.count - 1);
        nearestTileNotifier.value = startPos;
        _centeredOnce = true;
        _snapToTile(startPos);
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          behavior: HitTestBehavior.opaque,
          child: Listener(
            onPointerDown: (_) => _stopAnimationIfRunning(),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(0),
              panEnabled: false,
              scaleEnabled: false,
              minScale: widget.scale,
              maxScale: widget.scale,
              transformationController: _controller,
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: GridView.builder(
                  padding: EdgeInsets.all(widget.padding),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.crossAxisCount,
                    crossAxisSpacing: widget.spacing,
                    mainAxisSpacing: widget.spacing,
                    childAspectRatio: widget.itemWidth / widget.itemHeight,
                  ),
                  itemCount: widget.count,
                  itemBuilder: (context, pos) {
                    final displayIndex = _displayIndexForPos(pos);
                    return RepaintBoundary(
                      child: ValueListenableBuilder<int>(
                        valueListenable: nearestTileNotifier,
                        builder: (context, nearestPos, _) {
                          final isCenter = pos == nearestPos;
                          return widget.builder(
                            context,
                            displayIndex,
                            isCenter,
                            () {
                              _snapToTile(pos);
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
