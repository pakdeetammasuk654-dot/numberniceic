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
    );
    
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmeringGoldWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
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
              colors: Theme.of(context).brightness == Brightness.dark
                ? const [
                    Color(0xFFFFC107), // Amber 500 (Pure Gold Base)
                    Color(0xFFFFD700), // Gold
                    Color(0xFFFFFAD8), // Very Light Gold (instead of pure white)
                    Color(0xFFFFD700), // Gold
                    Color(0xFFFFC107), // Amber 500
                  ]
                : const [
                    Color(0xFFA07000), // Darker Gold (High Contrast)
                    Color(0xFFD4AF37), // Metallic Gold
                    Color(0xFFFFFAD8), // Very Light Gold
                    Color(0xFFD4AF37), // Metallic Gold
                    Color(0xFFA07000), // Darker Gold
                  ],
              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
              begin: Alignment(-3.0 + (4.0 * _controller.value), 0.0),
              end: Alignment(-1.0 + (4.0 * _controller.value), 0.0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0), // Force room for descenders
            child: widget.child,
          ),
        );
      },
    );
  }
}
