import 'name_analysis.dart';
import 'name_character.dart';

class BestNamesData {
  final List<NameAnalysis> top4;
  final List<NameAnalysis> recommended;
  final List<NameCharacter> targetNameHtml;
  final int totalBest;

  BestNamesData({
    required this.top4,
    required this.recommended,
    required this.targetNameHtml,
    required this.totalBest,
  });

  factory BestNamesData.fromJson(Map<String, dynamic> json) {
    return BestNamesData(
      top4: (json['top_4'] as List? ?? [])
          .map((e) => NameAnalysis.fromJson(e))
          .toList(),
      recommended: (json['recommended'] as List? ?? [])
          .map((e) => NameAnalysis.fromJson(e))
          .toList(),
      targetNameHtml: (json['target_name_html'] as List? ?? [])
          .map((e) => NameCharacter.fromJson(e))
          .toList(),
      totalBest: json['total_best'] ?? json['total_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'top_4': top4.map((e) => e.toJson()).toList(),
      'recommended': recommended.map((e) => e.toJson()).toList(),
      'target_name_html': targetNameHtml.map((e) => e.toJson()).toList(),
      'total_best': totalBest,
    };
  }
}
