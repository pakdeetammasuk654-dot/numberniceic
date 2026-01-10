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

    return Column(
      children: [
        // VIP Banner
        if (!isVip)
          GestureDetector(
            onTap: () {
               // Initial action, maybe navigate to shop
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107), // Amber 500
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF212121), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ท่านจะได้เป็น VIP', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF212121))),
                        Text('เมื่ออุดหนุนสินค้า', style: GoogleFonts.kanit(fontSize: 14, color: const Color(0xFF424242))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF263238),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text('ร้านมาดี', style: GoogleFonts.kanit(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 16),

        // Toggles
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Toggle: Show Good Only
              Column(
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      value: showGoodOnly,
                      onChanged: onToggleGoodOnly, 
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF2E7D32),
                    ),
                  ),
                  Text('แสดงเลขดีเท่านั้น', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32))), 
                ],
              ),
              const SizedBox(width: 16),
              
              // Toggle: Show Klakini
              Column(
                children: [
                   Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      value: showKlakini,
                      onChanged: onToggleKlakini,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFFD32F2F), // Red Track
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600]),
                      children: [
                        const TextSpan(text: 'แสดง'),
                        TextSpan(text: 'กาลกิณี', style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                      ]
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF8FAFC),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('ชื่อดี', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 11))),
              Expanded(flex: 2, child: Center(child: Text('เลข\nศาสตร์', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 10, height: 1.0)))),
              Expanded(flex: 2, child: Center(child: Text('พลัง\nเงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 10, height: 1.0)))),
              Expanded(flex: 2, child: Center(child: Text('คะแนน', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 11)))),
              Expanded(flex: 2, child: Center(child: Text('คล้าย', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFF64748B), fontSize: 11)))),
              const SizedBox(width: 34), // Arrow space
            ],
          ),
        ),

        // Table Rows
        if (isLoading) ...[
          ...List.generate(3, (index) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              border: const Border(bottom: BorderSide(color: Color(0xFFFFD54F), width: 1.0)),
              color: const Color(0xFFFFFDE7),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Expanded(flex: 2, child: Center(child: Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)))),
                Expanded(flex: 2, child: Center(child: Container(width: 24, height: 24, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)))),
                Expanded(flex: 2, child: Center(child: Container(width: 40, height: 24, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6))))),
                Expanded(flex: 2, child: Center(child: Container(width: 30, height: 16, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))))),
                Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12))),
              ],
            ),
          )),
           if (!isVip) _buildLockedSection(),
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

            // Notice strict limit logic removed from here as we use .take()
 
             final isNumBad = _isListBad(name.tSat);
             final isShaBad = _isListBad(name.tSha);
             final isScorePos = name.totalScore >= 0;
             final hasKlakini = name.displayNameHtml.any((c) => c.isBad);
             final isPerfectName = !isNumBad && !isShaBad && !hasKlakini;
             final isTop3 = originalIndex < 3;

            // Helper for bubble style
            BoxDecoration getBubbleDecoration(bool isBad) {
              if (isBad) return const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle); // Red
              return const BoxDecoration(color: Color(0xFF1B5E20), shape: BoxShape.circle); // Green
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                border: const Border(bottom: BorderSide(color: Color(0xFFFFD54F), width: 1.0)),
                color: const Color(0xFFFFFDE7),
              ),
              child: Row(
                children: [
                  // Rank & Name
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTop3) ...[
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                Text('#${originalIndex + 1}', style: GoogleFonts.kanit(fontSize: 10, color: Colors.amber[800], fontWeight: FontWeight.bold)),
                              ] else 
                                Text('#${originalIndex + 1}', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShimmeringGoldWrapper(
                            // Disable gold shimmer if we are showing Klakini and the name has any bad chars
                            enabled: (isTop3 || isPerfectName) && !(showKlakini && name.displayNameHtml.any((c) => c.isBad)),
                            child: RichText(
                              text: TextSpan(
                                // Use black base color if showing Klakini and name is bad, overriding Top3 gold
                                style: GoogleFonts.kanit(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: ((isTop3 || isPerfectName) && !(showKlakini && name.displayNameHtml.any((c) => c.isBad))) 
                                    ? const Color(0xFF8B6F00) 
                                    : Colors.black87
                                ),
                                children: name.displayNameHtml.map((char) {
                                  // Determine base color for this character
                                  // If Top3 AND NOT (Showing Bad & Has Bad), default to Gold. Else Black.
                                  final bool isGoldMode = (isTop3 || isPerfectName) && !(showKlakini && name.displayNameHtml.any((c) => c.isBad));
                                  
                                  return TextSpan(
                                    text: char.char,
                                      style: TextStyle(
                                        color: char.isBad 
                                            ? (showKlakini ? const Color(0xFFFF1744) : (isGoldMode ? const Color(0xFF8B6F00) : Colors.black87))
                                            : (isGoldMode ? const Color(0xFF8B6F00) : Colors.black87),
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
                           color: isNumBad ? const Color(0xFFEF4444) : const Color(0xFF1B5E20), // Red if Bad (from API), Dark Green if Good
                           shape: BoxShape.circle,
                           boxShadow: [
                             BoxShadow(
                               color: (isNumBad ? const Color(0xFFEF4444) : const Color(0xFF1B5E20)).withOpacity(0.3),
                               blurRadius: 4,
                               offset: const Offset(0, 2),
                             )
                           ]
                         ),
                         child: Text(
                           '${name.totalNumerology}',
                           style: GoogleFonts.kanit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold) // Reduced from 13
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
                           color: isShaBad ? const Color(0xFFEF4444) : const Color(0xFF1B5E20), // Red if Bad (from API), Dark Green if Good
                           shape: BoxShape.circle,
                           boxShadow: [
                             BoxShadow(
                               color: (isShaBad ? const Color(0xFFEF4444) : const Color(0xFF1B5E20)).withOpacity(0.3),
                               blurRadius: 4,
                               offset: const Offset(0, 2),
                             )
                           ]
                         ),
                         child: Text(
                           '${name.totalShadow}',
                           style: GoogleFonts.kanit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold) // Reduced from 13
                         ),
                       )
                    )
                  ),

                  // Score
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isScorePos ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), // Green 50 : Red 50
                          borderRadius: BorderRadius.circular(6)
                        ),
                        child: Text(
                          '${isScorePos ? '+' : ''}${name.totalScore}',
                          style: GoogleFonts.kanit(
                            color: isScorePos ? const Color(0xFF2E7D32) : const Color(0xFFC62828), 
                            fontWeight: FontWeight.w900, 
                            fontSize: 13
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Similarity
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        '${name.similarity <= 1 ? (name.similarity * 100).round() : name.similarity.round()}%',
                        style: GoogleFonts.kanit(color: Colors.black54, fontSize: 13),
                      ),
                    ),
                  ),

                  // Arrow
                  GestureDetector(
                    onTap: () => onNameSelected(name.thName),
                    child: Container(
                      width: 34,
                      height: 34,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                            BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                            )
                        ]
                      ),
                      child: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 18, color: Colors.green),
                    ),
                  ),
                ],
              ),
            );
          }),

            
          if (!isLoading && filteredList.isEmpty)
             Padding(
               padding: const EdgeInsets.all(24),
               child: Center(child: Text('ไม่พบข้อมูลตามเงื่อนไข', style: GoogleFonts.kanit(color: Colors.grey))),
             ),
             
          // Permanently Attached Locked Section for Non-VIP
          if (!isVip && !isLoading) _buildLockedSection(),
      ],
    );
  }

  Widget _buildLockedSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Golden Gradient Line
        Container(
          height: 2,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFBF953F),
                Color(0xFFFCF6BA),
                Color(0xFFB38728),
                Color(0xFFFBF5B7),
                Color(0xFFAA771C),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          color: const Color(0xFFFFFDE7), // Light yellow background
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text('ชื่อดีล็อกแสดง 3 รายชื่อเท่านั้น', style: GoogleFonts.kanit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                    // Navigate to Shop
                },
                child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                    color: const Color(0xFFFB8C00), // Orange 700
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                        BoxShadow(
                        color: const Color(0xFFE65100), // Darker orange shadow
                        offset: const Offset(0, 4),
                        blurRadius: 0, 
                        )
                    ]
                    ),
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('ซื้อสินค้าร้านมาดี', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                    ),
                ),
              ),
            ],
          ),
        ),
        // Bottom Yellow Bar
        Container(
          height: 8,
          width: double.infinity,
          color: const Color(0xFFFFC107), // Amber
        ),
      ],
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
}
