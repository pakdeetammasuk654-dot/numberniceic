import 'package:flutter/foundation.dart';
import 'solar_system_data.dart';
import 'best_names_data.dart';
import 'name_analysis.dart'; // Added import for NameAnalysis

class AnalysisResult {
  final SolarSystemData? solarSystem;
  final BestNamesData? bestNames;
  final List<NameAnalysis>? similarNames; // Added field
  final bool isVip;

  AnalysisResult({
    this.solarSystem,
    this.bestNames,
    this.similarNames,
    this.isVip = false,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    if (json['solar_system'] == null) {
       // Detected flattened data (Legacy or Single Result)
       if (json.containsKey('cleaned_name')) {
          if (kDebugMode) debugPrint('🔍 AnalysisResult: Detected flattened data. Wrapping as solar_system.');
          return AnalysisResult(
            solarSystem: SolarSystemData.fromJson(json),
            isVip: json['is_vip'] == true,
            similarNames: (json['similar_names'] as List? ?? [])
                .map((e) => NameAnalysis.fromJson(e))
                .toList(),
          );
       }
       // If no solar_system and no cleaned_name, it's likely a partial section result (e.g. 'names')
       if (kDebugMode && !json.containsKey('best_names')) {
          debugPrint('ℹ️ AnalysisResult: Partial data received (No solar_system). Keys: ${json.keys.toList()}');
       }
    }
    
    return AnalysisResult(
      solarSystem: json['solar_system'] != null
          ? SolarSystemData.fromJson(json['solar_system'])
          : null,
      bestNames: json['best_names'] != null
          ? BestNamesData.fromJson(json['best_names'])
          : null,
      similarNames: (json['similar_names'] as List? ?? [])
          .map((e) => NameAnalysis.fromJson(e))
          .toList(),
      isVip: json['is_vip'] == true,
    );
  }
  
  AnalysisResult copyWith({
    SolarSystemData? solarSystem,
    BestNamesData? bestNames,
    List<NameAnalysis>? similarNames,
    bool? isVip,
  }) {
    return AnalysisResult(
      solarSystem: solarSystem ?? this.solarSystem,
      bestNames: bestNames ?? this.bestNames,
      similarNames: similarNames ?? this.similarNames,
      isVip: isVip ?? this.isVip,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'solar_system': solarSystem?.toJson(),
      'best_names': bestNames?.toJson(),
      'similar_names': similarNames?.map((e) => e.toJson()).toList(),
      'is_vip': isVip,
    };
  }
}
