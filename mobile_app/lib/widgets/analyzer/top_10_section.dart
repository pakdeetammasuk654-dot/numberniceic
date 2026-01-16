import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/best_names_data.dart';
import '../../models/name_character.dart';
import 'best_name_card.dart';
import '../shimmering_gold_wrapper.dart';
import '../background_pattern_painter.dart';

class Top10Section extends StatelessWidget {
  final BestNamesData? data;
  final bool showTop10;
  final bool showGoodOnly;
  final bool isLoading;
  final bool isSwitching;
  final bool isVip;
  final ValueChanged<bool> onToggleTop10;
  final Function(String name) onNameSelected;

  const Top10Section({
    Key? key,
    required this.data,
    required this.showTop10,
    required this.showGoodOnly,
    this.isLoading = false,
    this.isSwitching = false,
    this.isVip = false,
    required this.onToggleTop10,
    required this.onNameSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
     if (isLoading) {
       return _buildSkeleton();
     }

     if (isSwitching && data == null) {
       return _buildSkeleton();
     }
     
     if (data == null) return const SizedBox.shrink();

     final top10 = data!.top10; // Now contains 10 items from backend
     final recommended = data!.recommended; // Now contains 10 items (ranks #91-#100)
     final targetNameHtml = data!.targetNameHtml;
     
     final names = showTop10 ? top10 : (recommended.isNotEmpty ? recommended : top10);
     
     // Filter Logic: Hide Kalakini names if toggle is OFF
      final visibleNames = names.where((name) {
        // If showGoodOnly is true, we ONLY show non-Klakini names.
        // If showGoodOnly is false, we show all names (including Klakini).
        if (!showGoodOnly) return true; 
       
       print('🔍 [Top10] Checking: ${name.thName}');
       
       // Check if name has any bad characters
       final displayHtml = name.displayNameHtml;
       print('   displayNameHtml: ${displayHtml?.length ?? 0} chars');
       
       if (displayHtml == null || displayHtml.isEmpty) {
         print('   ✅ CLEAN (no HTML)');
         return true;
       }
       
       for (var charData in displayHtml) {
         print('   char: "${charData.char}", isBad: ${charData.isBad}');
         if (charData.isBad == true) {
           print('   ❌ DIRTY (has bad char)');
           return false; // Hide names with bad characters
         }
       }
       print('   ✅ CLEAN');
       return true; // Show clean names
     }).toList();
     
     print('📊 [Top10] Total: ${names.length}, Visible: ${visibleNames.length}');
     
     final bool isActuallyShowingTop10 = showTop10 || recommended.isEmpty;
     final String titlePrefix = 'ตั้งชื่อดีให้ ';
     
     if (visibleNames.isEmpty) return const SizedBox.shrink();
     
     // Theme Logic
    final bool isGold = isActuallyShowingTop10;
    final Color themeColor = isGold ? const Color(0xFFFFD700) : const Color(0xFFC5E1A5);
    final List<Color> gradientColors = isGold 
        ? [Colors.white, const Color(0xFFFFFDE7)]
        : [Colors.white, const Color(0xFFF1F8E9)];

    // Calculate ranks for LAST10 display (#91-#100)
    int getLastRank(int index) {
      final total = data!.totalBest;
      return (total - names.length + index + 1).toInt();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.zero, // Remove horizontal padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildHeader(titlePrefix, targetNameHtml, isActuallyShowingTop10, visibleNames.length),
          ),
          const SizedBox(height: 12),
          
          // 2. Toggles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildToggles(),
          ),
          const SizedBox(height: 16),

          // 3. Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Light Header
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('ชื่อดี', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey[700]))),
                Expanded(flex: 4, child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                      Text('ศาสตร์', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.grey[700])),
                      const SizedBox(width: 16),
                      Text('เงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.grey[700])),
                   ],
                )),
                SizedBox(
                   width: 50, 
                   child: Text('คะแนน', textAlign: TextAlign.right, style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey[700]))
                ),
                const SizedBox(width: 12),
                SizedBox(width: 28),
              ],
            ),
          ),
          
          // 4. List (10 items)
          isSwitching
              ? _buildSkeletonGrid()
              : Container(
                   clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), // Light Slate Background
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), 
                      border: Border.all(color: Colors.grey[300]!, width: 1.5), 
                   ),
                   child: CustomPaint(
                     painter: BackgroundPatternPainter(
                       color: const Color(0xFF94A3B8), // Slate 400 for pattern
                       opacity: 0.1, // Very subtle
                     ),
                     child: ListView.separated(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       padding: EdgeInsets.zero,
                       itemCount: visibleNames.length > 10 ? 10 : visibleNames.length,
                       separatorBuilder: (context, index) => Container(height: 1, color: Colors.grey[200]),
                     itemBuilder: (context, index) {
                       final name = visibleNames[index];
                       final rank = isActuallyShowingTop10 ? (index + 1) : getLastRank(index);
                       
                       // VIP Locking Logic: Lock first 7 items (Rank 1-7 or Rank 91-97)
                       if (index < 7 && !isVip) {
                          return _buildLockedItem(rank);
                       }

                       // Calculate isGold based on name's properties, not display mode
                       final hasKlakini = name.displayNameHtml?.any((c) => c.isBad) ?? false;
                       final shouldBeGold = name.isTopTier && !hasKlakini;

                       return BestNameCard(
                         nameAnalysis: name,
                         rank: rank,
                         isGold: shouldBeGold,
                         onTap: () => onNameSelected(name.thName),
                         isCompact: true,
                         forceTransparentBg: true,
                       );
                     },
                   ),
                 ),
               ),
        ],
      ),
    );
  }

  Widget _buildLockedItem(int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
           // Rank Badge (Greyed out)
           Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w300, color: Colors.grey[600]),
              ),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Row(
               children: [
                 Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
                 const SizedBox(width: 8),
                 Text(
                   'สำหรับ VIP เท่านั้น',
                   style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[500]),
                 ),
               ],
             ),
           ),
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
             decoration: BoxDecoration(
               color: const Color(0xFFFFD700),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Text('VIP', style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
           )
        ],
      ),
    );
  }

  Widget _buildHeader(String prefix, List<NameCharacter> targetNameHtml, bool isActuallyShowingTop10, int count) {
     return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF388E3C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            prefix,
                            style: GoogleFonts.kanit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          Text(' "', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2D3748))),
                          ShimmeringGoldWrapper(
                            // ENABLED if No Bad Letters
                            enabled: !targetNameHtml.any((dc) => dc.isBad),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: targetNameHtml.map((dc) => Text(
                                dc.char,
                                style: GoogleFonts.kanit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: dc.isBad == true ? const Color(0xFFFF4757) : const Color(0xFFC59D00),
                                ),
                              )).toList(),
                            ),
                          ),
                          Text('"', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2D3748))),
                        ],
                      ),
                      if (!isActuallyShowingTop10) 
                         Builder(builder: (context) {
                            final total = data!.totalBest;
                            final start = total - count + 1;
                            return Text(
                              'ลำดับที่ #$start - #$total',
                               style: GoogleFonts.kanit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.grey[600],
                                ),
                            );
                         }),
                    ],
                  ),
              ),
            ],
          );
  }

  Widget _buildToggles() {
    return Center(
      child: Column(
        children: [
          // VIP Toggle
          Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                decoration: BoxDecoration(
                  color: showTop10 ? const Color(0xFFFFF1C1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: showTop10 ? const Color(0xFFFFD54F) : Colors.grey[300]!, width: 1.5),
                  boxShadow: [
                    if (showTop10)
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: showTop10 ? Colors.orange : Colors.grey[400], size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'TOP10',
                      style: GoogleFonts.kanit(
                        fontSize: 16, 
                        fontWeight: FontWeight.w900, 
                        color: showTop10 ? Colors.orange[800] : Colors.grey[500]
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 28,
                      width: 44,
                      child: Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: showTop10,
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF388E3C),
                          onChanged: onToggleTop10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
        margin: const EdgeInsets.only(bottom: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Header Skeleton
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 20, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)))),
              ],
            ),
            const SizedBox(height: 20),
            // Toggles
            Row(
              children: [
                 Container(width: 120, height: 36, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(30))),
                 const SizedBox(width: 24),
                 Container(width: 150, height: 36, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(30))),
              ],
            ),
            const SizedBox(height: 24),
            _buildSkeletonGrid(),
          ],
        ),
    );
  }

  Widget _buildSkeletonGrid() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 310),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 2.5),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSingleSkeletonCard()),
                      Container(width: 2, color: Colors.white12),
                      Expanded(child: _buildSingleSkeletonCard()),
                    ],
                  ),
                ),
                Container(height: 2, color: Colors.white12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSingleSkeletonCard()),
                      Container(width: 2, color: Colors.white12),
                      Expanded(child: _buildSingleSkeletonCard()),
                    ],
                  ),
                ),
              ],
            ),
            if (isLoading || isSwitching)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 40, height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700))),
                        ),
                        const SizedBox(height: 16),
                        Text('กำลังวิเคราะห์ชื่อ +3 แสนรายชื่อ...', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
                        const SizedBox(height: 4),
                        Text('เพื่อค้นหาชื่อที่ดีที่สุดสำหรับคุณ', style: GoogleFonts.kanit(fontSize: 13, color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSkeletonCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Container(width: 80, height: 20, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
          ],
        ),
        const SizedBox(height: 8),
        Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Container(width: 1.5, height: 20, color: Colors.white10),
            const SizedBox(width: 12),
            Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle)),
          ],
        ),
      ],
    );
  }
}
