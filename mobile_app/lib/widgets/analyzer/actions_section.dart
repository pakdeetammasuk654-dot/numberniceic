import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/name_analysis.dart';
import '../shimmering_gold_wrapper.dart';

class ActionsSection extends StatelessWidget {
  final List<NameAnalysis>? similarNames;
  final bool showKlakini;
  final bool showGoodOnly;
  final bool isVip;
  final bool isLoading;
  final ValueChanged<bool> onToggleKlakini;
  final ValueChanged<bool> onToggleGoodOnly;
  final ValueChanged<String> onNameSelected;
  final VoidCallback onShopPressed;
  final Set<int> badNumbers;


  const ActionsSection({
    Key? key,
    required this.similarNames,
    required this.showKlakini,
    required this.showGoodOnly,
    required this.isVip,
    this.isLoading = false,
    required this.onToggleKlakini,
    required this.onToggleGoodOnly,
    required this.onNameSelected,
    required this.onShopPressed,
    this.badNumbers = const {}, // Empty default, essentially required logic-wise but preventing break
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // const badNumbers = ... removed, using field.

    // Prepare filtered list while preserving original rank
    final List<MapEntry<int, NameAnalysis>> filteredList = [];
    if (similarNames != null) {
      for (var i = 0; i < similarNames!.length; i++) {
        final name = similarNames![i];
        
        if (showGoodOnly) {
           final isNumBad = _isListBad(name.tSat);
           final isShaBad = _isListBad(name.tSha);
           // Only add if BOTH are good (not bad)
           if (!isNumBad && !isShaBad) {
             filteredList.add(MapEntry(i, name));
           }
        } else {
           filteredList.add(MapEntry(i, name));
        }
      }
    }

    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          // VIP Banner
          // VIP Banner removed as per request
          
          Container(
            color: const Color(0xFF16213E),
            height: 16,
          ),

          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Toggle: Show Good Only
                  Row(
                    children: [
                      Text('แสดงเลขดีเท่านั้น', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF34D399))),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch.adaptive(
                          value: showGoodOnly,
                          onChanged: onToggleGoodOnly, 
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Toggle: Show Klakini
                  Row(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.kanit(fontSize: 12, color: Colors.white54),
                          children: [
                            const TextSpan(text: 'แสดง'),
                            TextSpan(text: 'กาลกิณี', style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
                          ]
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch.adaptive(
                          value: showKlakini,
                          onChanged: onToggleKlakini,
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1F2E4D), // Lighter Navy Header
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('ชื่อดี', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11))),
              Expanded(flex: 2, child: Center(child: Text('ศาสตร์', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 10, height: 1.0)))),
              Expanded(flex: 2, child: Center(child: Text('เงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 10, height: 1.0)))),
              Expanded(flex: 2, child: Center(child: Text('คะแนน', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11)))),
              const SizedBox(width: 34), // Arrow space
            ],
          ),
        ),

        // Table Rows
        if (isLoading) ...[
          ...List.generate(3, (index) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12, width: 1.0)),
              color: Color(0xFF16213E),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Expanded(flex: 2, child: Center(child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle)))),
                Expanded(flex: 2, child: Center(child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle)))),
                Expanded(flex: 2, child: Center(child: Container(width: 40, height: 24, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6))))),
                Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12))),
              ],
            ),
          )),
        ],

        if (!isLoading && filteredList.isNotEmpty)
          ...filteredList
              .take(isVip ? filteredList.length : 3)
              .toList()
              .asMap()
              .entries
              .map((entry) {
            final displayIndex = entry.key; // 0, 1, 2... in the processed list
            final filteredEntry = entry.value; 
            final originalIndex = filteredEntry.key; // Original index in validNames
            final name = filteredEntry.value;

             final isNumBad = _isListBad(name.tSat);
             final isShaBad = _isListBad(name.tSha);
             final isScorePos = name.totalScore >= 0;
             final hasKlakini = name.displayNameHtml.any((c) => c.isBad);
             final isPerfectName = !isNumBad && !isShaBad && !hasKlakini;
             final isTop3 = originalIndex < 3;
             
             // A name should be gold/shimmer if it's PerfectName (Good Num + Good Shadow + No Klakini)
             // regardless of rank.
             final bool shouldBeGold = isPerfectName;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: shouldBeGold ? const Color(0xFFFFD700) : Colors.white12, width: 1.0)),
                color: shouldBeGold ? const Color(0xFF2C250E) : Colors.transparent, // Gold tint or transparent
              ),
              child: Row(
                children: [
                  // Rank & Name
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTop3) ...[
                                if (showGoodOnly)
                                  const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 16),
                                Text('#${originalIndex + 1}', style: GoogleFonts.kanit(fontSize: showGoodOnly ? 10 : 12, color: const Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                              ] else 
                                Text('#${originalIndex + 1}', style: GoogleFonts.kanit(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShimmeringGoldWrapper(
                            enabled: shouldBeGold,
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.kanit(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: shouldBeGold ? const Color(0xFFFFD700) : Colors.white
                                ),
                                children: name.displayNameHtml.map((char) {
                                  return TextSpan(
                                    text: char.char,
                                      style: TextStyle(
                                        color: char.isBad 
                                            ? (showKlakini ? const Color(0xFFFF4757) : (shouldBeGold ? const Color(0xFFFFD700) : Colors.white))
                                            : (shouldBeGold ? const Color(0xFFFFD700) : Colors.white),
                                      ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Numerology
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                         width: 24, height: 24, 
                         alignment: Alignment.center,
                          decoration: BoxDecoration(
                           color: _getDynamicColor(name.tSat), 
                           shape: BoxShape.circle,
                           boxShadow: [
                             BoxShadow(
                               color: _getDynamicColor(name.tSat).withOpacity(0.3),
                               blurRadius: 4,
                               offset: const Offset(0, 2),
                             )
                           ]
                         ),
                         child: Text(
                           '${name.totalNumerology}',
                           style: GoogleFonts.kanit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold) 
                         ),
                      ),
                    )
                  ),

                  // Shadow
                  Expanded(
                    flex: 2,
                    child: Center(
                       child: Container(
                         width: 24, height: 24, 
                         alignment: Alignment.center,
                          decoration: BoxDecoration(
                           color: _getDynamicColor(name.tSha),
                           shape: BoxShape.circle,
                           boxShadow: [
                             BoxShadow(
                               color: _getDynamicColor(name.tSha).withOpacity(0.3),
                               blurRadius: 4,
                               offset: const Offset(0, 2),
                             )
                           ]
                         ),
                         child: Text(
                           '${name.totalShadow}',
                           style: GoogleFonts.kanit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold) 
                         ),
                       )
                    )
                  ),

                  // Score
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                          '${isScorePos ? '+' : ''}${name.totalScore}',
                          style: GoogleFonts.kanit(
                            color: isScorePos ? Colors.greenAccent : Colors.redAccent, 
                            fontWeight: FontWeight.w900, 
                            fontSize: 14
                          ),
                      ),
                    ),
                  ),

                  // Arrow
                  GestureDetector(
                    onTap: () => onNameSelected(name.thName),
                    child: Container(
                      width: 32,
                      height: 32,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 18, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            );
          }),

            
          if (!isLoading && filteredList.isEmpty)
             Padding(
               padding: const EdgeInsets.all(24),
               child: Center(child: Text('ไม่พบข้อมูลตามเงื่อนไข', style: GoogleFonts.kanit(color: Colors.white54))),
             ),
             

          if (!isVip && !isLoading) _buildLockedSection(),
      ],
    ),
  );
}

  Widget _buildLockedSection() {
    // Show 7 locked items (positions 4-10)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (index) {
        final itemNumber = index + 4; // 4, 5, 6, 7, 8, 9, 10
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12, width: 1.0)),
            color: Color(0xFF2A2A3E), // Gray locked background
          ),
          child: Stack(
            children: [
              // Grayed out content
              Opacity(
                opacity: 0.3,
                child: Row(
                  children: [
                    // Rank & Name
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '#$itemNumber',
                              style: GoogleFonts.kanit(
                                fontSize: 12,
                                color: Colors.white38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Numerology circle
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    // Shadow circle
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    // Score
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Arrow
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              // Lock overlay in center
              if (index == 3) // Show message on middle item (item #7)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD700), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock, color: Color(0xFFFFD700), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'ปลดล็อกด้วย VIP',
                            style: GoogleFonts.kanit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFD700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  bool _isListBad(List<Map<String, dynamic>>? list) {
    if (list == null || list.isEmpty) return false;
    return list.any((item) {
      final color = (item['color'] as String? ?? '').toUpperCase();
      final type = (item['type'] as String? ?? '').toUpperCase();
      
      // Check for Red colors (EF4444, D32F2F) or explicit 'Bad' type (R-prefix like R10, or 'BAD')
      final isBadColor = color.contains('EF4444') || color.contains('D32F2F') || color.contains('RED');
      final isBadType = type.startsWith('R') || type.contains('BAD');
      
      return isBadColor || isBadType;
    });
  }

  Color _getDynamicColor(List<Map<String, dynamic>>? list) {
    String? foundColor;
    if (list != null) {
      for (var item in list) {
        final c = item['color'] as String?;
        if (c != null && c.isNotEmpty) {
           foundColor = c;
           break; 
        }
      }
    }
    
    if (foundColor != null) {
       final parsed = _parseColor(foundColor);
       if (parsed != null) return parsed;
    }
    
    // Fallback based on badness (Red) or default Green
    return _isListBad(list) ? const Color(0xFFEF4444) : const Color(0xFF1B5E20);
  }

  Color? _parseColor(String hexCode) {
    try {
      String cleanHex = hexCode.toUpperCase().replaceAll('#', '').replaceAll('0X', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('0xFF$cleanHex'));
      } else if (cleanHex.length == 8) {
        return Color(int.parse('0x$cleanHex'));
      }
    } catch (_) {}
    return null; 
  }
}
