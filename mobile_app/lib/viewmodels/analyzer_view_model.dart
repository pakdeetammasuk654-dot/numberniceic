import 'dart:async';
import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../models/day_option.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AnalyzerViewModel extends ChangeNotifier {
  // State
  String _currentName = '';
  String _selectedDay = 'sunday';
  int _loadingCount = 0; // NEW: Track progress
  int _scannedCount = 0;
  bool _isAuspicious = true;
  bool _showTop10 = false;
  bool _isTop10Switching = false;
  bool _isLoading = false;
  
  bool _isSolarLoading = false;
  bool _isNamesLoading = false;
  
  AnalysisResult? _analysisResult;
  bool _isLoggedIn = false;
  bool _isAvatarScrolling = true; // Shared state for avatar list scrolling
  bool _showTutorial = true; 
  
  // Scroll to top notifier - increment to trigger scroll
  final ValueNotifier<int> scrollToTopNotifier = ValueNotifier<int>(0);
  
  // Options
  final List<DayOption> days = [
    DayOption(value: 'sunday', label: 'วันอาทิตย์', icon: Icons.wb_sunny, color: Colors.red),
    DayOption(value: 'monday', label: 'วันจันทร์', icon: Icons.brightness_2, color: const Color(0xFFFFD600)),
    DayOption(value: 'tuesday', label: 'วันอังคาร', icon: Icons.bolt, color: Colors.pink),
    DayOption(value: 'wednesday1', label: 'วันพุธ (กลางวัน)', icon: Icons.wb_cloudy, color: Colors.green),
    DayOption(value: 'wednesday2', label: 'วันพุธ (กลางคืน)', icon: Icons.nightlight_round, color: const Color(0xFF1B5E20)),
    DayOption(value: 'thursday', label: 'วันพฤหัสบดี', icon: Icons.auto_stories, color: Colors.orange),
    DayOption(value: 'friday', label: 'วันศุกร์', icon: Icons.favorite, color: Colors.blue),
    DayOption(value: 'saturday', label: 'วันเสาร์', icon: Icons.filter_vintage, color: Colors.purple),
  ];
  
  Timer? _debounce;
  
  // Getters
  String get currentName => _currentName;
  int get loadingCount => _loadingCount;
  int get scannedCount => _scannedCount;
  String get selectedDay => _selectedDay;
  bool get isAuspicious => _isAuspicious;
  bool get showTop10 => _showTop10;
  bool get isTop10Switching => _isTop10Switching;
  bool get isLoading => _isLoading;

  bool get isSolarLoading => _isSolarLoading;
  bool get isNamesLoading => _isNamesLoading;
  AnalysisResult? get analysisResult => _analysisResult;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAvatarScrolling => _isAvatarScrolling;
  bool get showTutorial => _showTutorial;

  // Trigger scroll to top in listening pages
  void triggerScrollToTop() {
    scrollToTopNotifier.value++;
  }

  // Actions
  void setAvatarScrolling(bool val) {
    if (_isAvatarScrolling != val) {
      _isAvatarScrolling = val;
      notifyListeners();
    }
  }

  void setShowTutorial(bool val) {
    if (_showTutorial != val) {
      _showTutorial = val;
      notifyListeners();
    }
  }

  void init(String? initialName, String? initialDay) {
    if (initialName != null && initialName.isNotEmpty) {
      _currentName = initialName;
    }
    
    if (initialDay != null) {
      _normalizeDay(initialDay);
    }
    
    _checkLoginStatus();
    analyze();
  }
  
  void _normalizeDay(String rawDay) {
     final dayMap = {
      'วันอาทิตย์': 'sunday',
      'วันจันทร์': 'monday',
      'วันอังคาร': 'tuesday',
      'วันพุธ': 'wednesday1',
      'วันพุธกลางวัน': 'wednesday1',
      'วันพุธ (กลางวัน)': 'wednesday1',
      'วันพุธกลางคืน': 'wednesday2',
      'วันพุธ (กลางคืน)': 'wednesday2',
      'วันพฤหัสบดี': 'thursday',
      'วันศุกร์': 'friday',
      'วันเสาร์': 'saturday',
    };
    
    _selectedDay = dayMap[rawDay] ?? rawDay.toLowerCase();
    
    // Safety check
    bool exists = days.any((d) => d.value == _selectedDay);
    if (!exists) {
      _selectedDay = 'sunday';
    }
  }
  
  void setName(String name) {
    _currentName = name;
    // Debounce analysis
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      analyze();
    });
  }
  
  void setDay(String day) {
    _selectedDay = day;
    notifyListeners();
    analyze();
  }
  
  void toggleAuspicious(bool val) {
    _isAuspicious = val;
    notifyListeners();
    analyze();
  }
  
  
  void toggleShowTop10(bool val) {
    _isTop10Switching = true;
    _showTop10 = val;
    notifyListeners();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      _isTop10Switching = false;
      notifyListeners();
    });
  }
  

  Future<void> analyze() async {
    if (_currentName.isEmpty) {
       _analysisResult = null;
       notifyListeners();
       return;
    }
    
    _isLoading = true;
    _isSolarLoading = true;
    _isNamesLoading = true;
    notifyListeners();
    
    try {
      // Step 1: Solar (Fast)
      final solarRes = await ApiService.analyzeName(
        _currentName,
        _selectedDay,
        auspicious: _isAuspicious,
        disableKlakini: _isAuspicious, // If showing good names only, hide Klakini
        disableKlakiniTop4: _isAuspicious, // If showing good names only, hide Klakini in TOP10
        section: 'solar',
      );
      
      if (_analysisResult == null) {
        _analysisResult = solarRes;
      } else {
        _analysisResult = _analysisResult!.copyWith(solarSystem: solarRes.solarSystem);
      }
      _isSolarLoading = false;
      notifyListeners();
      
      // Step 2: Names (Slower)
      // Step 2: Names (Slower) - Stream Progress
      _loadingCount = 0;
      _scannedCount = 0;
      notifyListeners();

      final stream = ApiService.analyzeNameStream(
         _currentName,
        _selectedDay,
        auspicious: _isAuspicious,
        disableKlakini: _isAuspicious,
        disableKlakiniTop4: _isAuspicious,
        section: 'names',
      );

      int lastUpdate = 0;
      await for (final event in stream) {
          if (event['type'] == 'progress') {
             _loadingCount = event['count'] ?? 0;
             _scannedCount = event['total'] ?? 0;
             
             // Throttle updates to prevent UI freeze (max 10fps)
             final now = DateTime.now().millisecondsSinceEpoch;
             if (now - lastUpdate > 100) {
                 notifyListeners();
                 lastUpdate = now;
             }
          } else if (event['type'] == 'result') {
             final namesRes = AnalysisResult.fromJson(event['payload']);
             
             if (_analysisResult == null) {
                _analysisResult = namesRes;
              } else {
                _analysisResult = _analysisResult!.copyWith(
                  bestNames: namesRes.bestNames,
                  similarNames: namesRes.similarNames,
                  isVip: namesRes.isVip,
                );
              }
          } else if (event['type'] == 'error') {
             debugPrint("Stream Error: ${event['message']}");
             // Don't throw to avoid crashing UI completely, but maybe show toast
          }
      }
      
      _isNamesLoading = false;
      _isLoading = false;
      notifyListeners();
      
    } catch (e) {
      _isLoading = false;
      _isSolarLoading = false;
      _isNamesLoading = false;
      debugPrint("Error analyzing: $e");
      notifyListeners();
    }
  }
  
  Future<void> _checkLoginStatus() async {
    _isLoggedIn = await AuthService.isLoggedIn();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
