import 'package:flutter/material.dart';

class ShimmeringGoldWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const ShimmeringGoldWrapper({super.key, required this.child, this.enabled = true});

  @override
  State<ShimmeringGoldWrapper> createState() => _ShimmeringGoldWrapperState();
}

class _ShimmeringGoldWrapperState extends State<ShimmeringGoldWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 3000) 
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFF8B6914), // Darker Gold for contrast
                Color(0xFFFFD700), // Gold
                Color(0xFFFFF8DC), // Cornsilk (White-ish Gold)
                Color(0xFFFFD700), // Gold
                Color(0xFF8B6914),
              ],
              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
              begin: Alignment(-3.0 + (4.0 * _controller.value), -0.5),
              end: Alignment(-1.0 + (4.0 * _controller.value), 0.5),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
