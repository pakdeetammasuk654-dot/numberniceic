
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';

class AutoScrollingAvatarList extends StatefulWidget {
  final List<SampleName> samples;
  final String currentName;
  final Function(String) onSelect;
  final bool? isScrolling; // Optional external control
  final VoidCallback? onStopScrolling; // Optional callback

  const AutoScrollingAvatarList({
    super.key, 
    required this.samples, 
    required this.currentName,
    required this.onSelect,
    this.isScrolling,
    this.onStopScrolling,
  });

  @override
  State<AutoScrollingAvatarList> createState() => _AutoScrollingAvatarListState();
}

class _AutoScrollingAvatarListState extends State<AutoScrollingAvatarList> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late Ticker _ticker;
  bool _isUserInteracting = false;
  // Speed: pixels per tick (at 60fps). 0.5 is slow and smooth.
  final double _scrollSpeed = 0.5; 
  bool _shouldAutoScroll = true;
  String? _lastTappedName;
  
  bool get _isScrollingEnabled => widget.isScrolling ?? _shouldAutoScroll;
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    
    // Calculate initial offset if there's a selected name to show immediately
    double initialOffset = 0;
    if (widget.currentName.isNotEmpty) {
      final cleanCurrent = widget.currentName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      final index = widget.samples.indexWhere((s) => s.name.replaceAll(RegExp(r'\s+'), '').toLowerCase() == cleanCurrent);
      if (index != -1) {
         // Estate width: Avatar(50) + Padding(16) + some text slack ~= 80
         // We center it roughly
         // screen width is unknown, but we just want it 'visible' so builder runs.
         initialOffset = index * 100.0; 
      }
    }

    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    
    // Always start scrolling initially, regardless of default name
    _shouldAutoScroll = true;

    _ticker = createTicker((elapsed) {
      if (_isScrollingEnabled && !_isUserInteracting && _scrollController.hasClients) {
          if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 100) {
             _scrollController.jumpTo(0);
          } else {
             _scrollController.jumpTo(_scrollController.offset + _scrollSpeed);
          }
      }
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(AutoScrollingAvatarList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset centering flag if name changes externally
    if (oldWidget.currentName != widget.currentName) {
       _hasInitialCentered = false;
    }

    // 1. Check external control changes
    if (widget.isScrolling != null) {
      final bool oldScrolling = oldWidget.isScrolling ?? true;
      final bool newScrolling = widget.isScrolling!;

      if (!oldScrolling && newScrolling) {
        if (!_ticker.isTicking && !_isUserInteracting) _ticker.start();
      } else if (oldScrolling && !newScrolling) {
        // Stop handled by property check in ticker
      }
      return;
    }

    // 2. Internal logic (Legacy/Fallback)
    if (oldWidget.currentName != widget.currentName) {
       final currentClean = widget.currentName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
       final lastTappedClean = _lastTappedName?.replaceAll(RegExp(r'\s+'), '').toLowerCase();

       if (currentClean == lastTappedClean) {
         _shouldAutoScroll = false;
         if (_ticker.isTicking) _ticker.stop();
       } else {
         _shouldAutoScroll = true;
         _lastTappedName = null; 
         if (!_ticker.isTicking && !_isUserInteracting) _ticker.start();
       }
    }
  }
  
  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
         _isUserInteracting = true;
      },
      onPointerUp: (_) {
         Future.delayed(const Duration(milliseconds: 200), () { 
            if (mounted) _isUserInteracting = false;
         });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Precise Initial Centering Logic
          if (!_hasInitialCentered && widget.currentName.isNotEmpty) {
             final cleanCurrent = widget.currentName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
             final index = widget.samples.indexWhere((s) => s.name.replaceAll(RegExp(r'\s+'), '').toLowerCase() == cleanCurrent);
             
             // Check if we should center (either explicitly stopped, or just loading a specific name)
             // If scrolling is ON, we usually don't force center, but user wants "Resume on type".
             // If I switch tabs, I want to see the name centered if it was selected.
             // If isScrollingEnabled is FALSE, we MUST center.
             if (index != -1 && !_isScrollingEnabled) {
                 _hasInitialCentered = true;
                 final double itemWidth = 100.0;
                 final double viewportWidth = constraints.maxWidth;
                 final double targetCenter = (index * itemWidth) + (itemWidth / 2);
                 final double screenCenter = viewportWidth / 2;
                 final double targetOffset = targetCenter - screenCenter;

                 SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                       _scrollController.jumpTo(targetOffset);
                    }
                 });
             }
          }

          return ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemExtent: 100, // Fixed width for precise calculation
            physics: const BouncingScrollPhysics(),
            itemCount: widget.samples.length * 1000, 
            itemBuilder: (context, index) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final realIndex = index % widget.samples.length;
              final sample = widget.samples[realIndex];
              final currentClean = widget.currentName.replaceAll(RegExp(r'[\s\u200B]+'), '').toLowerCase();
              final sampleClean = sample.name.replaceAll(RegExp(r'[\s\u200B]+'), '').toLowerCase();
              final isActive = currentClean == sampleClean;

              return GestureDetector(
                onTap: () {
                   // 1. Local Stop
                   _shouldAutoScroll = false;
                   if (_ticker.isTicking) _ticker.stop();
                   
                   _lastTappedName = sample.name;
                   widget.onSelect(sample.name);
                   
                   // 2. Math-based Centering (Robust & Simple)
                   final double itemWidth = 100.0;
                   final double viewportWidth = constraints.maxWidth;
                   
                   // Calculate best target index closest to current position
                   final double currentScroll = _scrollController.offset;
                   final int currentCycle = (currentScroll / (widget.samples.length * itemWidth)).floor();
                   
                   // Target index in "absolute" terms roughly
                   // We want the specific 'realIndex' in the current or next cycle
                   // actually, we know 'index' from the builder!
                   // But 'index' might be far if the user scrolled?
                   // 'index' passed to builder IS the absolute index of this item.
                   // So we just center THIS item 'index'.
                   
                   final double targetCenter = (index * itemWidth) + (itemWidth / 2);
                   final double screenCenter = viewportWidth / 2;
                   final double targetOffset = targetCenter - screenCenter;

                   _scrollController.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutQuad,
                   );

                   // 3. Global Stop
                   if (widget.onStopScrolling != null) {
                     widget.onStopScrolling!();
                   }
                },
                behavior: HitTestBehavior.opaque, // Ensure clicks hit even empty space
                child: Center(
                   // Center content within the 100px extent
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Container(
                         width: 50,
                         height: 50,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           border: Border.all(
                            color: isActive 
                              ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706)) 
                              : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)), // Slate 300
                            width: 2,
                          ),
                          boxShadow: [
                             BoxShadow(
                               color: Colors.black.withOpacity(0.1),
                               blurRadius: 4,
                               offset: const Offset(0, 2),
                             )
                          ]
                        ),
                        child: ClipOval(
                          child: Image.network(
                            sample.avatarUrl.startsWith('http')
                                  ? sample.avatarUrl
                                  : '${ApiService.baseUrl}${sample.avatarUrl}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF16213E),
                                child: const Icon(Icons.person, color: Colors.white38),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sample.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.kanit(
                          fontSize: 12, // Slightly larger
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive 
                            ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706)) // Gold / Amber 600
                            : (isDark ? Colors.white70 : const Color(0xFF475569)), // Slate 600
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      ),
    );
  }
} // End State
