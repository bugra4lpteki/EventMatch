import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../models/event_model.dart';
import '../screens/event_detail_screen.dart';

/// Performance-optimized carousel with isolated indicator rebuilds and RepaintBoundary.
class PopularEventsCarousel extends StatefulWidget {
  final List<EventModel> events;
  final double height;
  final bool showIndicators;

  const PopularEventsCarousel({
    super.key,
    required this.events,
    this.height = 420,
    this.showIndicators = true,
  });

  @override
  State<PopularEventsCarousel> createState() => _PopularEventsCarouselState();
}

class _PopularEventsCarouselState extends State<PopularEventsCarousel> {
  late final PageController _pageController;
  // Use ValueNotifier so only the indicator dots rebuild on scroll/change, eliminating carousel rebuild jank
  late final ValueNotifier<int> _currentPageNotifier;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
    _currentPageNotifier = ValueNotifier<int>(0);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || widget.events.isEmpty) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPageNotifier.value + 1) % widget.events.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              // Only notify the indicator listener instead of calling full setState
              _currentPageNotifier.value = index;
            },
            itemCount: widget.events.length,
            itemBuilder: (context, index) {
              final event = widget.events[index];
              // Isolate each card's paint layer to prevent re-rasterization during swipe
              return RepaintBoundary(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailScreen(event: event),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AppImageWidget(
                              imageUrl: event.imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 720,
                              memCacheHeight: 480,
                            ),
                          ),
                          // Dark Gradient Overlay for optimal contrast and zero GPU blending overhead
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.2),
                                    Colors.black.withValues(alpha: 0.95),
                                  ],
                                  stops: const [0.3, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Bottom Content Panel
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white24, width: 0.8),
                                      ),
                                      child: Text(
                                        event.category.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  event.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: widget.height < 300 ? 16 : 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.showIndicators) ...[
          const SizedBox(height: 12),
          // Isolated Pagination Dots Indicator using ValueListenableBuilder
          ValueListenableBuilder<int>(
            valueListenable: _currentPageNotifier,
            builder: (context, currentPage, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.events.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentPage == index ? 24 : 8,
                    height: 6,
                    decoration: BoxDecoration(
                      color: currentPage == index
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
