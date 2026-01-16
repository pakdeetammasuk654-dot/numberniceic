import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/name_analysis.dart';
import '../../models/name_character.dart';
import '../shimmering_gold_wrapper.dart';
import 'best_name_card.dart';
import 'analysis_toggles.dart';
import '../background_pattern_painter.dart';

class ActionsSection extends StatefulWidget {
  final String currentName;
  final String selectedDayLabel;
  final List<NameAnalysis>? similarNames;
  final int startRank; // Starting rank of first name in similarNames
  final bool showGoodOnly;
  final bool isVip;
  final bool isLoading;
  final ValueChanged<bool> onToggleGoodOnly;
  final ValueChanged<String> onNameSelected;
  final VoidCallback onShopPressed;
  final VoidCallback? onPageChanged;
  final Set<int> badNumbers;
  final List<NameCharacter>? inputNameChars; // New: For finding Kalakini in input name
  final bool isInputNamePerfect; // New: For shimmering input name

  const ActionsSection({
    Key? key,
    required this.currentName,
    required this.selectedDayLabel,
    required this.similarNames,
    this.startRank = 1, // Default to rank 1
    required this.showGoodOnly,
    required this.isVip,
    this.isLoading = false,
    required this.onToggleGoodOnly,
    required this.onNameSelected,
    required this.onShopPressed,
    this.onPageChanged,
    this.badNumbers = const {},
    this.inputNameChars,
    this.isInputNamePerfect = false,
  }) : super(key: key);

  @override
  State<ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends State<ActionsSection> {
  int _currentPage = 0;
  static const int _pageSize = 100;

  @override
  void didUpdateWidget(ActionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset page if name or filter changes
    if (oldWidget.currentName != widget.currentName || 
        oldWidget.showGoodOnly != widget.showGoodOnly) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prepare filtered list while preserving original rank
    final List<MapEntry<int, NameAnalysis>> fullFilteredList = [];
    if (widget.similarNames != null) {
      for (var i = 0; i < widget.similarNames!.length; i++) {
        final name = widget.similarNames![i];
        
        if (widget.showGoodOnly) {
           final hasKlakini = name.displayNameHtml.any((c) => c.isBad);
           if (!name.hasBadPair && !hasKlakini) {
             fullFilteredList.add(MapEntry(i, name));
           }
        } else {
           fullFilteredList.add(MapEntry(i, name));
        }
      }
    }

    final totalItems = fullFilteredList.length;
    final totalPages = (totalItems / _pageSize).ceil().clamp(1, 999);
    
    // Slice for current page
    final int start = _currentPage * _pageSize;
    final int end = (start + _pageSize) > totalItems ? totalItems : (start + _pageSize);
    final List<MapEntry<int, NameAnalysis>> pagedList = 
        (totalItems > 0) ? fullFilteredList.sublist(start, end) : [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
        // Analysis Header Title
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 5),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.kanit(fontSize: 16, color: isDark ? Colors.white70 : const Color(0xFF334155)),
              children: [
                const TextSpan(text: 'หาชื่อดีให้ '),
                // Quote start
                TextSpan(text: '"', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                
                // Name with Shimmer and Kalakini
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: ShimmeringGoldWrapper(
                    enabled: widget.isInputNamePerfect,
                    child: RichText(
                      text: TextSpan(
                        children: widget.inputNameChars != null 
                            ? widget.inputNameChars!.map((c) => TextSpan(
                                text: c.char, 
                                style: GoogleFonts.kanit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: (c.isBad) 
                                      ? const Color(0xFFEF4444) 
                                      : (widget.isInputNamePerfect 
                                          ? const Color(0xFF7E22CE) 
                                          : const Color(0xFF111827)),
                                ),
                              )).toList()
                            : [
                                TextSpan(
                                  text: widget.currentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                                )
                              ],
                      ),
                    ),
                  ),
                ),
                
                // Quote end
                TextSpan(text: '"', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                
                const TextSpan(text: ' เกิดวัน '),
                TextSpan(text: '"${widget.selectedDayLabel}"', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
              ],
            ),
          ),
        ),

        // 2. Toggles
        AnalysisToggles(
          showGoodOnly: widget.showGoodOnly,
          enabled: !widget.isLoading,
          onToggleGoodOnly: widget.onToggleGoodOnly,
        ),

        // 3. Table Header (Navy)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(flex: 4, child: Text('ชื่อดี / คล้าย', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.normal, color: isDark ? Colors.white60 : Colors.grey[700]))),
              Expanded(flex: 4, child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  Text('ศาสตร์', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.normal, color: isDark ? Colors.white60 : Colors.grey[700])),
                  const SizedBox(width: 16),
                  Text('เงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.normal, color: isDark ? Colors.white60 : Colors.grey[700])),
               ],
              )),
              SizedBox(
               width: 50, 
               child: Text('คะแนน', textAlign: TextAlign.right, style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.normal, color: isDark ? Colors.white60 : Colors.grey[700]))
              ),
              const SizedBox(width: 12),
           ],
         )
        ),

        // Table Rows Container
        Container(
           clipBehavior: Clip.hardEdge,
           decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!, width: 1.5),
           ),
           child: Column(
               children: [
                 if (widget.isLoading)
                   ...List.generate(3, (index) => _buildSkeletonRow()),

                  if (!widget.isLoading && pagedList.isNotEmpty)
                    ...pagedList.asMap().entries
                     .take(widget.isVip ? pagedList.length : 3)
                     .map((entry) {
                       final pagedIdx = entry.key;
                       final filteredEntry = entry.value;
                       final originalIndex = filteredEntry.key; // Original index in full list
                       final name = filteredEntry.value;
                       
                       // Calculate actual rank using startRank
                       final actualRank = widget.startRank + originalIndex;

                       final hasKlakini = name.displayNameHtml.any((c) => c.isBad);
                       // Premium name criteria: isTopTier (all pairs are D10/D8/D5) AND no Klakini
                       final bool shouldBeGold = name.isTopTier && !hasKlakini;
                       
                       // Debug: Print ALL names being rendered
                       print('🔍 [Rank $actualRank] ${name.thName}: isTopTier=${name.isTopTier}, hasKlakini=$hasKlakini, shouldBeGold=$shouldBeGold');

                       return Container(
                         decoration: BoxDecoration(
                           border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 1.0)),
                         ),
                         child: BestNameCard(
                           nameAnalysis: name,
                           rank: actualRank,
                           isGold: shouldBeGold,
                           onTap: () => widget.onNameSelected(name.thName),
                           isCompact: true,
                           forceTransparentBg: true,
                         ),
                       );
                     }),
                    
                 if (!widget.isLoading && pagedList.isEmpty)
                   Padding(
                     padding: const EdgeInsets.all(24),
                     child: Center(child: Text('ไม่พบข้อมูลตามเงื่อนไข', style: GoogleFonts.kanit(color: Colors.grey[500]))),
                   ),
                   
                 if (!widget.isVip && !widget.isLoading && _currentPage == 0)
                   _buildLockedSummary(),
               ],
             ),
        ),

        if (!widget.isLoading && totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildPageButton(
                   icon: Icons.chevron_left_rounded,
                   enabled: _currentPage > 0,
                   onTap: () {
                     setState(() => _currentPage--);
                     widget.onPageChanged?.call();
                   },
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Text(
                    'หน้า ${_currentPage + 1} / $totalPages',
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7E22CE),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildPageButton(
                   icon: Icons.chevron_right_rounded,
                   enabled: _currentPage < totalPages - 1,
                   onTap: () {
                     setState(() => _currentPage++);
                     widget.onPageChanged?.call();
                   },
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

  Widget _buildPageButton({required IconData icon, required bool enabled, required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: enabled 
                  ? const Color(0xFF7E22CE).withOpacity(0.1) 
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: enabled ? const Color(0xFF7E22CE).withOpacity(0.3) : Colors.transparent),
            ),
            child: Icon(
              icon,
              color: enabled ? const Color(0xFF7E22CE) : Colors.white24,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skeletonColor = isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200];
    final borderColor = isDark ? Colors.white10 : Colors.grey[300];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor!, width: 1.0)),
      ),
      child: Row(
        children: [
          Container(width: 30, height: 20, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(4))),
          Expanded(child: Container(height: 20, decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(width: 16),
          Container(width: 24, height: 24, decoration: BoxDecoration(color: skeletonColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Container(width: 24, height: 24, decoration: BoxDecoration(color: skeletonColor, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Container(width: 40, height: 20, decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }

  Widget _buildLockedSection() {
    // Show 7 locked items (positions 4-10)
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(7, (index) {
          final itemNumber = index + 4; // 4, 5, 6, 7, 8, 9, 10
          return _buildLockedItem(itemNumber);
        }),
      ),
    );
  }

  Widget _buildLockedSummary() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
       width: double.infinity,
       padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
       decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!)),
       ),
       child: Column(
          children: [
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], 
                  shape: BoxShape.circle
               ),
               child: Icon(Icons.lock_rounded, size: 32, color: Colors.grey[400]),
             ),
             const SizedBox(height: 16),
             Text(
               "รายชื่อเพิ่มเติมสำหรับ VIP",
               style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[800]),
             ),
             const SizedBox(height: 8),
             Text(
               "ยังมีผลการวิเคราะห์ชื่อดีอีกไม่จำกัด\nซื้อสินค้าเพื่อรับสิทธิ์ VIP",
               textAlign: TextAlign.center,
               style: GoogleFonts.kanit(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey[500]),
             ),
             const SizedBox(height: 20),
             SizedBox(
               width: 200,
               child: ElevatedButton.icon(
                 onPressed: widget.onShopPressed,
                 icon: const Icon(Icons.storefront_rounded, color: Colors.black),
                 label: Text("ร้านชื่อดี", style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
                 style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                 ),
               ),
             )
          ],
       ),
    );
  }

  Widget _buildLockedItem(int rank) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!)),
      ),
      child: Row(
        children: [
           // Rank Badge (Greyed out)
           Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w300, color: isDark ? Colors.white38 : Colors.grey[500]),
              ),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Row(
               children: [
                 Icon(Icons.lock_outline, color: isDark ? Colors.white24 : Colors.grey[400], size: 20),
                 const SizedBox(width: 8),
                 Text(
                   'สำหรับ VIP เท่านั้น',
                   style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white38 : Colors.grey[500]),
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
