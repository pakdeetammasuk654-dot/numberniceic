import 'package:flutter/foundation.dart';
import '../utils/takhsa_utils.dart';
import 'name_character.dart';

class SolarSystemData {
  final String cleanedName;
  final String inputDayRaw;
  final num grandTotalScore;
  final num totalNumerologyValue;
  final num totalShadowValue;
  final num numNegativeScore;
  final num shaNegativeScore;
  final List<NameCharacter> sunDisplayNameHtml;
  final List<String> klakiniChars;
  final List<dynamic> decodedParts;
  final List<dynamic> allUniquePairs;
  final Map<String, dynamic>? sumPair;
  final List<dynamic>? mainPairs;
  final List<dynamic>? hiddenPairs;
  
  // New fields for Analysis Card and Donut Chart
  final List<dynamic> analysisSummaries;
  final String resultTitle;
  final String resultColor;
  final Map<String, dynamic> categoryBreakdown;
  final int totalPairs;
  final int totalPositiveScore;
  final int totalNegativeScore;

  SolarSystemData({
    required this.cleanedName,
    required this.inputDayRaw,
    required this.grandTotalScore,
    required this.totalNumerologyValue,
    required this.totalShadowValue,
    required this.numNegativeScore,
    required this.shaNegativeScore,
    required this.sunDisplayNameHtml,
    required this.klakiniChars,
    required this.decodedParts,
    required this.allUniquePairs,
    this.sumPair,
    this.mainPairs,
    this.hiddenPairs,
    this.analysisSummaries = const [],
    this.resultTitle = '',
    this.resultColor = '',
    this.categoryBreakdown = const {},
    this.totalPairs = 0,
    this.totalPositiveScore = 0,
    this.totalNegativeScore = 0,
  });

  factory SolarSystemData.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('☀️ SolarSystemData Keys: ${json.keys.toList()}');
    }
    
    final mappedMainPairs = json['main_pairs'] ?? json['numerology_pairs'];
    final mappedHiddenPairs = json['hidden_pairs'] ?? json['shadow_pairs'];
    
    // Attempt to map sumPair
    Map<String, dynamic>? mappedSumPair = json['sum_pair'];
    if (mappedSumPair == null) {
       mappedSumPair = {
         'pair': json['grand_total_score'] ?? 0,
         'meaning': {
            'color': '#FDB813', 
            'is_bad': false,
            'text': 'ผลรวม'
         }
       };
    }

    final String birthday = json['input_day_raw'] ?? json['input_day'] ?? 'sunday';

    List<NameCharacter> sunChars = (json['sun_display_name_html'] as List? ?? [])
        .map((e) => NameCharacter.fromJson(e))
        .toList();

    // Removed forced client-side Klakini detection to rely on API truth
    // sunChars = sunChars.map((c) { ... 

    List<String> klakiniList = (json['klakini_chars'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    // Fallback: If API didn't provide klakini_chars but some characters are bad, collect them
    if (klakiniList.isEmpty) {
      klakiniList = sunChars.where((c) => c.isBad).map((c) => c.char).toList();
    }

    return SolarSystemData(
      cleanedName: json['cleaned_name'] ?? '',
      inputDayRaw: json['input_day_raw'] ?? json['input_day'] ?? '',
      grandTotalScore: json['grand_total_score'] ?? 0,
      totalNumerologyValue: json['total_numerology_value'] ?? 0,
      totalShadowValue: json['total_shadow_value'] ?? 0,
      numNegativeScore: json['num_negative_score'] ?? 0,
      shaNegativeScore: json['sha_negative_score'] ?? 0,
      sunDisplayNameHtml: sunChars,
      klakiniChars: klakiniList,
      decodedParts: json['decoded_parts'] as List? ?? [],
      allUniquePairs: json['all_unique_pairs'] as List? ?? [],
      sumPair: mappedSumPair,
      mainPairs: mappedMainPairs as List?,
      hiddenPairs: mappedHiddenPairs as List?,
      
      // New fields
      analysisSummaries: json['analysis_summaries'] as List? ?? [],
      resultTitle: json['result_title'] ?? '',
      resultColor: json['result_color'] ?? '',
      categoryBreakdown: json['category_breakdown'] as Map<String, dynamic>? ?? {},
      totalPairs: json['total_pairs'] is int ? json['total_pairs'] : (int.tryParse(json['total_pairs']?.toString() ?? '0') ?? 0),
      totalPositiveScore: (json['num_positive_score'] ?? 0) + (json['sha_positive_score'] ?? 0),
      totalNegativeScore: (json['num_negative_score'] ?? 0) + (json['sha_negative_score'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cleaned_name': cleanedName,
      'input_day_raw': inputDayRaw,
      'grand_total_score': grandTotalScore,
      'total_numerology_value': totalNumerologyValue,
      'total_shadow_value': totalShadowValue,
      'num_negative_score': numNegativeScore,
      'sha_negative_score': shaNegativeScore,
      'sun_display_name_html': sunDisplayNameHtml.map((e) => e.toJson()).toList(),
      'klakini_chars': klakiniChars,
      'decoded_parts': decodedParts,
      'all_unique_pairs': allUniquePairs,
      'sum_pair': sumPair,
      'main_pairs': mainPairs,
      'hidden_pairs': hiddenPairs,
      
      'analysis_summaries': analysisSummaries,
      'result_title': resultTitle,
      'result_color': resultColor,
      'category_breakdown': categoryBreakdown,
      'total_pairs': totalPairs,
      'num_positive_score': totalPositiveScore,
      'num_negative_score': totalNegativeScore,
    };
  }
}
