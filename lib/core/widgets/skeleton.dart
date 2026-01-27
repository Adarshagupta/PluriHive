import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _skeletonBase = Color(0xFFE5E7EB);
const Color _skeletonHighlight = Color(0xFFF3F4F6);

class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: duration, color: _skeletonHighlight);
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: _skeletonBase,
        borderRadius: borderRadius,
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: const BoxDecoration(
        color: _skeletonBase,
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final EdgeInsetsGeometry? margin;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(8),
      margin: margin,
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry padding;

  const SkeletonListTile({
    super.key,
    this.height = 64,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      child: Row(
        children: [
          SkeletonCircle(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLine(height: 14, width: double.infinity),
                SizedBox(height: 8),
                SkeletonLine(height: 12, width: 160),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonLine(height: 12, width: 40),
        ],
      ),
    );
  }
}

