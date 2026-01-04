import 'package:flutter/material.dart';

class LuckyNumberSkeleton extends StatefulWidget {
  const LuckyNumberSkeleton({super.key});

  @override
  State<LuckyNumberSkeleton> createState() => _LuckyNumberSkeletonState();
}

class _LuckyNumberSkeletonState extends State<LuckyNumberSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmerBox({double width = double.infinity, double height = 16, double radius = 4}) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: width, height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                colors: [Colors.grey[200]!, Colors.grey[100]!, Colors.grey[200]!],
                stops: const [0.1, 0.5, 0.9],
                begin: Alignment(-1.0 + (_controller.value * 2), 0),
                end: Alignment(1.0 + (_controller.value * 2), 0),
                tileMode: TileMode.clamp
              ),
            ),
          );
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E5), // Light cream/gold bg to match theme
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
          children: [
             // Prophecy Text
             _buildShimmerBox(width: 200, height: 16),
             const SizedBox(height: 16),
             
             // Phone Number (Big)
             _buildShimmerBox(width: 240, height: 40, radius: 8),
             const SizedBox(height: 16),

             // Sum Badge
             _buildShimmerBox(width: 80, height: 24, radius: 12),
             const SizedBox(height: 16),
             
             Divider(color: Colors.grey[200]),
             const SizedBox(height: 16),

             // Action Buttons
             Row(
               children: [
                 Expanded(child: _buildShimmerBox(height: 48, radius: 8)),
                 const SizedBox(width: 12),
                 Expanded(child: _buildShimmerBox(height: 48, radius: 8)),
                 const SizedBox(width: 8),
                 _buildShimmerBox(width: 40, height: 40, radius: 20), // Circle
               ],
             )
          ],
        ),
    );
  }
}
