import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/widgets/lucky_number_card.dart';
import 'package:mobile_app/widgets/lucky_number_skeleton.dart';
import 'package:mobile_app/widgets/contact_purchase_modal.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/services/numbers_json_service.dart';
import 'package:mobile_app/screens/number_analysis_page.dart';
import 'package:mobile_app/models/name_character.dart'; // Add this import
import 'shimmering_gold_wrapper.dart';
import 'background_pattern_painter.dart';
import 'package:mobile_app/widgets/pct_item.dart';

class WeightedPair {
  final String pair;
  final double weight;
  WeightedPair(this.pair, this.weight);
  
  @override
  String toString() => '$pair($weight)';
}

// --- MAIN WIDGET ---
class CategoryNestedDonut extends StatefulWidget {
  final Map<String, dynamic> categoryBreakdown;
  final int totalPairs;
  final int grandTotalScore;
  final int totalPositiveScore;
  final int totalNegativeScore;
  final String? analyzedName;
  final List<NameCharacter>? nameHtml; // New parameter
  final List<dynamic>? allUniquePairs; // NEW: All unique pairs from name analysis
  final Function(String phoneNumber)? onAddPhoneNumber; // Just for notification
  final Color? backgroundColor; // Optional background color
  final bool isPerfect; // Control Shimmer Logic

  const CategoryNestedDonut({
    super.key,
    required this.categoryBreakdown,
    required this.totalPairs,
    required this.grandTotalScore,
    required this.totalPositiveScore,
    required this.totalNegativeScore,
    this.analyzedName,
    this.nameHtml, // New parameter
    this.allUniquePairs, // NEW
    this.onAddPhoneNumber,
    this.backgroundColor,
    this.isPerfect = false,
  });

  @override
  State<CategoryNestedDonut> createState() => _CategoryNestedDonutState();
}

class _CategoryNestedDonutState extends State<CategoryNestedDonut> with TickerProviderStateMixin {
  final Set<String> _enhancedCategories = {};
  final Map<String, Map<String, dynamic>?> _fetchedLuckyNumbers = {}; 
  final Map<String, int> _categoryIndices = {};
  
  // Store added phone numbers grouped by category
  final Map<String, List<Map<String, dynamic>>> _addedPhoneNumbersByCategory = {};
  
  // NEW: Store pair numbers from added phone numbers for averaging
  final List<String> _addedPhonePairNumbers = [];
  
  // NEW: Store summaries from pairs
  List<String> _pairSummaries = [];
  
  // NumbersJsonService for calculating percentages from numbers.json
  final NumbersJsonService _numbersService = NumbersJsonService();
  bool _numbersLoaded = false; // Track if numbers.json is loaded
  
  AnimationController? _textShineController;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;
  
  // NEW: Chart Wipe Animation
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;


  @override
  void initState() {
    super.initState();
    
    // Load numbers.json data and rebuild when done
    _loadNumbersData();
    
    _textShineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
    
    // Score Count Up
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scoreAnimation = CurvedAnimation(parent: _scoreController, curve: Curves.easeOutExpo);
    
    // Chart Animation (Fan Opening Effect with Bounce)
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Use elasticOut for "Boing!" effect
    _chartAnimation = CurvedAnimation(parent: _chartController, curve: Curves.elasticOut);

    // Safety Delay Start
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
         _scoreController.forward();
         _chartController.forward();
      }
    });
  }
  
  Future<void> _loadNumbersData() async {
    await _numbersService.loadData();
    if (mounted) {
      setState(() {
        _numbersLoaded = true;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Detect visibility change (e.g. switching Tabs in TabBarView)
    if (TickerMode.of(context)) {
      // Small delay to ensure layout is ready or simply to create a 'fresh' feel
      // Force replay animation when tab becomes visible
      _scoreController.forward(from: 0.0);
      _chartController.forward(from: 0.0);
    } else {
      // Pause/Reset if tab is switched away to save resources
      _scoreController.stop();
      _chartController.stop();
    }
  }

  @override
  void didUpdateWidget(CategoryNestedDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if data changed significantly (Name changed OR Scores changed)
    if (widget.analyzedName != oldWidget.analyzedName || 
        widget.grandTotalScore != oldWidget.grandTotalScore ||
        widget.categoryBreakdown != oldWidget.categoryBreakdown) {
      
      // Clear enhancement state if name changed
      if (widget.analyzedName != oldWidget.analyzedName) {
        _enhancedCategories.clear();
        _addedPhoneNumbersByCategory.clear();
        _fetchedLuckyNumbers.clear();
      }
          
      // Reset animations
      _scoreController.reset();
      _chartController.reset();
      
      // Play ONLY if visible. If not visible, didChangeDependencies will handle it when user returns.
      if (TickerMode.of(context)) {
        _chartController.forward();
        _scoreController.forward();
      }
    }
  }

  @override
  void dispose() {
    _textShineController?.dispose();
    _scoreController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _onEnhanceChange(String category, bool isEnhanced) async {
    if (!isEnhanced) {
      // Close action - not needed for bottom sheet approach
      return;
    }

    // Show bottom sheet with 3 lucky numbers
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LuckyNumbersBottomSheet(
        category: category,
        categoryColor: _getCategoryColor(category),
        analyzedName: widget.analyzedName,
        onAddPhoneNumber: (phoneNumber, sum, keywords) {
          _handleAddPhoneNumber(category, phoneNumber, sum, keywords);
        },
      ),
    );
  }

  // Handle adding phone number
  void _handleAddPhoneNumber(String category, String phoneNumber, int sum, List<String> keywords) {
    setState(() {
      // Initialize category list if not exists
      if (!_addedPhoneNumbersByCategory.containsKey(category)) {
        _addedPhoneNumbersByCategory[category] = [];
      }
      
      // Add/Replace phone number to category (Limit 1 per category)
      _addedPhoneNumbersByCategory[category] = [{
        'number': phoneNumber,
        'sum': sum,
        'keywords': keywords,
      }];
      
      // Extract pair numbers from the phone number and add to the list for averaging
      final phonePairs = _extractPhonePairNumbers(phoneNumber);
      
      // Clear previous phone pairs for this category and add new ones
      // (For now, we accumulate all phone pairs)
      _addedPhonePairNumbers.clear();
      
      // Add pairs from all added phone numbers
      for (var catPhones in _addedPhoneNumbersByCategory.values) {
        for (var phoneData in catPhones) {
          final pairs = _extractPhonePairNumbers(phoneData['number'] ?? '');
          _addedPhonePairNumbers.addAll(pairs);
        }
      }
      
      print('📊 Added phone number $phoneNumber to $category');
      print('   Phone pairs: $phonePairs');
      print('   Total added pairs: $_addedPhonePairNumbers');
    });
    
    // Animate chart change
    _chartController.forward(from: 0.0);
    
    // Notify parent (just for SnackBar)
    if (widget.onAddPhoneNumber != null) {
      widget.onAddPhoneNumber!(phoneNumber);
    }
  }

  // Handle removing phone number
  void _handleRemovePhoneNumber(String category, int index) {
    setState(() {
      if (_addedPhoneNumbersByCategory.containsKey(category)) {
        _addedPhoneNumbersByCategory[category]!.removeAt(index);
        
        // Remove category key if list is empty
        if (_addedPhoneNumbersByCategory[category]!.isEmpty) {
          _addedPhoneNumbersByCategory.remove(category);
        }
        
        // Recalculate phone pair numbers from remaining phones
        _addedPhonePairNumbers.clear();
        for (var catPhones in _addedPhoneNumbersByCategory.values) {
          for (var phoneData in catPhones) {
            final pairs = _extractPhonePairNumbers(phoneData['number'] ?? '');
            _addedPhonePairNumbers.addAll(pairs);
          }
        }
        
        print('🔴 Removed phone number at index $index from category $category');
      }
    });

    // Animate chart change
    _chartController.forward(from: 0.0);
  }
  
  /// Extract pair numbers from allUniquePairs
  /// Each pair in allUniquePairs is like {"pair_number": "12", "meaning": {...}}
  List<String> _extractPairNumbers(List<dynamic>? pairs) {
    if (pairs == null || pairs.isEmpty) return [];
    
    final List<String> pairNumbers = [];
    for (var pair in pairs) {
      String? pairNum;
      if (pair is Map) {
        // Handle {"pair_number": "12", ...} from API
        pairNum = pair['pair_number']?.toString() ?? pair['pair']?.toString();
      } else if (pair is String) {
        pairNum = pair;
      } else if (pair is num) {
        pairNum = pair.toString();
      }
      
      if (pairNum != null && pairNum.isNotEmpty) {
        // Ensure 2-digit format (e.g., "1" -> "01", "12" -> "12")
        if (pairNum.length == 1) {
          pairNum = '0$pairNum';
        }
        // Only take last 2 digits if longer
        if (pairNum.length > 2) {
          pairNum = pairNum.substring(pairNum.length - 2);
        }
        pairNumbers.add(pairNum);
      }
    }
    return pairNumbers;
  }
  
  /// Calculate average percentages from a list of pair numbers using numbers.json
  Map<String, double> _calculateAveragePercentages(List<String> pairNumbers) {
    if (pairNumbers.isEmpty) {
      return {'สุขภาพ': 25.0, 'การงาน': 25.0, 'การเงิน': 25.0, 'ความรัก': 25.0};
    }
    
    double totalHealth = 0, totalCareer = 0, totalFinance = 0, totalLove = 0;
    int count = 0;
    
    for (var pairNum in pairNumbers) {
      final aspects = _numbersService.getAspectPercentages(pairNum);
      totalHealth += aspects['health'] ?? 25;
      totalCareer += aspects['career'] ?? 25;
      totalFinance += aspects['finance'] ?? 25;
      totalLove += aspects['love'] ?? 25;
      count++;
    }
    
    if (count == 0) {
      return {'สุขภาพ': 25.0, 'การงาน': 25.0, 'การเงิน': 25.0, 'ความรัก': 25.0};
    }
    
    return {
      'สุขภาพ': totalHealth / count,
      'การงาน': totalCareer / count,
      'การเงิน': totalFinance / count,
      'ความรัก': totalLove / count,
    };
  }
  
  /// Calculate good (D) and bad (R) percentages separately
  /// Returns a map with 'good' and 'bad' percentages for each category
  /// Calculate comprehensive weighted stats for all pairs (Good + Bad combined)
  /// Returns:
  /// - 'good': Map<String, double> (Percentage of Good weight for each category relative to TOTAL weight of all pairs)
  /// - 'bad': Map<String, double> (Percentage of Bad weight for each category relative to TOTAL weight of all pairs)
  /// - 'total': Map<String, double> (Total percentage for each category, sums to 100% across all categories)
  // Calculate weighted stats based on pair weights AND aspect scores
  // Returns: { 'good': Map<String, double>, 'bad': Map<String, double>, 'total': Map<String, double> }
  Map<String, Map<String, double>> _calculateWeightedStats(List<WeightedPair> weightedPairs) {
    // Initialize accumulators
    final Map<String, double> goodWeights = {'สุขภาพ': 0.0, 'การงาน': 0.0, 'การเงิน': 0.0, 'ความรัก': 0.0};
    final Map<String, double> badWeights = {'สุขภาพ': 0.0, 'การงาน': 0.0, 'การเงิน': 0.0, 'ความรัก': 0.0};
    double grandTotalWeight = 0.0;

    if (weightedPairs.isEmpty) {
        // Fallback equal distribution
        return {
           'good': {'สุขภาพ': 6.25, 'การงาน': 6.25, 'การเงิน': 6.25, 'ความรัก': 6.25},
           'bad': {'สุขภาพ': 18.75, 'การงาน': 18.75, 'การเงิน': 18.75, 'ความรัก': 18.75},
           'total': {'สุขภาพ': 25.0, 'การงาน': 25.0, 'การเงิน': 25.0, 'ความรัก': 25.0} // 25% each
        };
    }

    for (var wp in weightedPairs) {
       final p = wp.pair;
       final pairWeight = wp.weight;
       if (pairWeight <= 0) continue; // Skip if weight is 0

       final isGood = _numbersService.isGoodPair(p); // Good (D-type)
       final isBad = _numbersService.isBadPair(p);   // Bad (R-type)
       final aspects = _numbersService.getAspectPercentages(p); 
       
       // Process each aspect only if it has a clear Polar nature (Good or Bad)
       // Neutral pairs are ignored to prevent diluting the Good/Bad score incorrectly
       if (isGood || isBad) {
         aspects.forEach((key, val) {
             final thaiKey = NumbersJsonService.keyToThai(key); // Ensure Thai key
             final weight = val.toDouble() * pairWeight; // Apply Position Weight
             
             if (isGood) {
                goodWeights[thaiKey] = (goodWeights[thaiKey] ?? 0) + weight;
             } else {
                badWeights[thaiKey] = (badWeights[thaiKey] ?? 0) + weight;
             }
             grandTotalWeight += weight;
         });
       }
    }
    
    if (grandTotalWeight == 0) grandTotalWeight = 1; // Prevent div by zero

    // Normalize to Percentages (Total of ALL categories = 100%)
    final Map<String, double> goodPcts = {};
    final Map<String, double> badPcts = {};
    final Map<String, double> totalPcts = {}; // Chart size depends on this

    final categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];
    for (var cat in categories) {
       goodPcts[cat] = (goodWeights[cat] ?? 0) / grandTotalWeight * 100;
       badPcts[cat] = (badWeights[cat] ?? 0) / grandTotalWeight * 100;
       totalPcts[cat] = goodPcts[cat]! + badPcts[cat]!;
    }
    
    return {'good': goodPcts, 'bad': badPcts, 'total': totalPcts};
  }
  
  /// Collect summaries from pair numbers
  List<String> _collectSummaries(List<String> pairNumbers) {
    final List<String> summaries = [];
    for (var pairNum in pairNumbers) {
      final summary = _numbersService.getSummary(pairNum);
      if (summary != null && summary.isNotEmpty) {
        summaries.add(summary);
      }
    }
    return summaries;
  }
  
  /// Collect insights for a specific category from pair numbers
  /// Returns unique insights for the given category (e.g., 'health', 'career', 'finance', 'love')
  List<String> _collectCategoryInsights(List<String> pairNumbers, String categoryKey) {
    final Set<String> insightSet = {};
    for (var pairNum in pairNumbers) {
      final insight = _numbersService.getAspectInsight(pairNum, categoryKey);
      if (insight != null && insight.isNotEmpty) {
        insightSet.add(insight);
      }
    }
    return insightSet.take(3).toList(); // Top 3 unique insights
  }
  
  /// Extract pair numbers from a phone number string and assign weights based on position
  /// Standard formatting: 0XX-ABC-DEFG
  /// Pairs: (0X, XX), XA, AB, BC, CD, DE, EF, FG
  /// Usually analysis focuses on last 7 digits (ABC-DEFG) => Pairs: AB, BC, CD, DE, EF, FG (6 pairs)
  /// Weights are applied to these 6 pairs.
  List<WeightedPair> _extractPhonePairNumbersWithType(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9) return [];
    
    // Prediction Weights logic for 10-digit number (0XX-ABC-DEFG)
    // Last 7 digits are significant (ABC-DEFG) -> Indices relative to length.
    // Length is L.
    // Pairs inside ABC-DEFG (Last 6 pairs): Weight 1.0 (100%)
    // Pairs prefix (0XX...): Weight 0.1 (10%) - Just background influence
    
    final List<WeightedPair> pairs = [];
    final int l = digits.length;
    // We want last 7 digits: indices [L-7, L-6, ... L-1]
    // The pairs start from index of first digit.
    // 7 digits = 6 pairs.
    // Start index for prediction = (L - 7).
    final int predictionStartIndex = l - 7;
    
    for (int i = 0; i < digits.length - 1; i++) {
       String pair = digits.substring(i, i + 2);
       double weight = 0.1; // Default low weight for prefix
       
       if (i >= predictionStartIndex) {
         weight = 1.0; // High weight for predictive pairs 
       }
       
       pairs.add(WeightedPair(pair, weight));
    }
    return pairs;
  }
  
  // Helper to extraction plain strings for insights
  List<String> _extractPhonePairNumbers(String phoneNumber) {
     return _extractPhonePairNumbersWithType(phoneNumber).map((e) => e.pair).toList();
  }
  
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'การงาน': return const Color(0xFF42A5F5); // Blue
      case 'การเงิน': return const Color(0xFFFFA726); // Orange
      case 'ความรัก': return const Color(0xFFEC407A); // Pink
      case 'สุขภาพ': return const Color(0xFF26A69A); // Teal
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    // Prepare chart data
    final List<CategoryData> chartData = [];
    final List<String> categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];

    for (var cat in categories) {
      final data = widget.categoryBreakdown[cat] ?? {};
      
      Map<String, dynamic>? luckyData;
      if (_fetchedLuckyNumbers.containsKey(cat)) {
         luckyData = _fetchedLuckyNumbers[cat];
      } else {
         luckyData = data['suggested_number'];
      }
      
      chartData.add(CategoryData(
        name: cat,
        good: data['good'] ?? 0,
        bad: data['bad'] ?? 0,
        color: _getCategoryColor(cat),
        keywords: List<String>.from(data['keywords'] ?? []),
        suggestedNumber: luckyData,
      ));
    }
    
    // Combine manual enhanced categories and categories with added phone numbers
    final allEnhanced = Set<String>.from(_enhancedCategories)
      ..addAll(_addedPhoneNumbersByCategory.keys);
    
    // ============================================================
    // NEW LOGIC: Calculate percentages from numbers.json using averaging
    // ============================================================
    
    // Step 1: Extract pair numbers from name analysis (Weight 1.0)
    final namePairs = _extractPairNumbers(widget.allUniquePairs);
    final List<WeightedPair> nameWeightedPairs = namePairs.map((p) => WeightedPair(p, 1.0)).toList();
    
    // Step 2: Extract pairs from all added phone numbers with Position Weights
    final List<WeightedPair> phoneWeightedPairs = [];
    _addedPhoneNumbersByCategory.forEach((cat, phoneList) {
       for (var phoneData in phoneList) {
          String phone = phoneData['number'] ?? '';
          phoneWeightedPairs.addAll(_extractPhonePairNumbersWithType(phone));
       }
    });

    // Combine all weighted pairs
    final List<WeightedPair> allWeightedPairs = [...nameWeightedPairs, ...phoneWeightedPairs];
    
    // For insights/summaries, use plain pair strings
    final List<String> allPairStrings = allWeightedPairs.map((e) => e.pair).toList();
    
    // Step 3: Calculate Weighted Stats (Good + Bad combined sums to 100%)
    final weightedStats = _calculateWeightedStats(allWeightedPairs);
    
    final Map<String, double> goodPercentages = weightedStats['good']!;
    final Map<String, double> badPercentages = weightedStats['bad']!;
    final Map<String, double> totalPercentages = weightedStats['total']!;
    
    // Use total percentages for chart segment sizes
    final Map<String, double> chartPercentages = Map.from(totalPercentages);
    
    // Determine colors for each segment
    // If Bad > Good for a category, use Black color scheme. Else use Category color.
    final Map<String, bool> isCategoryBad = {};
    for (var cat in categories) {
       // A category is considered "Bad" for the chart color if its Bad component is larger than Good
       // OR if it's pure bad. 
       // User requirement: "Vikram" (1 Good, 1 Bad) -> Split 100%. 
       // "Sek Loso" (Pure Bad) -> Black tube.
       // Logic: If bad component > good component, render as Bad (Black).
       isCategoryBad[cat] = (badPercentages[cat] ?? 0) > (goodPercentages[cat] ?? 0);
    }
    
    // Calculate display percentages for Table with Normalization (Largest Remainder Method)
    // To ensure Total Good + Total Bad across all categories sums to exactly 100%
    final Map<String, int> goodDisplayPcts = {};
    final Map<String, int> badDisplayPcts = {};
    
    // 1. Collect all values
    // Using PctItem class from external file
    
    List<PctItem> allItems = [];
    for (var cat in categories) {
      allItems.add(PctItem(cat, true, goodPercentages[cat] ?? 0));
      allItems.add(PctItem(cat, false, badPercentages[cat] ?? 0));
    }
    
    // 2. Calculate current sum
    int currentSum = allItems.fold(0, (sum, item) => sum + item.floorVal);
    int diff = 100 - currentSum;
    
    // 3. Sort by remainder descending
    allItems.sort((a, b) => b.remainder.compareTo(a.remainder));
    
    // 4. Distribute difference
    for (int i = 0; i < diff; i++) {
      if (i < allItems.length) {
         allItems[i].floorVal += 1;
      }
    }
    
    // 5. Populate result maps
    for (var item in allItems) {
      if (item.isGood) goodDisplayPcts[item.cat] = item.floorVal;
      else badDisplayPcts[item.cat] = item.floorVal;
    }
    
    // NO NEED TO RECALCULATE CHART PERCENTAGES
    // We pass good/bad percentages separately to the painter to draw split segments.
    // Normalized integer values (goodDisplayPcts/badDisplayPcts) ensure exactly 100% total.

    // Step 6: Collect summaries for display
    _pairSummaries = _collectSummaries(allPairStrings.take(5).toList()); // Top 5 summaries
    
    // Step 7: Collect insights for each category from numbers.json
    final Map<String, List<String>> categoryInsights = {
      'สุขภาพ': _collectCategoryInsights(allPairStrings, 'health'),
      'การงาน': _collectCategoryInsights(allPairStrings, 'career'),
      'การเงิน': _collectCategoryInsights(allPairStrings, 'finance'),
      'ความรัก': _collectCategoryInsights(allPairStrings, 'love'),
    };
    
    // Prepare display percentages for labels
    double sumGood = goodPercentages.values.fold(0, (a, b) => a + b);
    Map<String, double>? displayLabelsMap;
    if (sumGood <= 0) {
      displayLabelsMap = {
        'สุขภาพ': 0.0,
        'การงาน': 0.0,
        'การเงิน': 0.0,
        'ความรัก': 0.0,
      };
    }

    // Calculate final score
    double finalScoreTarget = widget.grandTotalScore.abs().toDouble(); 
    // Just use the absolute score as target, max 100 usually managed by backend or capped here
    if (finalScoreTarget > 100) finalScoreTarget = 100;
    if (finalScoreTarget == 0) finalScoreTarget = 100; 

    return Container(
      color: widget.backgroundColor ?? Colors.transparent,
      child: Stack(
        children: [
          // Background Pattern removed to prevent overlap and improve performance
          
          Column(
            children: [
              // Chart Section (Transparent, on top of watermark)
              Container(
                color: Colors.transparent,
                child: Column(
                  children: [
                    // 1. Analyzed Name Header
                    _buildAnalyzedNameHeader(),

                    // Chart Section
                    SizedBox(
                      height: 220,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _scoreController.forward(from: 0.0);
                                _chartController.forward(from: 0.0);
                              },
                              child: AnimatedBuilder(
                                animation: _chartAnimation,
                                builder: (context, child) {
                                  return CustomPaint(
                                    size: const Size(200, 200),
                                    painter: NestedDonutPainter(
                                      data: chartData,
                                      totalPairs: widget.totalPairs,
                                      enhancedCategories: allEnhanced,
                                      progress: _chartAnimation.value,
                                      goodPercentages: goodDisplayPcts.map((k, v) => MapEntry(k, v.toDouble())), 
                                      badPercentages: badDisplayPcts.map((k, v) => MapEntry(k, v.toDouble())),
                                    ),
                                  );
                                }
                              ),
                            ),
                            // Center Text (Golden)
                            // Center Text (Golden)
                            Container(
                               width: 136, height: 136,
                               decoration: BoxDecoration(
                                 gradient: const RadialGradient(
                                   colors: [
                                     Color(0xFFF3E5D8), // Brighter center
                                     Color(0xFFE5D5C5), // Classic Light Canvas Tan
                                   ],
                                 ),
                                 shape: BoxShape.circle,
                                 border: Border.all(color: const Color(0xFFD7BCA3), width: 2),
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.black.withOpacity(0.15),
                                     blurRadius: 10,
                                     offset: const Offset(0, 4),
                                   )
                                 ]
                               ),
                               child: ClipOval(
                                 child: Stack(
                                   children: [
                                     // LV Pattern Watermark
                                     Positioned.fill(
                                       child: CustomPaint(
                                         painter: BackgroundPatternPainter(
                                           color: const Color(0xFF5D4037), // Rich Chocolate Brown pattern
                                           opacity: 0.35, // Stronger visibility like the actual LV pattern
                                         ),
                                       ),
                                     ),
                                     
                                     // Text Content
                                     Center(
                                       child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                             // Name in Center
                                             Padding(
                                               padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                               child: widget.isPerfect 
                                               ? ShimmeringGoldWrapper(
                                                   child: RichText(
                                                     textAlign: TextAlign.center,
                                                     text: TextSpan(
                                                       children: _buildNameTextSpans(fontSize: 28, defaultColor: const Color(0xFF4E342E)),
                                                     ),
                                                   ),
                                                 )
                                               : RichText(
                                                   textAlign: TextAlign.center,
                                                   text: TextSpan(
                                                     children: _buildNameTextSpans(fontSize: 28, defaultColor: const Color(0xFF4E342E)),
                                                   ),
                                                 ),
                                             ),
                                          ],
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              const SizedBox(height: 0), 
              _buildLegendHeader(),
              Divider(height: 1, color: Colors.grey[200]),
              Column(
                children: [
                  ...chartData.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var cat = entry.value;
                      bool isEnhanced = allEnhanced.contains(cat.name);
                      
                      int displayPct = goodDisplayPcts[cat.name] ?? 0;
                      int badPct = badDisplayPcts[cat.name] ?? 0;
                      
                      int potentialBoost = 0;
                      if (!isEnhanced && cat.good == 0) {
                        potentialBoost = 15; 
                      }

                      final rawInsights = categoryInsights[cat.name] ?? [];
                      final addedPhones = _addedPhoneNumbersByCategory[cat.name] ?? [];
                      final addedKeywords = addedPhones.expand((p) => List<String>.from(p['keywords'] ?? [])).toSet();
                      final filteredInsights = rawInsights.where((ins) => !addedKeywords.contains(ins)).toList();

                      return CategoryLegendRow(
                        key: ValueKey(cat.name),
                        cat: cat, 
                        totalPairs: widget.totalPairs,
                        index: idx,
                        onEnhanceChange: (val) => _onEnhanceChange(cat.name, val),
                        textShineController: _textShineController!,
                        isEnhanced: isEnhanced,
                        displayPct: displayPct,
                        badPct: badPct, 
                        potentialBoost: potentialBoost,
                        categoryInsights: filteredInsights,
                        addedPhoneNumbers: _addedPhoneNumbersByCategory[cat.name],
                        onRemovePhoneNumber: _handleRemovePhoneNumber,
                        isDominantlyBad: isCategoryBad[cat.name] ?? false, // NEW
                      );
                    }),
                    Divider(height: 1, color: Colors.grey[200]),
                    _buildTotalPercentageRow(goodDisplayPcts, badDisplayPcts),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHintText() {
      return Container(
        color: const Color(0xFFF1F5F9), // Slate 100 for hint bg
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('💡 แตะไอคอน ', style: GoogleFonts.kanit(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
            Container(
              width: 14, height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 1))],
              ),
              child: const Icon(Icons.autorenew, size: 10, color: Colors.white),
            ),
            Text(' เพื่อเปลี่ยนเบอร์มงคล', style: GoogleFonts.kanit(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
          ],
        ),
      );
  }

  Widget _buildLegendHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text('หมวดหมู่', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : const Color(0xFF64748B)))),
            Expanded(flex: 2, child: Center(child: Text('%ดี', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : const Color(0xFF64748B))))),
            Expanded(flex: 2, child: Center(child: Text('%ร้าย', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : const Color(0xFF64748B))))),
            Expanded(
              flex: 2, 
              child: Align(
                alignment: Alignment.centerRight, 
                child: Text(
                  'เติมกราฟ', 
                  style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                  textAlign: TextAlign.right, 
                )
              )
            ),
          ],
        ),
      ),
    );
  }
  


  Widget _buildTotalPercentageRow(Map<String, int> goodPcts, Map<String, int> badPcts) {
    int totalGood = goodPcts.values.fold(0, (sum, val) => sum + val);
    int totalBad = badPcts.values.fold(0, (sum, val) => sum + val);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.6),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('รวม', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('$totalGood%', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981))), // Brighter Green for Dark
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('$totalBad%', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF202020))), // Light gray for Dark
            ),
          ),
          const Expanded(flex: 2, child: SizedBox.shrink()), // Empty for button column
        ],
      ),
    );
  }

  Widget _buildTotalScoreRow(List<CategoryData> chartData) {
     final score = widget.grandTotalScore;
     final isPositive = score >= 0;
     
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.transparent, // Transparent to show watermark
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คะแนนรวม', style: GoogleFonts.kanit(fontSize: 16, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               Text(isPositive ? '😊' : '😭', style: const TextStyle(fontSize: 48)),
               const SizedBox(width: 16),
               Text(
                 '${isPositive ? '+' : ''}$score',
                 style: GoogleFonts.kanit(
                   fontSize: 56, 
                   fontWeight: FontWeight.w900, 
                   color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                   height: 1.0,
                 ),
               ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
               _buildPill('ดี +${widget.totalPositiveScore}', const Color(0xFFECFDF5), const Color(0xFF10B981)),
               const SizedBox(width: 12),
               _buildPill('ร้าย ${widget.totalNegativeScore}', const Color(0xFFFEF2F2), const Color(0xFFEF4444)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color bg, Color fg) {
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
          child: Text(text, style: GoogleFonts.kanit(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
      );
  }
  


  Widget _buildAnalyzedNameHeader() {
    if (widget.analyzedName == null || widget.analyzedName!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 24, left: 20, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: const Color(0xFF388E3C), // Green
               borderRadius: BorderRadius.circular(10),
               boxShadow: [
                 BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
               ]
             ),
             child: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
           ),
           const SizedBox(width: 12),
           Expanded(
             child: Wrap(
               crossAxisAlignment: WrapCrossAlignment.center,
               children: [
                   Text(
                     'เสริมชื่อดีให้ ',
                     style: GoogleFonts.kanit(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: const Color(0xFF1E293B), // Navy/Black
                     ),
                   ),
                   const SizedBox(width: 4),
                   
                   // Name Display Logic
                   ShimmeringGoldWrapper(
                     enabled: widget.isPerfect, // Only shimmer if perfect
                     child: RichText(
                        text: TextSpan(
                          children: [
                            _buildQuoteSpan(),
                            ..._buildNameTextSpans(),
                            _buildQuoteSpan(),
                          ]
                        ),
                     ),
                   ),
               ],
             ),
           ) 
        ],
      ),
    );
  }

  TextSpan _buildQuoteSpan() {
    return TextSpan(
      text: '"',
      style: GoogleFonts.kanit(
        fontSize: 22, 
        fontWeight: FontWeight.w900,
        color: const Color(0xFF1E293B), // Quote always black (unless shimmered)
        height: 1.5,
        shadows: widget.isPerfect ? [
            const Shadow(offset: Offset(0, 1.5), blurRadius: 3, color: Color(0x8A000000))
        ] : null,
      ),
    );
  }

  List<InlineSpan> _buildNameTextSpans({double fontSize = 22, Color defaultColor = const Color(0xFF1E293B)}) {
    // 1. If we have detailed character data (nameHtml)
    if (widget.nameHtml != null && widget.nameHtml!.isNotEmpty) {
      return widget.nameHtml!.map((char) {
        // Condition: If NOT perfect and IS bad -> Red. Else -> Default Color.
        // (If isPerfect, the Wrapper will override color to Gold)
        final bool isRed = !widget.isPerfect && char.isBad;
        
        return TextSpan(
          text: char.char,
          style: GoogleFonts.kanit(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: isRed ? const Color(0xFFEF4444) : defaultColor,
            height: 1.5, // Ensure vowel coverage
            shadows: widget.isPerfect ? [
               const Shadow(offset: Offset(0, 1.5), blurRadius: 3, color: Color(0x8A000000))
            ] : null,
          ),
        );
      }).toList();
    }

    // 2. Fallback: Use string only (All Default Color)
    return [
      TextSpan(
        text: widget.analyzedName,
        style: GoogleFonts.kanit(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          color: defaultColor,
          height: 1.5,
          shadows: widget.isPerfect ? [
             const Shadow(offset: Offset(0, 1.5), blurRadius: 3, color: Color(0x8A000000))
          ] : null,
        ),
      )
    ];
  }

}

// --- PAINTER & MODEL ---

class CategoryData {
  final String name;
  final num good;
  final num bad;
  final Color color;
  final List<String> keywords;
  final Map<String, dynamic>? suggestedNumber;

  CategoryData({
    required this.name,
    required this.good,
    required this.bad,
    required this.color,
    required this.keywords,
    this.suggestedNumber,
  });
}

class NestedDonutPainter extends CustomPainter {
  final List<CategoryData> data;
  final int totalPairs;
  final Set<String> enhancedCategories;
  final double progress; // 0.0 to 1.0
  final Map<String, double> goodPercentages; 
  final Map<String, double> badPercentages;

  NestedDonutPainter({
    required this.data,
    required this.totalPairs,
    required this.enhancedCategories,
    required this.progress,
    required this.goodPercentages,
    required this.badPercentages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 32.0;

    // Draw Background Track
    final bgPaint = Paint()
      ..color = Colors.grey[200]! // Light track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth/2, bgPaint);
    
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    CategoryData? getData(String name) {
      try { return data.firstWhere((d) => d.name == name); } catch (e) { return null; }
    }

    final quadrants = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];
    
    double currentStartAngle = -math.pi / 2;

    // Loop 1: Draw GOOD segments (Colored) based on goodPercentages
    for (var name in quadrants) {
      final catData = getData(name);
      final pct = goodPercentages[name] ?? 0;
      
      if (pct > 0) {
        double sweepAngle = (pct / 100) * (2 * math.pi);
        double drawSweep = sweepAngle * progress;

        Color color = catData?.color ?? Colors.grey;
        int displayVal = pct.round();
        
        // Draw Good Segment (Not Bad) - Always draw gap between good segments
        _drawSegment(canvas, rect, currentStartAngle, drawSweep, color, strokeWidth, center, radius, "$displayVal%", false, drawGap: true);
        
        currentStartAngle += drawSweep;
      }
    }

    // Loop 2: Draw BAD segments (Black) based on badPercentages
    final badQuads = quadrants.where((q) => (badPercentages[q] ?? 0) > 0).toList();
    double totalBadPct = badPercentages.values.fold(0, (a, b) => a + b);
    double badStartAngle = currentStartAngle;

    for (int i = 0; i < badQuads.length; i++) {
      final name = badQuads[i];
      final pct = badPercentages[name] ?? 0;
      final isLastBad = i == badQuads.length - 1;
      
      if (pct > 0) {
        double sweepAngle = (pct / 100) * (2 * math.pi);
        double drawSweep = sweepAngle * progress;

        // Force Black Color for Bad Segment
        Color color = const Color(0xFF202020); 
        
        // Draw Bad Segment (Is Bad = true for gradient)
        // Pass empty label because we will draw the combined percentage after
        _drawSegment(canvas, rect, currentStartAngle, drawSweep, color, strokeWidth, center, radius, "", true, drawGap: isLastBad);
        
        currentStartAngle += drawSweep;
      }
    }

    // Draw single combined label for all black segments
    if (totalBadPct > 0 && progress > 0.5) {
       double totalBadSweep = (totalBadPct / 100) * (2 * math.pi) * progress;
       _drawLabel(canvas, center, radius, strokeWidth, badStartAngle, totalBadSweep, "${totalBadPct.round()}%");
    }
  }

  void _drawLabel(Canvas canvas, Offset center, double radius, double strokeWidth, double start, double sweep, String label) {
       if (sweep < 0.1) return;
       
       final labelAngle = start + sweep / 2;
       final labelRadius = radius - strokeWidth / 2;
       final dx = center.dx + labelRadius * math.cos(labelAngle);
       final dy = center.dy + labelRadius * math.sin(labelAngle);

       final textSpan = TextSpan(
         text: label,
         style: GoogleFonts.kanit(
           color: Colors.white, 
           fontWeight: FontWeight.bold, 
           fontSize: 11,
           shadows: [const Shadow(blurRadius: 2, color: Colors.black26)],
         ),
       );
       final textPainter = TextPainter(
         text: textSpan,
         textDirection: TextDirection.ltr,
       );
       textPainter.layout();
       textPainter.paint(canvas, Offset(dx - textPainter.width / 2, dy - textPainter.height / 2));
  }

  void _drawSegment(Canvas canvas, Rect rect, double start, double sweep, Color categoryColor, double strokeWidth, Offset center, double radius, String label, bool isBad, {bool drawGap = true}) {
       List<Color> gradientColors;
       
       if (isBad) {
          // Bad/Black gradients
          gradientColors = [const Color(0xFF424242), const Color(0xFF1E1E1E)]; 
       } else if (categoryColor.value == 0xFF42A5F5) { // Blue
          gradientColors = [const Color(0xFF90CAF9), const Color(0xFF42A5F5)];
       } else if (categoryColor.value == 0xFFFFA726) { // Orange
          gradientColors = [const Color(0xFFFFCC80), const Color(0xFFFFA726)];
       } else if (categoryColor.value == 0xFFEC407A) { // Pink
          gradientColors = [const Color(0xFFF48FB1), const Color(0xFFEC407A)];
       } else if (categoryColor.value == 0xFF26A69A) { // Teal
          gradientColors = [const Color(0xFF80CBC4), const Color(0xFF26A69A)];
       } else {
          gradientColors = [categoryColor.withOpacity(0.7), categoryColor];
       }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..shader = LinearGradient(
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
             colors: gradientColors,
             tileMode: TileMode.mirror
        ).createShader(rect);

      canvas.drawArc(rect, start, sweep, false, paint);
      
      // Gap
      if (drawGap && sweep > 0.1) {
         final gapPaint = Paint()
           ..color = Colors.white
           ..style = PaintingStyle.stroke
           ..strokeWidth = strokeWidth + 2
           ..strokeCap = StrokeCap.butt;
         const gapSize = 0.03;
         canvas.drawArc(rect, start + sweep - gapSize, gapSize, false, gapPaint);
      }
      
      // TEXT LABEL
       if (label.isNotEmpty) {
          _drawLabel(canvas, center, radius, strokeWidth, start, sweep, label);
       }
  }

  @override
  bool shouldRepaint(NestedDonutPainter oldDelegate) => true;
}

// --- LEGEND ROW WIDGET ---
class CategoryLegendRow extends StatelessWidget {
  final CategoryData cat;
  final int totalPairs;
  final int index;
  final Function(bool) onEnhanceChange;
  final AnimationController textShineController;
  final bool isEnhanced;
  final int displayPct;
  final int badPct; // NEW: Bad percentage from R-type pairs
  final int potentialBoost; // NEW: Show potential boost when enhancing
  final List<String> categoryInsights; // NEW: Insights from numbers.json
  final List<Map<String, dynamic>>? addedPhoneNumbers;
  final Function(String category, int index)? onRemovePhoneNumber;
  final bool isDominantlyBad; // NEW

  const CategoryLegendRow({
    super.key,
    required this.cat,
    required this.totalPairs,
    required this.index,
    required this.onEnhanceChange,
    required this.textShineController,
    required this.isEnhanced,
    required this.displayPct,
    this.badPct = 0,
    this.potentialBoost = 0,
    this.categoryInsights = const [],
    this.addedPhoneNumbers,
    this.onRemovePhoneNumber,
    this.isDominantlyBad = false, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // NEW: Always show percentage since we now calculate from numbers.json
    // isActive is true if displayPct > 0 (from numbers.json average)
    bool isActive = displayPct > 0 || cat.good > 0 || isEnhanced; 
    bool hasBad = badPct > 0; // Use badPct field from R-type pairs
    bool showColor = isActive || hasBad || displayPct > 0; 
    int goodPct = displayPct;
    
    // Determine representative color (match chart)
    Color dotColor = isDominantlyBad ? (isDark ? Colors.white38 : const Color(0xFF202020)) : cat.color;
    if (!showColor) dotColor = isDark ? Colors.white10 : Colors.grey[300]!;

    return Container(
      // Zebra striping: even rows get slightly different dark background
      decoration: BoxDecoration(
        color: index % 2 == 0 
            ? (isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6)) 
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.name, 
                        style: GoogleFonts.kanit(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold, 
                          color: showColor 
                              ? (isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF1E293B)) 
                              : (isDark ? Colors.white24 : Colors.grey[400])
                        ),
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  // Good percentage from D-type pairs
                  child: goodPct > 0 
                  ? Text('$goodPct%', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? cat.color.withOpacity(0.9) : cat.color))
                  : Text('-', style: GoogleFonts.kanit(fontSize: 16, color: isDark ? Colors.white10 : Colors.grey[300])),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  // Bad percentage from R-type pairs - shown in dark/gray color
                  child: badPct > 0
                  ? Text('$badPct%', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF202020)))
                  : Text('-', style: GoogleFonts.kanit(fontSize: 16, color: isDark ? Colors.white10 : Colors.grey[300])),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _EnhanceButton(
                    isActive: isActive,
                    isEnhanced: isEnhanced,
                    onChanged: onEnhanceChange,
                    categoryColor: cat.color,
                  ),
                ),
              ),
            ],
          ),
          // Show insights from numbers.json first, fallback to old keywords
          if (categoryInsights.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8), 
                child: ShimmeringGoldWrapper(
                  enabled: showColor && !hasBad,
                  child: Text(
                    categoryInsights.join(', '),
                    style: GoogleFonts.sarabun(
                      fontSize: 16, 
                      color: isDark 
                          ? (showColor && !hasBad ? const Color(0xFFFBBF24) : Colors.white70)
                          : (showColor && !hasBad ? const Color(0xFFD97706) : const Color(0xFF334155)), 
                      fontWeight: FontWeight.bold,
                      height: 1.8,
                      fontStyle: FontStyle.normal,
                    ),
                    strutStyle: StrutStyle(
                      fontFamily: 'Sarabun',
                      fontSize: 16,
                      height: 1.8,
                      forceStrutHeight: true,
                    ),
                  ),
                ),
            ),
          ] else if (cat.keywords.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8), 
              child: ShimmeringGoldWrapper(
                enabled: showColor && !hasBad,
                child: Text(
                  cat.keywords.join(', '),
                  style: GoogleFonts.sarabun(
                    fontSize: 15, 
                    color: const Color(0xFFFFD700), // Base color for shader (Gold)
                    fontWeight: FontWeight.bold,
                    height: 1.8,
                    fontStyle: FontStyle.normal,
                  ),
                  strutStyle: StrutStyle(
                    fontFamily: 'Sarabun',
                    fontSize: 15,
                    height: 1.8,
                    forceStrutHeight: true,
                  ),
                ),
              ),
            ),
          ] else if (addedPhoneNumbers == null || addedPhoneNumbers!.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Text(
                '-',
                style: GoogleFonts.kanit(
                  fontSize: 13, 
                  color: hasBad ? Colors.white38 : Colors.white24,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ],
          
          // Added Phone Numbers
          if (addedPhoneNumbers != null && addedPhoneNumbers!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...addedPhoneNumbers!.asMap().entries.map((entry) {
              final phoneIndex = entry.key;
              final phoneData = entry.value;
              final phoneNumber = phoneData['number'] as String;
              final sum = phoneData['sum'] as int;
              final keywords = phoneData['keywords'] as List<String>;
              
              return TweenAnimationBuilder<double>(
                key: ValueKey(phoneNumber),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 20, right: 8, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.08), // Using category color (lighter)
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cat.color.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: cat.color.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Keywords
                      if (keywords.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4), // Extra room for Thai descenders inside shimmer bounds
                            child: ShimmeringGoldWrapper(
                              child: Text(
                                keywords.join(', '),
                                style: GoogleFonts.sarabun(
                                  fontSize: 18,
                                  color: const Color(0xFFFFD700), // Base color for shader (Gold)
                                  fontWeight: FontWeight.w900,
                                  height: 2.0,
                                ),
                                strutStyle: StrutStyle(
                                  fontFamily: 'Sarabun',
                                  fontSize: 18,
                                  height: 2.0,
                                  forceStrutHeight: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Phone number and sum
                      // Phone number and sum
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedBuilder(
                              animation: textShineController,
                              builder: (context, child) {
                                return ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: const [
                                        Color(0xFF8E6E12), // Dark Gold
                                        Color(0xFFF1C40F), // Gold
                                        Color(0xFFFFFAD8), // Light Gold
                                        Color(0xFFF1C40F), // Gold
                                        Color(0xFF8E6E12), // Dark Gold
                                      ],
                                      stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                                      begin: Alignment(-2.5 + (textShineController.value * 5), 0.0),
                                      end: Alignment(-1.0 + (textShineController.value * 5), 0.0),
                                      tileMode: TileMode.clamp,
                                    ).createShader(bounds);
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        phoneNumber,
                                        style: GoogleFonts.sarabun(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFFFD700), // Overridden but gold helps anti-aliasing
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '($sum)',
                                        style: GoogleFonts.sarabun(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFFD700),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Remove button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                if (onRemovePhoneNumber != null) {
                                  onRemovePhoneNumber!(cat.name, phoneIndex);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(Icons.close, size: 18, color: cat.color.withOpacity(0.7)),
                              ),
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

class _EnhanceButton extends StatefulWidget {
  final bool isActive;
  final bool isEnhanced;
  final Function(bool) onChanged;
  final Color categoryColor;

  const _EnhanceButton({
    required this.isActive, 
    required this.isEnhanced,
    required this.onChanged,
    required this.categoryColor,
  });

  @override
  State<_EnhanceButton> createState() => _EnhanceButtonState();
}

class _EnhanceButtonState extends State<_EnhanceButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Create lighter and darker versions of the category color for gradient
    final HSLColor hslColor = HSLColor.fromColor(widget.categoryColor);
    final Color lightColor = hslColor.withLightness((hslColor.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final Color darkColor = hslColor.withLightness((hslColor.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final Color borderColor = hslColor.withLightness((hslColor.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        widget.onChanged(true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [lightColor, widget.categoryColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: _isPressed 
            ? [
                BoxShadow(color: widget.categoryColor.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 0))
              ]
            : [
                BoxShadow(color: darkColor, blurRadius: 0, offset: const Offset(0, 3)), // 3D Depth
                BoxShadow(color: widget.categoryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 4)), // Soft Shadow
              ]
        ),
        transform: Matrix4.identity()..translate(0.0, _isPressed ? 3.0 : 0.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              'เสริม',
              style: GoogleFonts.kanit(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                height: 1.2
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom Sheet Widget for displaying 3 lucky numbers
class _LuckyNumbersBottomSheet extends StatefulWidget {
  final String category;
  final Color categoryColor;
  final String? analyzedName;
  final Function(String phoneNumber, int sum, List<String> keywords)? onAddPhoneNumber;
  final Function(String phoneNumber)? onNotifyParent;

  const _LuckyNumbersBottomSheet({
    required this.category,
    required this.categoryColor,
    this.analyzedName,
    this.onAddPhoneNumber,
    this.onNotifyParent,
  });

  @override
  State<_LuckyNumbersBottomSheet> createState() => _LuckyNumbersBottomSheetState();
}

class _LuckyNumbersBottomSheetState extends State<_LuckyNumbersBottomSheet> {
  List<Map<String, dynamic>>? _luckyNumbers;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLuckyNumbers();
  }

  Future<void> _fetchLuckyNumbers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch 3 numbers (index 0, 1, 2)
      final List<Map<String, dynamic>> numbers = [];
      for (int i = 0; i < 3; i++) {
        final result = await ApiService.getLuckyNumber(widget.category, index: i);
        if (result != null) {
          numbers.add(result);
        }
      }

      if (mounted) {
        setState(() {
          _luckyNumbers = numbers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.kanit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    children: [
                      const TextSpan(text: 'หมายเลขไร้ที่ติ '),
                      TextSpan(
                        text: '"${widget.category}"',
                        style: TextStyle(color: widget.categoryColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                _error!,
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            )
          else if (_luckyNumbers == null || _luckyNumbers!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'ไม่พบข้อมูลเบอร์มงคล',
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Keywords Header (shown once)
                  if (_luckyNumbers!.isNotEmpty && _luckyNumbers![0]['keywords'] != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.categoryColor.withOpacity(0.15),
                            widget.categoryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.categoryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.sarabun(
                            fontSize: 20,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                          children: [
                            if (widget.analyzedName != null && widget.analyzedName!.isNotEmpty) ...[
                              TextSpan(
                                text: '${widget.analyzedName}" ',
                                style: GoogleFonts.sarabun(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: widget.categoryColor,
                                ),
                              ),
                            ],
                            const TextSpan(text: 'เบอร์ส่งเสริม:\n'),
                            TextSpan(
                              text: (List<String>.from(_luckyNumbers![0]['keywords'] ?? [])).join(', '),
                              style: TextStyle(
                                color: widget.categoryColor,
                                decoration: TextDecoration.underline,
                                decorationColor: widget.categoryColor.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Phone Numbers List
                  ..._luckyNumbers!.asMap().entries.map((entry) {
                    final number = entry.value;
                    final phoneNumber = number['number'] ?? '---';
                    final sum = int.tryParse(number['sum'].toString()) ?? 0;
                    final keywords = List<String>.from(number['keywords'] ?? []);
                    
                    return _CompactPhoneRow(
                      phoneNumber: phoneNumber,
                      sum: sum,
                      categoryColor: widget.categoryColor,
                      onAdd: () {
                        // Close bottom sheet
                        Navigator.pop(context);
                        
                        // Add phone number to CategoryNestedDonut state
                        if (widget.onAddPhoneNumber != null) {
                          widget.onAddPhoneNumber!(phoneNumber, sum, keywords);
                        }
                        
                        // Notify parent for SnackBar
                        if (widget.onNotifyParent != null) {
                          widget.onNotifyParent!(phoneNumber);
                        }
                      },
                      onBuy: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => ContactPurchaseModal(
                            phoneNumber: phoneNumber,
                          ),
                        );
                      },
                      onAnalyze: () {
                        // Close the lucky numbers bottom sheet first
                        Navigator.pop(context);
                        // Show the analysis as a new bottom sheet
                        NumberAnalysisPage.show(context, phoneNumber: phoneNumber);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Compact Phone Row for Bottom Sheet
class _CompactPhoneRow extends StatefulWidget {
  final String phoneNumber;
  final int sum;
  final Color categoryColor;
  final VoidCallback onAdd;
  final VoidCallback onBuy; // Keep parameter but maybe ignored in build if UI removed
  final VoidCallback onAnalyze;

  const _CompactPhoneRow({
    required this.phoneNumber,
    required this.sum,
    required this.categoryColor,
    required this.onAdd,
    required this.onBuy,
    required this.onAnalyze,
  });

  @override
  State<_CompactPhoneRow> createState() => _CompactPhoneRowState();
}

class _CompactPhoneRowState extends State<_CompactPhoneRow> with SingleTickerProviderStateMixin {
  late AnimationController _shineController;
  
  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 4500),
    )..repeat();
  }
  
  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Phone Number and Sum
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, child) {
                        return ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                Color(0xFF8E6E12), // Dark Gold
                                Color(0xFFF1C40F), // Gold
                                Color(0xFFFFFAD8), // Light Gold
                                Color(0xFFF1C40F), // Gold
                                Color(0xFF8E6E12), // Dark Gold
                              ],
                              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                              begin: Alignment(-2.5 + (_shineController.value * 5), 0.0),
                              end: Alignment(-1.0 + (_shineController.value * 5), 0.0),
                              tileMode: TileMode.clamp,
                            ).createShader(bounds);
                          },
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.phoneNumber,
                                  style: GoogleFonts.kanit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white, // Overridden by ShaderMask
                                    letterSpacing: 1.2,
                                    height: 1.0,
                                  ),
                                ),
                                TextSpan(
                                  text: ' (${widget.sum})',
                                  style: GoogleFonts.kanit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white, // Overridden by ShaderMask
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Add Button (3D Green)
                _build3DButton(
                  icon: Icons.add_circle,
                  color: const Color(0xFF10B981),
                  onTap: widget.onAdd,
                ),
                
                const SizedBox(width: 10),
                
                // Analyze Button (3D Blue)
                _build3DButton(
                  icon: Icons.query_stats,
                  color: const Color(0xFF3B82F6),
                  onTap: widget.onAnalyze,
                ),
              ],
            ),
          ),
        ),
        // Thin divider
        Container(
          height: 1,
          color: Colors.grey[200],
        ),
      ],
    );
  }

  Widget _build3DButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final Color lightColor = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final Color darkColor = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
    final Color shadowColor = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lightColor,
            color,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 3), // 3D Depth
            blurRadius: 0,
          ),
          BoxShadow(
            color: color.withOpacity(0.3),
            offset: const Offset(0, 5), // Soft drop shadow
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}



