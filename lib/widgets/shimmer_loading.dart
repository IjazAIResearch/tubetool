import 'package:flutter/material.dart';

/// A reusable shimmer/skeleton loading widget.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  /// Preset: List of video card skeletons
  static Widget videoCardList({int count = 4}) {
    return ShimmerLoading(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            ShimmerBox(width: 120, height: 68, borderRadius: 8),
            SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: 14),
                SizedBox(height: 6),
                ShimmerBox(width: 140, height: 12),
                SizedBox(height: 6),
                ShimmerBox(width: 100, height: 12),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Tween<double>(begin: -2, end: 2)
            .evaluate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
        return _ShimmerScope(gradientValue: value, child: widget.child);
      },
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  final double gradientValue;
  const _ShimmerScope({required this.gradientValue, required super.child});

  static _ShimmerScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();

  @override
  bool updateShouldNotify(_ShimmerScope old) => gradientValue != old.gradientValue;
}

/// A shimmer placeholder box.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({super.key, required this.width, required this.height, this.borderRadius = 4});

  @override
  Widget build(BuildContext context) {
    final scope = _ShimmerScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[600]! : Colors.grey[100]!;

    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(scope?.gradientValue ?? -2, 0),
          end: Alignment((scope?.gradientValue ?? -2) + 2, 0),
          colors: [base, highlight, base],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

