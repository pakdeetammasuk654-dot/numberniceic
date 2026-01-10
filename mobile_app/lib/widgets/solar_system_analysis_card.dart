import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SolarSystemAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onSaveName;
  final VoidCallback? onPerfectName;
  final String cleanedName;

  const SolarSystemAnalysisCard({
    Key? key,
    required this.data,
    required this.cleanedName,
    this.onSaveName,
    this.onPerfectName,
    this.showKlakini = true,
  }) : super(key: key);

  final bool showKlakini;

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF1E293B);
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return const Color(0xFF1E293B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sunDisplayName = data['sun_display_name_html'] as List?;
    final resultTitle = data['result_title'] as String? ?? '';
    final resultColorHex = data['result_color'] as String? ?? '#1E293B';
    final grandTotalScore = data['grand_total_score'] as int? ?? 0;
    // Safely cast analysis_summaries
    // Safely cast analysis_summaries
    final List<dynamic> rawSummaries = data['analysis_summaries'] ?? [];
    final summaries = rawSummaries.map((e) => Map<String, dynamic>.from(e)).toList();

    // Determine if name is good or bad for card styling
    final bool isGoodName = grandTotalScore >= 0;

    // Check for mixed good/bad (Good Name but has Bad summaries)
    bool hasBadInSummaries = false;
    for (var s in summaries) {
        // Check both flag and Title (backend removed text, but safe to keep) AND Content
        if (s['is_bad'] == true || (s['title'] as String? ?? '').contains('ส่งผลร้าย')) {
            hasBadInSummaries = true;
            break;
        }
        // Deep check content values
        final content = s['content'] as List? ?? [];
        for (var c in content) {
           if (c is Map && c['is_bad'] == true) {
              hasBadInSummaries = true;
              break; 
           }
        }
        if (hasBadInSummaries) break;
    }
    
    String displayResultTitle = ' " $resultTitle';
    if (isGoodName && hasBadInSummaries) {
        displayResultTitle = ' " $resultTitle (แต่)';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoodName 
            ? [
                const Color(0xFFFFFBEF), // Cream
                const Color(0xFFFFF8E1), // Pale Amber
                const Color(0xFFFFECB3), // Light Amber
                const Color(0xFFFFF8E1), // Pale Amber (back)
              ]
            : [
                const Color(0xFFF5F5F5), 
                const Color(0xFFE5E5E5),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: isGoodName ? [0.0, 0.3, 0.6, 1.0] : null,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isGoodName ? const Color(0xFFFFC107) : const Color(0xFFBDBDBD), 
          width: 1.0
        ),
        boxShadow: isGoodName 
          ? [
              // Soft outer glow - Gold
              BoxShadow(
                color: const Color(0xFFFFC107).withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 0),
              ),
              // Medium glow
              BoxShadow(
                color: const Color(0xFFFFCA28).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, 4),
              ),
              // Subtle depth shadow
              BoxShadow(
                color: const Color(0xFFFFB300).withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // 1. Title Header
          if (resultTitle.isNotEmpty)
             Padding(
               padding: EdgeInsets.zero,
               child: _ShimmeringGoldWrapper(
                 // Strict Logic: No Bad Pairs (Negative Score = 0) AND No Bad Letters (Safe check)
                 enabled: ((data['num_negative_score'] as num? ?? 0) == 0 && (data['sha_negative_score'] as num? ?? 0) == 0) && 
                          (!(sunDisplayName?.any((dc) {
                             final val = dc['is_bad'];
                             if (val is bool) return val;
                             if (val is String) return val.toLowerCase() == 'true';
                             return false;
                          }) ?? false)),
                 child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: '" ',
                        style: TextStyle(color: Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      if (sunDisplayName != null)
                        ...(sunDisplayName).map((dc) => TextSpan(
                           text: dc['char'],
                           style: GoogleFonts.kanit(
                             fontSize: 22,
                             fontWeight: FontWeight.w600,
                             color: (showKlakini && dc['is_bad'] == true) ? const Color(0xFFEF4444) : const Color(0xFF1E293B), // Use Black if hidden (will be gold by wrapper)
                             height: 1.3,
                           ),
                        )),
                      if (sunDisplayName == null)
                         TextSpan(
                           text: cleanedName,
                           style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                         ),
                      TextSpan(
                        text: displayResultTitle, // Updated Logic
                        style: GoogleFonts.kanit(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B), // Always black for result title
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
               ),
             ),
             ),
             const SizedBox(height: 8), // Reduced from 12
             Divider(
               height: 1,
               thickness: 1,
               color: const Color(0xFFFFD700).withOpacity(0.6), // Changed to Gold
             ),
             const SizedBox(height: 16), // Reduced from 24
          
          // 2. Summary List
            if (summaries.isNotEmpty)
              Column(
                children: summaries.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  final summary = entry.value;
                  // Only consider it the "last" item for divider logic if it matches the Simple List style (Case B)
                  // But actually, we just want to remove the divider from the visual last item.
                  final isLast = index == summaries.length - 1;

                  final bgColor = summary['background_color'] as String?;
                  final rawTitle = summary['title'] as String? ?? '';
                  final rawContent = summary['content'] as List? ?? [];
                  final content = rawContent.map((e) => Map<String, dynamic>.from(e)).toList();                  

                  // Robust IsBad Calculation
                  bool isBadItem = summary['is_bad'] == true;
                  if (!isBadItem) {
                      for (var c in content) {
                          if (c['is_bad'] == true) {
                              isBadItem = true;
                              break;
                          }
                      }
                  }

                  // Case A: Premium Box (has background color)
                  if (bgColor != null && bgColor.isNotEmpty) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, _parseColor(bgColor).withOpacity(0.3)], 
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.03),
                             blurRadius: 8,
                             offset: const Offset(0, 2),
                           )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rawTitle,
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.sarabun(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF475569),
                                height: 1.5,
                              ),
                              children: _buildContentSpans(content),
                            ),
                          ),
                        ],
                      ),
                    );
                  } 
                  // Case B: Simple List - Like "Bad Name" categories
                  else {
                    Color catColor = _getCategoryColor(rawTitle);
                    String displayTitle = rawTitle.replaceAll(': จะส่งผลร้าย', ''); 
                    
                    if (isBadItem) {
                       catColor = const Color(0xFFEF4444); // Red for bad
                    }

                    return Container(
                      width: double.infinity,
                      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
                      padding: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
                      // decoration: removed border here
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           children: [
                             // Icon Box Matching Web Style (48px)
                             Container(
                               width: 48, height: 48,
                               decoration: BoxDecoration(
                                 color: catColor.withOpacity(0.15), // Softer background like Web
                                 borderRadius: BorderRadius.circular(12), // Web uses 12px radius
                               ),
                               padding: const EdgeInsets.all(0),
                               alignment: Alignment.center,
                                 child: Icon(
                                   isBadItem ? Icons.lightbulb_outline : Icons.lightbulb, // Outlined = Off, Filled = On
                                   color: catColor,
                                   size: 24,
                                 ),
                             ),
                             const SizedBox(width: 12),
                             RichText(
                               text: TextSpan(
                                 children: [
                                   TextSpan(
                                     text: displayTitle,
                                     style: GoogleFonts.kanit(
                                       fontSize: 18,
                                       fontWeight: FontWeight.w600,
                                       color: const Color(0xFF1E293B),
                                     ),
                                   ),
                                   if (isBadItem)
                                     TextSpan(
                                       text: ' (ร้าย)',
                                       style: GoogleFonts.kanit(
                                         fontSize: 18,
                                         fontWeight: FontWeight.w600,
                                         color: const Color(0xFFEF4444),
                                       ),
                                     ),
                                 ],
                               ),
                             ),
                           ],
                         ),
                         Padding(
                           padding: const EdgeInsets.only(left: 44, top: 4),
                           child: RichText(
                               text: TextSpan(
                                 style: GoogleFonts.sarabun(
                                   fontSize: 15,
                                   fontWeight: FontWeight.w400,
                                   color: const Color(0xFF4B5563),
                                   height: 1.5,
                                 ),
                                 children: _buildContentSpans(content),
                               ),
                           ),
                         ),
                      ],
                    ),
                  );
                }
              }).toList(),
            ),
        ],
      ),
    );
  }

  // TextSpan Builder for Keyword Content with commas
  List<InlineSpan> _buildContentSpans(List<Map<String, dynamic>> content) {
     List<InlineSpan> spans = [];
     for (int i = 0; i < content.length; i++) {
        final kw = content[i];
        final text = kw['text'] as String? ?? '';
        // Keywords are always black, regardless of is_bad status
        
        spans.add(TextSpan(
          text: text,
          style: const TextStyle(
             color: Color(0xFF1E293B), // Always black for keywords
          ),
        ));

        if (i < content.length - 1) {
           spans.add(const TextSpan(text: ', ')); // Grey by default from parent
        }
     }
     return spans;
  }
  
  // Helper for Category Colors (matching web logic)
  Color _getCategoryColor(String title) {
    if (title.contains("การงาน")) return const Color(0xFF42A5F5); // Blue
    if (title.contains("การเงิน")) return const Color(0xFFFFA726); // Orange
    if (title.contains("ความรัก")) return const Color(0xFFEC407A); // Pink
    if (title.contains("สุขภาพ")) return const Color(0xFF26A69A); // Teal
    if (title.contains("โชคลาภ")) return const Color(0xFF8B5CF6); // Purple
    if (title.contains("กาลกิณี") || title.contains("ร้าย")) return const Color(0xFFEF4444); // Red
    return const Color(0xFF64748B); // Slate
  }
}

class _ShimmeringGoldWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _ShimmeringGoldWrapper({super.key, required this.child, this.enabled = true});

  @override
  State<_ShimmeringGoldWrapper> createState() => _ShimmeringGoldWrapperState();
}

class _ShimmeringGoldWrapperState extends State<_ShimmeringGoldWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFF8B6914), // Darker Gold for contrast
                Color(0xFFFFD700), // Gold
                Color(0xFFFFF8DC), // Cornsilk (White-ish Gold)
                Color(0xFFFFD700), // Gold
                Color(0xFF8B6914),
              ],
              stops: const [0.0, 0.4, 0.5, 0.6, 1.0], // Tighter shine band
              begin: Alignment(-1.0 + (3.0 * _controller.value), -0.5), // Faster movement
              end: Alignment(1.0 + (3.0 * _controller.value), 0.5),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
