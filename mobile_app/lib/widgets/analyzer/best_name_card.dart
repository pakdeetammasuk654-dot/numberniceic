import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/name_analysis.dart';
import '../../utils/color_utils.dart';
import '../shimmering_gold_wrapper.dart';

class BestNameCard extends StatelessWidget {
  final NameAnalysis nameAnalysis;
  final int rank;
  final bool isGold;
  final bool showKlakini;
  final VoidCallback onTap;
  final bool isCompact;

  const BestNameCard({
    Key? key,
    required this.nameAnalysis,
    required this.rank,
    this.isGold = true,
    required this.showKlakini,
    required this.onTap,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard();
    }
    return _buildFullCard();
  }

  Widget _buildCompactCard() {
    final displayName = nameAnalysis.displayNameHtml;
    final similarity = nameAnalysis.similarity * 100;
    final totalScore = nameAnalysis.totalScore;

    // Background Logic (similar to Dashboard)
    final bool isTop = nameAnalysis.isTopTier;
    final Color bgColor = isTop 
        ? const Color(0xFF2C250E) // Dark Gold Tint
        : Colors.transparent;
        
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(bottom: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: [
            // Rank Badge
            if (rank <= 3) 
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                     Icon(Icons.workspace_premium, color: const Color(0xFFFFD700), size: 14),
                     Text(
                      '#$rank',
                      style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFFFD700)),
                    ),
                  ],
                ),
              )
            else
               Container(
                 margin: const EdgeInsets.only(right: 12),
                 width: 36, 
                 alignment: Alignment.center,
                 child: Text(
                    '#$rank',
                    style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38),
                 )
               ),

            // Name
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Flexible(child: _buildNameText(displayName)),
                  if (nameAnalysis.isTopTier) const SizedBox(width: 4),
                  if (nameAnalysis.isTopTier) const Text(' ⭐', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
            
            // Score Circles (Math & Shadow)
            Expanded(
              flex: 4,
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    // Math
                    if (nameAnalysis.tSat.isNotEmpty)
                      _buildScoreCircle(
                        nameAnalysis.satNum.isNotEmpty ? nameAnalysis.satNum[0].toString() : '',
                        _resolveColor(nameAnalysis.tSat[0]),
                        size: 24,
                      ),
                    const SizedBox(width: 8),
                    // Shadow
                    if (nameAnalysis.tSha.isNotEmpty)
                      _buildScoreCircle(
                        nameAnalysis.shaNum.isNotEmpty ? nameAnalysis.shaNum[0].toString() : '',
                        _resolveColor(nameAnalysis.tSha[0]),
                        size: 24,
                        isShadow: true,
                      ),
                 ],
              ),
            ),

            // Score Logic (Text Only - No Box)
            Container(
              width: 50,
              alignment: Alignment.centerRight,
              child: Text(
                    '${totalScore >= 0 ? '+' : ''}$totalScore',
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: totalScore >= 0 ? Colors.greenAccent : Colors.redAccent,
                    ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Arrow
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(
                Icons.keyboard_double_arrow_right_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard() {
    final displayName = nameAnalysis.displayNameHtml;
    final similarity = nameAnalysis.similarity * 100;
    final totalScore = nameAnalysis.totalScore;

    // Theme Colors
    final Color badgeBg = isGold ? const Color(0xFFFFD700) : const Color(0xFF66BB6A);
    final Color badgeText = isGold ? const Color(0xFF4A3B00) : Colors.white;
    final String badgeLabel = isGold ? 'Top $rank' : '#$rank';

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 160,
          maxHeight: 180,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top-Right Badge
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.zero,
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isGold) ...[
                      Icon(Icons.workspace_premium, color: badgeText, size: 10),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      badgeLabel,
                      style: GoogleFonts.kanit(
                        fontSize: 11,
                        fontWeight: isGold ? FontWeight.w900 : FontWeight.w400,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Star + Name
                   Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (nameAnalysis.isTopTier) _buildPremiumStar(18),
                        if (nameAnalysis.isTopTier) const SizedBox(width: 6),
                        Expanded(child: _buildNameText(displayName)),
                      ],
                   ),
                   const SizedBox(height: 6),
                   // Similarity & Score
                   RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.kanit(fontSize: 11, color: const Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                        children: [
                          const TextSpan(text: 'คล้าย '),
                          TextSpan(text: '${similarity.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                          const TextSpan(text: ' • ', style: TextStyle(color: Color(0xFFCBD5E0))),
                          const TextSpan(text: 'คะแนน '),
                          TextSpan(text: '$totalScore', style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                   ),
                   const SizedBox(height: 10),
                   // Score Circles
                   _buildScoreCircles(),
                   const SizedBox(height: 12),
                   // Chevron
                   _buildChevron(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumStar(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.star, color: const Color(0xFFFFD700).withOpacity(0.4), size: size + 4),
        Icon(Icons.star, color: const Color(0xFFB8860B), size: size + 1.5),
        Icon(Icons.star, color: const Color(0xFFFFD700), size: size),
      ],
    );
  }

  Widget _buildNameText(List<dynamic> displayName) {
     // Check if valid to shimmer/gold
     bool anyBad = displayName.any((dc) => dc.isBad);
     bool enableShimmer = !anyBad || !showKlakini;

     return FittedBox(
       fit: BoxFit.scaleDown,
       child: ShimmeringGoldWrapper(
         enabled: enableShimmer,
         child: RichText(
            maxLines: 1,
            text: TextSpan(
              children: displayName.map((dc) {
                return TextSpan(
                  text: dc.char,
                  style: GoogleFonts.kanit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    // If shimmer is enabled, this color doesn't matter much as shader overrides,
                    // but for fallback or if disabled (due to bad char):
                    color: dc.isBad ? const Color(0xFFFF4757) : const Color(0xFFC59D00),
                    shadows: nameAnalysis.isTopTier ? [
                       Shadow(
                         color: const Color(0xFFC59D00).withOpacity(0.2),
                         offset: const Offset(0, 1),
                         blurRadius: 1,
                       )
                    ] : null,
                  ),
                );
              }).toList(),
            ),
         ),
       ),
     );
  }

  Widget _buildScoreCircles() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
         ...nameAnalysis.tSat.asMap().entries.map((entry) {
            final idx = entry.key;
            final color = _resolveColor(entry.value);
            final numStr = nameAnalysis.satNum.length > idx ? nameAnalysis.satNum[idx].toString() : '';
            return _buildScoreCircle(numStr, color);
         }).toList(),
         if (nameAnalysis.tSat.isNotEmpty && nameAnalysis.tSha.isNotEmpty)
            const SizedBox(width: 2),
         ...nameAnalysis.tSha.asMap().entries.map((entry) {
            final idx = entry.key;
            final color = _resolveColor(entry.value);
            final numStr = nameAnalysis.shaNum.length > idx ? nameAnalysis.shaNum[idx].toString() : '';
            return _buildScoreCircle(numStr, color, isShadow: true);
         }).toList(),
      ],
    );
  }

  Widget _buildScoreCircle(String score, Color color, {bool isShadow = false, double size = 26}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: isShadow ? Border.all(color: Colors.white.withOpacity(0.5), width: 1) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        score,
        style: GoogleFonts.kanit(
          color: Colors.white, 
          fontWeight: FontWeight.w900, 
          fontSize: size < 24 ? 9 : 11,
          shadows: [
            const Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChevron() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isGold ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isGold ? const Color(0xFFFFD700).withOpacity(0.5) : const Color(0xFF66BB6A).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.keyboard_double_arrow_right_rounded,
          size: 16,
          color: isGold ? const Color(0xFFF9A825) : const Color(0xFF43A047),
        ),
      );
  }


  Color _resolveColor(Map<String, dynamic> item) {
      final colorCode = item['color'] as String?;
      final parsed = ColorUtils.tryParseColor(colorCode);
      if (parsed != null) return parsed;
      
      // Fallback
      final cStr = (colorCode ?? '').toUpperCase();
      final type = (item['type'] as String? ?? '').toUpperCase();
      final isBad = cStr.contains('EF4444') || cStr.contains('D32F2F') || cStr.contains('RED') || type.startsWith('R') || type.contains('BAD');
      
      return isBad ? const Color(0xFFEF4444) : const Color(0xFF1B5E20);
  }
}
