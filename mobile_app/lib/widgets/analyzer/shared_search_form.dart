import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/analyzer_view_model.dart'; // Adjust path if needed

import '../../screens/number_analysis_page.dart';

class SharedSearchForm extends StatefulWidget {
  final AnalyzerViewModel viewModel;
  final TextEditingController nameController;

  const SharedSearchForm({
    super.key,
    required this.viewModel,
    required this.nameController,
  });

  @override
  State<SharedSearchForm> createState() => _SharedSearchFormState();
}

class _SharedSearchFormState extends State<SharedSearchForm> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
    
    // Force check: If empty text, ensure tutorial is ON
    if (widget.nameController.text.isEmpty) {
      // Use Future.microtask to avoid build conflicts
      Future.microtask(() => widget.viewModel.setShowTutorial(true));
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  void _handleSubmitted(BuildContext context, String value) {
     // Phone number search disabled
  }

  @override
  Widget build(BuildContext context) {
    print("🔎 DEBUG: SharedSearchForm Build - showTutorial=${widget.viewModel.showTutorial}, text='${widget.nameController.text}'");
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme Colors
    final bgColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final inputGradientColors = isDark 
        ? [const Color(0xFF2E3B55), const Color(0xFF16213E)]
        : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)];
    final borderColor = isDark ? const Color(0xFF64B5F6).withOpacity(0.3) : const Color(0xFFE2E8F0);
    final shadowColor = isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF64748B).withOpacity(0.1);
    final textColor = isDark ? Colors.white : const Color(0xFF334155);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final iconColor = isDark ? const Color(0xFF90CAF9) : const Color(0xFF64748B);
    final searchIconColor = isDark ? const Color(0xFF64B5F6) : const Color(0xFF3B82F6);
    final dropdownIconColor = isDark ? const Color(0xFF90CAF9) : const Color(0xFF64748B);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Day Dropdown (Compact with label)
              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: inputGradientColors,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.viewModel.selectedDay,
                    dropdownColor: isDark ? const Color(0xFF16213E) : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: dropdownIconColor, size: 18),
                    borderRadius: BorderRadius.circular(12),
                    selectedItemBuilder: (context) {
                       return widget.viewModel.days.map((day) {
                        final shortLabel = day.label.replaceAll('วัน', '');
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(day.icon, color: day.color, size: 18),
                            const SizedBox(width: 6),
                            Text(shortLabel, style: GoogleFonts.kanit(fontSize: 11, color: textColor), overflow: TextOverflow.visible, softWrap: false),
                          ],
                        );
                      }).toList();
                    },
                    items: widget.viewModel.days.map((day) {
                      // Shorten labels for dropdown menu
                      String menuLabel = day.label.replaceAll('วัน', '');
                      if (day.value == 'wednesday1') menuLabel = 'พุธ (วัน)';
                      if (day.value == 'wednesday2') menuLabel = 'พุธ (คืน)';
                      return DropdownMenuItem(
                        value: day.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(day.icon, color: day.color, size: 18),
                            const SizedBox(width: 6),
                            Text(menuLabel, style: GoogleFonts.kanit(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF334155))),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                       if (val != null) widget.viewModel.setDay(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Name Input (Expanded)
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: inputGradientColors,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.0),
                        boxShadow: [
                           BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: searchIconColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: widget.nameController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (val) { 
                                FocusScope.of(context).unfocus();
                                _handleSubmitted(context, val);
                              },
                              onChanged: (val) {
                                widget.viewModel.setName(val);
                                if (val.isNotEmpty) {
                                  if (widget.viewModel.showTutorial) {
                                    widget.viewModel.setShowTutorial(false);
                                  }
                                  if (!widget.viewModel.isAvatarScrolling) {
                                     widget.viewModel.setAvatarScrolling(true);
                                  }
                                } else {
                                  // Show tutorial again if cleared
                                  widget.viewModel.setShowTutorial(true);
                                }
                              },
                              onTap: () {
                                // Don't hide tutorial on tap, only on type
                              },
                              decoration: InputDecoration(
                                hintText: 'กรอกชื่อ เช่น ณเดชน์',
                                hintStyle: GoogleFonts.kanit(color: hintColor, fontSize: 14),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                              cursorColor: const Color(0xFFFFD700),
                            ),
                          ),
                          if (widget.nameController.text.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.cancel, color: hintColor, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                     widget.nameController.clear();
                                     widget.viewModel.setName('');
                                     widget.viewModel.setShowTutorial(true);
                                  }
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => FocusScope.of(context).unfocus(),
                                ),
                              ],
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Tutorial below the input row
          // FORCE CHECK: Show whenever text is empty (ignoring flag for debug)
          if (widget.nameController.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildTutorialCallout(),
            ),
        ],
      ),
    );
  }

  Widget _buildTutorialCallout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               const Icon(Icons.touch_app, color: Colors.black87, size: 20),
               const SizedBox(width: 8),
               Text(
                'เลือกวันเกิด + กรอกชื่อ เพื่อทำการวิเคราะห์',
                style: GoogleFonts.kanit(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Down Arrow
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 10.0),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, value),
              child: Transform.rotate(
                angle: 3.14159, // 180 degrees
                child: CustomPaint(
                  size: const Size(20, 10),
                  painter: _TrianglePainter(color: const Color(0xFFFFD700)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
