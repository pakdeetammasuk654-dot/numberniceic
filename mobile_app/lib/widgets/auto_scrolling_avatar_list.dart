
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

  const AutoScrollingAvatarList({
    super.key, 
    required this.samples, 
    required this.currentName,
    required this.onSelect,
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

  @override
  void initState() {
    super.initState();
    // Start at a large offset so user can scroll left immediately if they want
    _scrollController = ScrollController(initialScrollOffset: 0);
    
    _ticker = createTicker((elapsed) {
      if (!_isUserInteracting && _scrollController.hasClients) {
          // Check for max extent
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
         // Add a small delay so momentum scrolling can finish or user can flick
         Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
               _isUserInteracting = false;
            }
         });
      },
      onPointerCancel: (_) {
         _isUserInteracting = false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        // Effectively infinite loop
        itemCount: widget.samples.length * 1000, 
        itemBuilder: (context, index) {
          final realIndex = index % widget.samples.length;
          final sample = widget.samples[realIndex];
          final isActive = widget.currentName.trim() == sample.name.trim();

          return GestureDetector(
            onTap: () => widget.onSelect(sample.name),
            child: Padding(
               padding: const EdgeInsets.only(right: 16),
               child: Column(
                 children: [
                   Container(
                     width: 50,
                     height: 50,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       border: Border.all(
                        color: isActive ? Colors.orange : Colors.grey[200]!,
                        width: 2,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(
                          sample.avatarUrl.startsWith('http')
                              ? sample.avatarUrl
                              : '${ApiService.baseUrl}${sample.avatarUrl}',
                        ),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.1),
                           blurRadius: 4,
                           offset: const Offset(0, 2),
                         )
                      ]
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sample.name,
                    style: GoogleFonts.kanit(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Colors.orange : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
