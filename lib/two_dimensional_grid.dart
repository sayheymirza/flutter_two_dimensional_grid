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
  final Duration animationDuration;

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

  double _accumDragDy = 0.0;
  double _accumDragDx = 0.0;

  // fields for simultaneous pan + jump
  Matrix4? _beginMatrix;
  int? _animTargetIndex;

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

        // current scale from scaleAnimation
        final s = _scaleAnimation!.value;

        // target matrix that centers the tile at scale s
        final targetMatrix = _matrixForTile(
          _animTargetIndex!,
          scaleOverride: s,
        );

        // lerp between beginMatrix and targetMatrix by t
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

  Offset _tileCenter(int index) {
    final col = index % widget.crossAxisCount;
    final row = index ~/ widget.crossAxisCount;
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
    for (int i = 0; i < widget.count; i++) {
      final dist = (_sceneToViewport(_tileCenter(i)) - vpCenter).distance;
      if (dist < minDist) {
        minDist = dist;
        nearestIndex = i;
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

  Matrix4 _matrixForTile(int index, {double? scaleOverride}) {
    final sceneCenter = _tileCenter(index);
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

  // simultaneous pan + jump:
  // lerp between beginMatrix and targetMatrix(scaleAnimated) while scaleAnimation runs
  void _snapToTile(int index) {
    _stopAnimationIfRunning();
    _animTargetIndex = index;

    // beginMatrix snapshot
    _beginMatrix = Matrix4.copy(_controller.value);

    // build scale animation: base -> dip -> base
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

    // duration for combined pan + jump
    _animController
      ..duration = widget.animationDuration
      ..value = 0.0;

    _animController.forward().whenComplete(() {
      // ensure final exact matrix (no rounding drift)
      _controller.value = _matrixForTile(index, scaleOverride: widget.scale);
      _scaleAnimation = null;
      _beginMatrix = null;
      _animTargetIndex = null;
      _updateNearestTile();
    });
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

  @override
  Widget build(BuildContext context) {
    _viewportSize ??= MediaQuery.of(context).size;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_centeredOnce && _viewportSize != null) {
        final middleIndex =
            (widget.count / 2).floor().clamp(0, widget.count - 1) +
            (widget.crossAxisCount / 2).toInt();
        nearestTileNotifier.value = middleIndex;
        _centeredOnce = true;
        _snapToTile(middleIndex);
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) {
            _stopAnimationIfRunning();
            _accumDragDy = 0.0;
          },
          onVerticalDragUpdate: (details) {
            _accumDragDy += details.delta.dy;
          },
          onVerticalDragEnd: (details) {
            final primaryVelocity = details.primaryVelocity ?? 0.0;
            _handleSwipeVertical(
              primaryVelocity: primaryVelocity,
              dragDy: _accumDragDy,
            );
            _accumDragDy = 0.0;
          },
          onHorizontalDragStart: (_) {
            _stopAnimationIfRunning();
            _accumDragDx = 0.0;
          },
          onHorizontalDragUpdate: (details) {
            _accumDragDx += details.delta.dx;
          },
          onHorizontalDragEnd: (details) {
            final primaryVelocity = details.primaryVelocity ?? 0.0;
            _handleSwipeHorizontal(
              primaryVelocity: primaryVelocity,
              dragDx: _accumDragDx,
            );
            _accumDragDx = 0.0;
          },
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
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: ValueListenableBuilder<int>(
                        valueListenable: nearestTileNotifier,
                        builder: (context, nearest, _) {
                          final isCenter = index == nearest;
                          return widget.builder(context, index, isCenter, () {
                            _snapToTile(index);
                          });
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
