import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Service to load and analyze number pair data from numbers.json
class NumbersJsonService {
  static final NumbersJsonService _instance = NumbersJsonService._internal();
  factory NumbersJsonService() => _instance;
  NumbersJsonService._internal();

  Map<String, dynamic>? _numbersData;
  bool _isLoaded = false;

  /// Load numbers.json data
  Future<void> loadData() async {
    if (_isLoaded) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/numbers.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      _numbersData = data['numbers'] as Map<String, dynamic>?;
      _isLoaded = true;
      print('✅ NumbersJsonService: Loaded ${_numbersData?.length ?? 0} number pairs');
    } catch (e) {
      print('❌ NumbersJsonService: Error loading numbers.json: $e');
    }
  }

  /// Get data for a specific pair number (e.g., "24", "12")
  Map<String, dynamic>? getPairData(String pairNumber) {
    if (!_isLoaded || _numbersData == null) return null;
    return _numbersData![pairNumber] as Map<String, dynamic>?;
  }

  /// Get aspect percentages for a pair number
  /// Returns a map like: {health: 12, career: 22, finance: 46, love: 20}
  Map<String, int> getAspectPercentages(String pairNumber) {
    final data = getPairData(pairNumber);
    if (data == null) return _defaultAspects();
    
    final aspects = data['aspects'] as Map<String, dynamic>?;
    if (aspects == null) return _defaultAspects();
    
    return {
      'health': (aspects['health']?['percentage'] as num?)?.toInt() ?? 25,
      'career': (aspects['career']?['percentage'] as num?)?.toInt() ?? 25,
      'finance': (aspects['finance']?['percentage'] as num?)?.toInt() ?? 25,
      'love': (aspects['love']?['percentage'] as num?)?.toInt() ?? 25,
    };
  }

  /// Get Thai names for categories
  static const Map<String, String> categoryThaiNames = {
    'health': 'สุขภาพ',
    'career': 'การงาน',
    'finance': 'การเงิน',
    'love': 'ความรัก',
  };

  /// Convert Thai category to English key
  static String thaiToKey(String thai) {
    switch (thai) {
      case 'สุขภาพ': return 'health';
      case 'การงาน': return 'career';
      case 'การเงิน': return 'finance';
      case 'ความรัก': return 'love';
      default: return thai.toLowerCase();
    }
  }

  /// Convert English key to Thai category
  static String keyToThai(String key) {
    return categoryThaiNames[key] ?? key;
  }

  /// Get insight text for a pair's aspect
  String? getAspectInsight(String pairNumber, String aspectKey) {
    final data = getPairData(pairNumber);
    if (data == null) return null;
    
    final aspects = data['aspects'] as Map<String, dynamic>?;
    if (aspects == null) return null;
    
    return aspects[aspectKey]?['insight'] as String?;
  }

  /// Get summary for a pair number
  String? getSummary(String pairNumber) {
    final data = getPairData(pairNumber);
    return data?['summary'] as String?;
  }

  /// Get nature (positive/negative/neutral) for a pair
  String getNature(String pairNumber) {
    final data = getPairData(pairNumber);
    return data?['nature'] as String? ?? 'neutral';
  }

  /// Get pairpoint (score) for a pair
  int getPairPoint(String pairNumber) {
    final data = getPairData(pairNumber);
    return (data?['pairpoint'] as num?)?.toInt() ?? 0;
  }

  /// Get pair type (D10, D8, D5 for good, R10, R7, R5 for bad)
  String getPairType(String pairNumber) {
    final data = getPairData(pairNumber);
    return data?['pairtype'] as String? ?? '';
  }
  
  /// Check if a pair is "good" based on pairtype (D = good)
  bool isGoodPair(String pairNumber) {
    final pairtype = getPairType(pairNumber);
    return pairtype.startsWith('D');
  }
  
  /// Check if a pair is "bad" based on pairtype (R = bad)
  bool isBadPair(String pairNumber) {
    final pairtype = getPairType(pairNumber);
    return pairtype.startsWith('R');
  }

  /// Calculate boost percentage for a category when adding a phone number
  /// This determines how much % will be added when user "เสริม" a category
  /// 
  /// Logic:
  /// - Each category can contribute up to 25% base
  /// - Enhancing with a number that emphasizes that category adds more %
  /// - The boost is based on the number's aspect percentage for that category
  Map<String, double> calculateBoostPercentages(String pairNumber) {
    final aspects = getAspectPercentages(pairNumber);
    
    // The boost is proportional to how much that aspect is emphasized in the pair
    // If a pair has 46% finance, it will boost finance more
    // We normalize so that the total potential boost is meaningful
    return {
      'health': aspects['health']! / 4.0, // Max ~25% boost
      'career': aspects['career']! / 4.0,
      'finance': aspects['finance']! / 4.0,
      'love': aspects['love']! / 4.0,
    };
  }

  /// Get all pair numbers that are positive (good numbers)
  List<String> getPositivePairs() {
    if (!_isLoaded || _numbersData == null) return [];
    
    return _numbersData!.entries
        .where((e) {
          final data = e.value as Map<String, dynamic>;
          final pairpoint = (data['pairpoint'] as num?)?.toInt() ?? 0;
          return pairpoint >= 50;
        })
        .map((e) => e.key)
        .toList();
  }

  /// Get best pairs for a specific category
  /// Returns pairs sorted by their percentage for that category
  List<Map<String, dynamic>> getBestPairsForCategory(String categoryKey, {int limit = 5}) {
    if (!_isLoaded || _numbersData == null) return [];
    
    final pairs = _numbersData!.entries.map((e) {
      final data = e.value as Map<String, dynamic>;
      final aspects = data['aspects'] as Map<String, dynamic>? ?? {};
      final percentage = (aspects[categoryKey]?['percentage'] as num?)?.toInt() ?? 0;
      final nature = data['nature'] as String? ?? 'neutral';
      
      return {
        'pairnumber': e.key,
        'percentage': percentage,
        'nature': nature,
        'summary': data['summary'] ?? '',
        'pairpoint': (data['pairpoint'] as num?)?.toInt() ?? 0,
      };
    }).toList();
    
    // Sort by percentage descending, prefer positive nature
    pairs.sort((a, b) {
      // First by nature (positive first)
      if (a['nature'] == 'positive' && b['nature'] != 'positive') return -1;
      if (b['nature'] == 'positive' && a['nature'] != 'positive') return 1;
      
      // Then by percentage
      return (b['percentage'] as int).compareTo(a['percentage'] as int);
    });
    
    return pairs.take(limit).toList();
  }

  Map<String, int> _defaultAspects() {
    return {'health': 25, 'career': 25, 'finance': 25, 'love': 25};
  }
}
