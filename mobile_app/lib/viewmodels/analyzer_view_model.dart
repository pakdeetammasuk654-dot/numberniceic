import 'dart:async';
import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../models/day_option.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AnalyzerViewModel extends ChangeNotifier {
  // State
  String _currentName = 'ณเดชน์';
  String _selectedDay = 'sunday';
  bool _isAuspicious = false;
  bool _showKlakini = true;
  bool _showTop4 = false;
  bool _showKlakiniTop4 = true;
  bool _isTop4Switching = false;
  bool _isLoading = false;
  
  bool _isSolarLoading = false;
  bool _isNamesLoading = false;
  
  AnalysisResult? _analysisResult;
  bool _isLoggedIn = false;
  
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
  String get selectedDay => _selectedDay;
  bool get isAuspicious => _isAuspicious;
  bool get showKlakini => _showKlakini;
  bool get showTop4 => _showTop4;
  bool get showKlakiniTop4 => _showKlakiniTop4;
  bool get isTop4Switching => _isTop4Switching;
  bool get isLoading => _isLoading;

  bool get isSolarLoading => _isSolarLoading;
  bool get isNamesLoading => _isNamesLoading;
  AnalysisResult? get analysisResult => _analysisResult;
  bool get isLoggedIn => _isLoggedIn;

  // Actions
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
  
  void toggleShowKlakini(bool val) {
    _showKlakini = val;
    notifyListeners();
    analyze();
  }
  
  void toggleShowTop4(bool val) {
    _isTop4Switching = true;
    _showTop4 = val;
    notifyListeners();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      _isTop4Switching = false;
      notifyListeners();
    });
  }
  
  void toggleShowKlakiniTop4(bool val) {
     _showKlakiniTop4 = val;
     _isTop4Switching = true;
     notifyListeners();
     analyze();
     
     Future.delayed(const Duration(milliseconds: 300), () {
       _isTop4Switching = false;
       notifyListeners();
     });
  }

  Future<void> analyze() async {
    if (_currentName.isEmpty) return;
    
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
        disableKlakini: !_showKlakini,
        disableKlakiniTop4: !_showKlakiniTop4,
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
      final namesRes = await ApiService.analyzeName(
         _currentName,
        _selectedDay,
        auspicious: _isAuspicious,
        disableKlakini: !_showKlakini,
        disableKlakiniTop4: !_showKlakiniTop4,
        section: 'names',
      );
      
       if (_analysisResult == null) {
        _analysisResult = namesRes;
      } else {
        _analysisResult = _analysisResult!.copyWith(
          bestNames: namesRes.bestNames,
          similarNames: namesRes.similarNames,
          isVip: namesRes.isVip,
        );
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
