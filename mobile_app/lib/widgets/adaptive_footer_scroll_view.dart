import 'package:flutter/material.dart';
import 'shared_footer.dart';

class AdaptiveFooterScrollView extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  const AdaptiveFooterScrollView({
    super.key,
    required this.children,
    this.onRefresh,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(
            delegate: SliverChildListDelegate(children),
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Spacer(),
              SharedFooter(),
            ],
          ),
        ),
      ],
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: content,
      );
    }

    return content;
  }
}
