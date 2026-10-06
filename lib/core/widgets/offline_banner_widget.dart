import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';

class OfflineBannerWidget extends StatelessWidget {
  const OfflineBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    ConnectivityService connectivity;
    try {
      connectivity = context.watch<ConnectivityService>();
    } catch (_) {
      connectivity = ConnectivityService();
    }

    final isOffline = connectivity.isOffline;
    final showRestored = connectivity.showRestoredBanner;
    final isVisible = isOffline || showRestored;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              offset: isVisible ? Offset.zero : const Offset(0, -1.5),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isVisible ? 1.0 : 0.0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOffline
                          ? const Color(0xFF1E1E2E).withValues(alpha: 0.95)
                          : const Color(0xFF064E3B).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOffline
                            ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                            : const Color(0xFF10B981).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isOffline ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                          color: isOffline ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isOffline
                                ? 'İnternet bağlantısı kesildi. Çevrimdışı mod.'
                                : 'İnternet bağlantısı yeniden kuruldu!',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
  }
}
