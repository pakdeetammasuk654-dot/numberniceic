import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/miracle_service.dart';
import '../services/notification_service.dart';
import 'shimmering_gold_wrapper.dart';
import 'package:intl/intl.dart';
import '../screens/login_page.dart';

class DailyMiracleCard extends StatefulWidget {
  const DailyMiracleCard({super.key});

  @override
  State<DailyMiracleCard> createState() => _DailyMiracleCardState();
}

class _DailyMiracleCardState extends State<DailyMiracleCard> {
  String? _userBirthDay;
  String? _username; // Added username
  Map<String, dynamic>? _dailyLuck;
  bool _isLoading = true;
  bool _isLoggedIn = false; // Added login status
  final MiracleService _service = MiracleService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _service.init();
    final birthDay = await _service.getUserBirthDay();
    final userInfo = await AuthService.getUserInfo();
    final loggedIn = await AuthService.isLoggedIn();
    
    Map<String, dynamic>? luck;
    if (birthDay != null) {
      luck = _service.getDailyLuck(birthDay);
    }

    if (mounted) {
      setState(() {
        _userBirthDay = birthDay;
        _username = userInfo['username'];
        _isLoggedIn = loggedIn;
        _dailyLuck = luck;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBirthDay() async {
    final days = {
      'sunday': 'วันอาทิตย์',
      'monday': 'วันจันทร์',
      'tuesday': 'วันอังคาร',
      'wednesday': 'วันพุธ',
      'thursday': 'วันพฤหัสบดี',
      'friday': 'วันศุกร์',
      'saturday': 'วันเสาร์',
    };

    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      ).then((_) => _loadData());
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent, // Transparent to show rounded corners properly
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: SafeArea( // Add SafeArea
          child: SingleChildScrollView( // Make content scrollable
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text("เลือกวันเกิดของคุณ", style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ...days.entries.map((e) => ListTile(
                  leading: _getDayIcon(e.key),
                  title: Text(e.value, style: GoogleFonts.kanit(fontSize: 16)),
                  onTap: () => Navigator.pop(context, e.key),
                )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true, // Enable full height control
    );

    if (selected != null) {
      // Show loading effect
      setState(() {
        _isLoading = true;
      });
      await Future.delayed(const Duration(milliseconds: 800));

      await _service.saveUserBirthDay(selected);
      
      // Immediate UI Update
      setState(() {
        _userBirthDay = selected;
        _dailyLuck = _service.getDailyLuck(selected);
        _isLoading = false;
      });
      
      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตดวงสำหรับคนเกิด${_service.getThaiDayName(selected)} เรียบร้อยแล้ว'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      
      // Schedule Notifications
      final notifs = _service.generateWeeklyNotifications(selected);
      await NotificationService().scheduleMiracleNotifications(notifs);
    }
  }

  Widget _getDayIcon(String day) {
    Color color;
    switch (day) {
      case 'sunday': color = Colors.red; break;
      case 'monday': color = Colors.yellow.shade700; break;
      case 'tuesday': color = Colors.pink; break;
      case 'wednesday': color = Colors.green; break;
      case 'thursday': color = Colors.orange; break;
      case 'friday': color = Colors.blue; break;
      case 'saturday': color = Colors.purple; break;
      default: color = Colors.grey;
    }
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // Debugging function to print Thursday's luck for all birth days
  void _printThursdayLuck() {
    if (_service.isDataLoaded) { // Check if data is loaded
      final days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      final acts = ['ตัดผม', 'สระผม', 'ตัดเล็บ', 'ผ้าใหม่']; // These activities are hardcoded for verification
      
      print('--- LUCK ON THURSDAY ---');
      for (var birthDay in days) {
         String row = '$birthDay: ';
         for (var activity in acts) {
            // Safely access data, assuming structure is as analyzed
            final val = _service.getSpecificLuck(birthDay, activity, 'thursday');
            row += '$activity=${val?['is_good']}, ';
         }
         print(row);
      }
      print('------------------------');
    } else {
      print('MiracleService data not loaded yet for _printThursdayLuck.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
           color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
           borderRadius: BorderRadius.circular(20),
           boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
           ]
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
      );
    } 

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate Luck Score
    int goodCount = 0;
    int totalCount = 0;
    if (_dailyLuck != null && _dailyLuck!['activities'] != null) {
      final Map<String, dynamic> acts = _dailyLuck!['activities'];
      totalCount = acts.length;
      goodCount = acts.values.where((a) => a['is_good'] == true).length;
    }
    final int score = totalCount > 0 ? ((goodCount / totalCount) * 100).round() : 0;
                  
    Color scoreColor;
    if (score >= 75) scoreColor = Colors.green;
    else if (score >= 50) scoreColor = Colors.orange;
    else scoreColor = Colors.red;

    // Default Container Style
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: isDark 
          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
          : [Colors.white, const Color(0xFFF1F5F9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        width: 1,
      )
    );

    if (_userBirthDay == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: decoration,
        child: Column(
          children: [
            ShimmeringGoldWrapper(
              child: const Icon(Icons.auto_awesome, size: 48, color: Color(0xFFFFD700)),
            ),
            const SizedBox(height: 16),
            if (!_isLoggedIn) ...[
              Text(
                "เข้าสู่ระบบเพื่อดูดวงรายวัน",
                style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 8),
              Text(
                "สระผมวันไหนดี? ตัดเล็บวันไหนเฮง?\nล็อกอินเพื่อดูคำทำนายมงคลของคุณ",
                textAlign: TextAlign.center,
                style: GoogleFonts.kanit(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage())).then((_) => _loadData());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
                child: Text("เข้าสู่ระบบ", style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ] else ...[
              if (_username != null && _username!.isNotEmpty) ...[
                Text(
                  "ยินดีต้อนรับ คุณ$_username",
                  style: GoogleFonts.kanit(fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                "กรุณาใส่วันเกิดเพื่อดูดวง",
                style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 8),
              Text(
                "ตัดผมวันไหนดี? วันนี้ใส่อะไรถึงเฮง?\nเลือกวันเกิดเพื่อดูคำทำนายเฉพาะคุณ",
                textAlign: TextAlign.center,
                style: GoogleFonts.kanit(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _selectBirthDay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
                child: Text("เลือกวันเกิด", style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ),
      );
    }

    // Main Card
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: decoration,
      child: Stack(
        children: [
          // Background Gradient Mesh (Subtle)
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFFFFD700).withOpacity(0.15), Colors.transparent],
                )
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calculate Luck Score
                  // Header: User Info & Edit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ยินดีต้อนรับกลับมาครับ",
                              style: GoogleFonts.kanit(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                            ),
                            if (_username != null && _username!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "คุณ$_username",
                                    style: GoogleFonts.kanit(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: isDark ? Colors.white : const Color(0xFF1E293B)
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "โฉลกคนเกิด${_service.getThaiDayName(_userBirthDay ?? '')} ประจำ${_service.getThaiDayName(_dailyLuck?['current_day'] ?? '')}",
                                style: GoogleFonts.kanit(
                                  fontSize: 18, fontWeight: FontWeight.bold, // Reduced font
                                  color: const Color(0xFFFFC107), // Amber 500 - Stronger gold
                                  height: 1.2,
                                  shadows: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 2,
                                      offset: const Offset(1, 1),
                                    )
                                  ]
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _selectBirthDay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                offset: const Offset(0, 3), 
                                blurRadius: 0, 
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade200)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_calendar, size: 16, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              Text("เลือกวันเกิด", style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 24, thickness: 1),
                
                // Activities Grid
                if (_dailyLuck != null && _dailyLuck!['activities'] != null)
                  _buildActivitiesGrid(_dailyLuck!['activities'], isDark)
                else
                  Center(child: Text("ไม่มีข้อมูลสำหรับวันนี้", style: GoogleFonts.kanit())),
                  
                const SizedBox(height: 12),
                
                // Bottom Tip
                 Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFFF9E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tips_and_updates, size: 18, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "หลักคิด: การดูแลร่างกายให้ถูกโฉลกกับวันตามตำราพรหมชาติ ช่วยเสริมสิริมงคล",
                              style: GoogleFonts.kanit(fontSize: 12, color: isDark ? Colors.white70 : Colors.brown),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.history, size: 10, color: isDark ? Colors.white30 : Colors.brown.withOpacity(0.3)),
                          const SizedBox(width: 4),
                          Text(
                            "ได้รับเมื่อ 07:00 น.",
                            style: GoogleFonts.kanit(
                              fontSize: 10, 
                              color: isDark ? Colors.white30 : Colors.brown.withOpacity(0.5),
                              fontWeight: FontWeight.w400
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesGrid(Map<String, dynamic> activities, bool isDark) {
    // Map specific keys to Icons
    final iconMap = {
      'ตัดผม': Icons.content_cut,
      'สระผม': Icons.spa, // or clean_hands
      'ตัดเล็บ': Icons.back_hand, // closer to nails
      'ผ้าใหม่': Icons.checkroom,
    };

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 2.2, // Wide cards - Adjusted to prevent overflow
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      padding: EdgeInsets.zero,
      children: activities.entries.map((entry) {
        final name = entry.key;
        final data = entry.value;
        final isGood = data['is_good'] == true;
        
        return InkWell(
          onTap: () {
             _showDetailModal(name, data['description']);
          },
          child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
             decoration: BoxDecoration(
               color: isDark ? Colors.white10 : Colors.white,
               borderRadius: BorderRadius.circular(12),
               border: Border.all(
                 color: isGood ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                 width: 1
               ),
               boxShadow: [
                 if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset:const Offset(0,2))
               ]
             ),
             child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(6),
                   decoration: BoxDecoration(
                     color: isGood ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                     shape: BoxShape.circle
                   ),
                   child: Icon(
                     iconMap[name] ?? Icons.star, 
                     size: 16, 
                     color: isGood ? Colors.green : Colors.red
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(name, style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold)),
                       Text(isGood ? "ดี" : "ไม่ดี", style: GoogleFonts.kanit(fontSize: 12, color: isGood ? Colors.green : Colors.red)),
                     ],
                   ),
                 ),
                 Icon(Icons.info_outline, size: 14, color: Colors.grey.withOpacity(0.5))
               ],
             ),
          ),
        );
      }).toList(),
    );
  }

  void _showDetailModal(String title, String description) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        String currentDayKey = _dailyLuck?['current_day'] ?? '';
                        String birthDayKey = _userBirthDay ?? '';
                        String currentDayName = _service.getThaiDayName(currentDayKey);
                        String birthDayName = _service.getThaiDayName(birthDayKey);
                        
                        return RichText(
                          textAlign: TextAlign.start,
                          text: TextSpan(
                            style: GoogleFonts.kanit(
                              fontSize: 16, // Smaller as requested (was 22)
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF475569), // Default text color
                              shadows: [
                                const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
                              ]
                            ),
                            children: [
                              TextSpan(
                                text: '"$title" ',
                                style: TextStyle(color: const Color(0xFFF59E0B)), // Activity Name in Gold
                              ),
                              TextSpan(
                                text: currentDayName,
                                style: TextStyle(color: _getDayColor(currentDayKey)), // Highlight current day
                              ),
                              const TextSpan(text: '\n'),
                              TextSpan(
                                text: 'สำหรับคนเกิด ',
                                style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: '($birthDayName)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getDayColor(birthDayKey), // Highlight birth day
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  if (_getIconPath(title) != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Image.asset(
                        _getIconPath(title)!,
                        width: 64,
                        height: 64,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                description, 
                style: GoogleFonts.sarabun(fontSize: 16, height: 1.5), // Use Sarabun for readability
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: Text("เข้าใจแล้ว", style: GoogleFonts.kanit()),
                ),
              )
            ],
          ),
        );
      }
    );
  }
  String? _getIconPath(String title) {
    if (title.contains("ตัดผม")) return "assets/images/hair_cut.png";
    if (title.contains("สระผม")) return "assets/images/hair_washing.png";
    if (title.contains("ตัดเล็บ")) return "assets/images/nail.png";
    if (title.contains("ผ้าใหม่")) return "assets/images/clothes.png";
    return null;
  }

  Color _getDayColor(String dayKey) {
    switch (dayKey.toLowerCase()) {
      case 'sunday': return const Color(0xFFEF4444); // Red
      case 'monday': return const Color(0xFFEAB308); // Yellow (Tailwind Yellow 600 for better visibility)
      case 'tuesday': return const Color(0xFFEC4899); // Pink
      case 'wednesday': return const Color(0xFF10B981); // Green
      case 'thursday': return const Color(0xFFF59E0B); // Orange
      case 'friday': return const Color(0xFF3B82F6); // Blue
      case 'saturday': return const Color(0xFF8B5CF6); // Purple
      default: return const Color(0xFF64748B); // Slate
    }
  }
}
