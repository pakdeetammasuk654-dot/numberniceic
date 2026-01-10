import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/best_names_data.dart';
import '../../models/name_character.dart';
import 'best_name_card.dart';
import '../shimmering_gold_wrapper.dart';

class Top4Section extends StatelessWidget {
  final BestNamesData? data;
  final bool showTop4;
  final bool showKlakini;
  final bool isLoading;
  final bool isSwitching;
  final ValueChanged<bool> onToggleTop4;
  final ValueChanged<bool> onToggleKlakini;
  final Function(String name) onNameSelected;

  const Top4Section({
    Key? key,
    required this.data,
    required this.showTop4,
    required this.showKlakini,
    this.isLoading = false,
    this.isSwitching = false,
    required this.onToggleTop4,
    required this.onToggleKlakini,
    required this.onNameSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
     if (isSwitching && data == null) {
       return _buildSkeleton();
     }
     
     if (data == null) return const SizedBox.shrink();

     final top4 = data!.top4;
     final recommended = data!.recommended;
     final targetNameHtml = data!.targetNameHtml;
     
     final names = showTop4 ? top4 : (recommended.isNotEmpty ? recommended : top4);
     final bool isActuallyShowingTop4 = showTop4 || recommended.isEmpty;
     final String titlePrefix = 'ตั้งชื่อดีให้ ';
     
     if (names.isEmpty) return const SizedBox.shrink();
     
     // Theme Logic
    final bool isGold = isActuallyShowingTop4;
    final Color themeColor = isGold ? const Color(0xFFFFD700) : const Color(0xFFC5E1A5);
    final List<Color> gradientColors = isGold 
        ? [Colors.white, const Color(0xFFFFFDE7)]
        : [Colors.white, const Color(0xFFF1F8E9)];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          _buildHeader(titlePrefix, targetNameHtml, isActuallyShowingTop4, names.length),
          const SizedBox(height: 24),
          
          // 2. Toggles
          _buildToggles(),
          const SizedBox(height: 12),
          
          // 3. Grid
          isSwitching
              ? _buildSkeletonGrid()
              : ConstrainedBox(
                   constraints: const BoxConstraints(maxHeight: 320),
                   child: Container(
                     clipBehavior: Clip.hardEdge,
                     decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeColor, width: 2.5),
                     ),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          // Top Row (Names 0, 1)
                          SizedBox(
                             height: 155,
                             child: Row(
                               crossAxisAlignment: CrossAxisAlignment.stretch,
                               children: [
                                  Expanded(child: BestNameCard(
                                    nameAnalysis: names[0],
                                    rank: isActuallyShowingTop4 ? 1 : (data!.totalBest) - 3,
                                    isGold: isGold,
                                    showKlakini: showKlakini,
                                    onTap: () => onNameSelected(names[0].thName),
                                  )),
                                  Container(width: 2, color: themeColor),
                                  Expanded(child: BestNameCard(
                                    nameAnalysis: names[1],
                                    rank: isActuallyShowingTop4 ? 2 : (data!.totalBest) - 2,
                                    isGold: isGold,
                                    showKlakini: showKlakini,
                                    onTap: () => onNameSelected(names[1].thName),
                                  )),
                               ],
                             ),
                          ),
                          Container(height: 2, color: themeColor),
                          // Bottom Row (Names 2, 3)
                          // Check if names has enough items usually it is fixed 4
                          if (names.length >= 4)
                          SizedBox(
                             height: 155,
                             child: Row(
                               crossAxisAlignment: CrossAxisAlignment.stretch,
                               children: [
                                  Expanded(child: BestNameCard(
                                    nameAnalysis: names[2],
                                    rank: isActuallyShowingTop4 ? 3 : (data!.totalBest) - 1,
                                    isGold: isGold,
                                    showKlakini: showKlakini,
                                    onTap: () => onNameSelected(names[2].thName),
                                  )),
                                  Container(width: 2, color: themeColor),
                                  Expanded(child: BestNameCard(
                                    nameAnalysis: names[3],
                                    rank: isActuallyShowingTop4 ? 4 : (data!.totalBest),
                                    isGold: isGold,
                                    showKlakini: showKlakini,
                                    onTap: () => onNameSelected(names[3].thName),
                                  )),
                               ],
                             ),
                          ),
                       ],
                     ),
                   ),
              ),
        ],
      ),
    );
  }

  Widget _buildHeader(String prefix, List<NameCharacter> targetNameHtml, bool isActuallyShowingTop4, int count) {
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
                      if (!isActuallyShowingTop4) 
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
    return Row(
            children: [
              // VIP Toggle
              Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                decoration: BoxDecoration(
                  color: showTop4 ? const Color(0xFFFFF1C1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: showTop4 ? const Color(0xFFFFD54F) : Colors.grey[300]!, width: 1.5),
                  boxShadow: [
                    if (showTop4)
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: showTop4 ? Colors.orange : Colors.grey[400], size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'TOP4',
                      style: GoogleFonts.kanit(
                        fontSize: 16, 
                        fontWeight: FontWeight.w900, 
                        color: showTop4 ? Colors.orange[800] : Colors.grey[500]
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 28,
                      width: 44,
                      child: Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: showTop4,
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF388E3C),
                          onChanged: onToggleTop4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Klakini Toggle
               Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   RichText(
                    text: TextSpan(
                      style: GoogleFonts.kanit(color: const Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.normal),
                      children: [
                        const TextSpan(text: 'แสดง'),
                        TextSpan(text: 'กาลกิณี', style: TextStyle(color: Colors.red[700])),
                      ]
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 28,
                    width: 44,
                    child: Transform.scale(
                      scale: 1.0,
                      child: Switch(
                      value: showKlakini,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF388E3C),
                      onChanged: onToggleKlakini,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 20, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)))),
              ],
            ),
            const SizedBox(height: 20),
            // Toggles
            Row(
              children: [
                 Container(width: 120, height: 36, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30))),
                 const SizedBox(width: 24),
                 Container(width: 150, height: 36, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30))),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 2.5),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSingleSkeletonCard()),
                      Container(width: 2, color: Colors.grey[200]),
                      Expanded(child: _buildSingleSkeletonCard()),
                    ],
                  ),
                ),
                Container(height: 2, color: Colors.grey[200]),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSingleSkeletonCard()),
                      Container(width: 2, color: Colors.grey[200]),
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
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 40, height: 40,
                          child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB300))),
                        ),
                        const SizedBox(height: 16),
                        Text('กำลังวิเคราะห์ +300,000 รายชื่อ...', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFF57F17))),
                        const SizedBox(height: 4),
                        Text('เพื่อค้นหาชื่อที่ดีที่สุดสำหรับคุณ', style: GoogleFonts.kanit(fontSize: 13, color: Colors.grey[600])),
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
            Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Container(width: 80, height: 20, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
          ],
        ),
        const SizedBox(height: 8),
        Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Container(width: 1.5, height: 20, color: Colors.grey[200]),
            const SizedBox(width: 12),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
          ],
        ),
      ],
    );
  }
}
