import 'name_character.dart';

class NameAnalysis {
  final String thName;
  final List<NameCharacter> displayNameHtml;
  final double similarity;
  final num totalScore;
  final List<dynamic> satNum;
  final List<dynamic> shaNum;
  final List<Map<String, dynamic>> tSat;
  final List<Map<String, dynamic>> tSha;
  final String meaning;
  final bool isTopTier;
  final bool hasBadPair;

  NameAnalysis({
    required this.thName,
    required this.displayNameHtml,
    required this.similarity,
    required this.totalScore,
    required this.satNum,
    required this.shaNum,
    required this.tSat,
    required this.tSha,
    required this.meaning,
    required this.isTopTier,
    required this.hasBadPair,
  });

  factory NameAnalysis.fromJson(Map<String, dynamic> json) {
    return NameAnalysis(
      thName: json['th_name'] ?? '',
      displayNameHtml: (json['display_name_html'] as List? ?? [])
          .map((e) => NameCharacter.fromJson(e))
          .toList(),
      similarity: (json['similarity'] as num? ?? 0).toDouble(),
      totalScore: json['total_score'] ?? 0,
      satNum: json['sat_num'] as List? ?? [],
      shaNum: json['sha_num'] as List? ?? [],
      tSat: List<Map<String, dynamic>>.from(json['t_sat'] ?? []),
      tSha: List<Map<String, dynamic>>.from(json['t_sha'] ?? []),
      meaning: json['meaning'] ?? '',
      isTopTier: json['is_top_tier'] == true,
      hasBadPair: json['has_bad_pair'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'th_name': thName,
      'display_name_html': displayNameHtml.map((e) => e.toJson()).toList(),
      'similarity': similarity,
      'total_score': totalScore,
      'sat_num': satNum,
      'sha_num': shaNum,
      't_sat': tSat,
      't_sha': tSha,
      'meaning': meaning,
      'is_top_tier': isTopTier,
      'has_bad_pair': hasBadPair,
    };
  }
  int get totalNumerology => satNum.fold(0, (sum, item) {
        if (item is num) return sum + item.toInt();
        if (item is String) return sum + (int.tryParse(item) ?? 0);
        return sum;
      });
      
  int get totalShadow => shaNum.fold(0, (sum, item) {
        if (item is num) return sum + item.toInt();
        if (item is String) return sum + (int.tryParse(item) ?? 0);
        return sum;
      });
}
