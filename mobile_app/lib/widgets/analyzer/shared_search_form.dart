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
    return Container(
      color: const Color(0xFF1A1A2E), // Dark navy background
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          // Day Dropdown (Compact with label)
          Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E3B55), Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF64B5F6).withOpacity(0.3), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.viewModel.selectedDay,
                dropdownColor: const Color(0xFF16213E),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF90CAF9), size: 18),
                selectedItemBuilder: (context) {
                  return widget.viewModel.days.map((day) {
                    final shortLabel = day.label.replaceAll('วัน', '');
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(day.icon, color: day.color, size: 18),
                        const SizedBox(width: 6),
                        Text(shortLabel, style: GoogleFonts.kanit(fontSize: 11, color: Colors.white), overflow: TextOverflow.visible, softWrap: false),
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
                        Text(menuLabel, style: GoogleFonts.kanit(fontSize: 14, color: Colors.white)),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E3B55), Color(0xFF16213E)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF64B5F6).withOpacity(0.3), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF64B5F6)),
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
                            if (widget.viewModel.showTutorial) {
                              widget.viewModel.setShowTutorial(false);
                            }
                            if (!widget.viewModel.isAvatarScrolling && val.isNotEmpty) {
                               widget.viewModel.setAvatarScrolling(true);
                            }
                          },
                          onTap: () {
                            if (widget.viewModel.showTutorial) {
                              widget.viewModel.setShowTutorial(false);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'กรอกชื่อ เช่น ณเดชน์',
                            hintStyle: GoogleFonts.kanit(color: Colors.white38, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                          cursorColor: const Color(0xFFFFD700),
                        ),
                      ),
                      if (widget.nameController.text.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.white38, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                 widget.nameController.clear();
                                 widget.viewModel.setName('');
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
                
                // Tutorial Overlay
                if (widget.viewModel.showTutorial && widget.nameController.text.isEmpty)
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: _buildTutorialCallout(),
                  ),
              ],
            ),
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
                'เริ่มกรอกชื่อที่นี่เพื่อวิเคราะห์',
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
