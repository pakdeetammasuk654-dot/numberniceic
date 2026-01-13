import 'package:flutter/material.dart';
import '../../viewmodels/analyzer_view_model.dart';
import '../../models/sample_name.dart';
import '../auto_scrolling_avatar_list.dart';

class SharedSampleNames extends StatelessWidget {
  final AnalyzerViewModel viewModel;
  final TextEditingController nameController;
  final Future<List<SampleName>> sampleNamesFuture;

  const SharedSampleNames({
    super.key,
    required this.viewModel,
    required this.nameController,
    required this.sampleNamesFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SampleName>>(
      future: sampleNamesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        return Container(
          color: const Color(0xFF1A1A2E),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 80,
            child: AutoScrollingAvatarList(
              samples: snapshot.data!,
              currentName: viewModel.currentName,
              isScrolling: viewModel.isAvatarScrolling,
              onStopScrolling: () => viewModel.setAvatarScrolling(false),
              onSelect: (name) {
                // Determine if this selection should stop scrolling (it should)
                // Handled by onStopScrolling callback via AutoScrollingAvatarList internal logic usually?
                // Actually AutoScrollingAvatarList calls onStopScrolling when user interacts.
                // We just set name here.
                viewModel.setName(name);
                nameController.text = name;
              },
            ),
          ),
        );
      },
    );
  }
}
