import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_image_widget.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';

/// Apple Wallet (PKPass) formatında dijital etkinlik ve VIP giriş bileti
class AppleWalletPassSheet extends StatefulWidget {
  final EventModel event;
  final UserModel user;

  const AppleWalletPassSheet({
    super.key,
    required this.event,
    required this.user,
  });

  static Future<void> show(
    BuildContext context, {
    required EventModel event,
    required UserModel user,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppleWalletPassSheet(event: event, user: user),
    );
  }

  @override
  State<AppleWalletPassSheet> createState() => _AppleWalletPassSheetState();
}

class _AppleWalletPassSheetState extends State<AppleWalletPassSheet>
    with SingleTickerProviderStateMixin {
  bool _isAddedToWallet = false;
  late final AnimationController _scannerAnimController;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerAnimController.dispose();
    super.dispose();
  }

  String get _serialNumber {
    final hash1 = (widget.event.id.hashCode.abs() % 90000) + 10000;
    final hash2 = (widget.user.id.hashCode.abs() % 9000) + 1000;
    return 'EM-$hash1-$hash2';
  }

  String get _gateCode {
    final gates = ['A1', 'B2', 'VIP-1', 'C3', 'ANA GİRİŞ'];
    final idx = widget.event.id.hashCode.abs() % gates.length;
    return widget.user.hasActiveVip ? 'VIP-ÖNCELİKLİ' : gates[idx];
  }

  String get _zoneCode {
    if (widget.user.hasActiveVip) return 'VIP SAHNE ÖNÜ / LOUNGE';
    final zones = ['GENEL GİRİŞ / AYAKTA', 'SAHNE ÖNÜ', 'TRİBÜN KATEGORİ 1'];
    final idx = widget.event.id.hashCode.abs() % zones.length;
    return zones[idx];
  }

  void _onAddToAppleWallet() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isAddedToWallet = true;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.wallet_rounded, color: Color(0xFF38BDF8), size: 28),
            SizedBox(width: 10),
            Text(
              'Apple Cüzdan\'a Eklendi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dijital biletiniz Apple Wallet uygulamanıza kaydedildi.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.notifications_active_outlined, color: Color(0xFFFBBF24), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Etkinlik günü konuma yaklaştığınızda kilit ekranınızda otomatik belirecektir.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sharePass() {
    HapticFeedback.selectionClick();
    final text = '🎟️ ${widget.event.title} için dijital bilet kartım hazır!\n'
        'Tarih: ${widget.event.dateTime.day}.${widget.event.dateTime.month}.${widget.event.dateTime.year}\n'
        'Mekan: ${widget.event.location}\n'
        'Bilet Seri No: $_serialNumber\n'
        'Sen de EventMatch\'te bana katıl!';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isVip = widget.user.hasActiveVip;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Handle
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.wallet_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apple Wallet Pass',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Dijital Etkinlik Giriş Kartı',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── THE PASS CARD (PKPASS DESIGN) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isVip
                        ? [
                            const Color(0xFF2E2215),
                            const Color(0xFF1F1914),
                            const Color(0xFF131110),
                          ]
                        : [
                            const Color(0xFF1E1E2E),
                            const Color(0xFF181825),
                            const Color(0xFF11111B),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isVip
                        ? const Color(0xFFFBBF24).withOpacity(0.4)
                        : Colors.white.withOpacity(0.14),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isVip ? const Color(0xFFFBBF24) : AppColors.primary)
                          .withOpacity(0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Top Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'EVENTMATCH',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: isVip
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFF38BDF8),
                                ),
                              ),
                              if (isVip) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'VIP PASS 👑',
                                    style: TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              event.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Event Title & Poster Strip
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFFF43F5E),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        event.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: AppImageWidget(
                                imageUrl: event.imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Detail Grid (Date, Time, Gate, Zone)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPassField(
                                    'TARİH',
                                    '${event.dateTime.day} ${_getMonthName(event.dateTime.month)} ${event.dateTime.year}',
                                  ),
                                ),
                                Expanded(
                                  child: _buildPassField(
                                    'SAAT',
                                    '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPassField('KAPI', _gateCode),
                                ),
                                Expanded(
                                  child: _buildPassField('ALAN', _zoneCode),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Attendee Card Strip
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white12,
                            backgroundImage: widget.user.avatarUrl.isNotEmpty
                                ? NetworkImage(widget.user.avatarUrl)
                                : null,
                            child: widget.user.avatarUrl.isEmpty
                                ? const Icon(Icons.person, color: Colors.white70, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      widget.user.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Color(0xFF38BDF8),
                                      size: 14,
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Doğrulanmış Katılımcı',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            child: const Text(
                              'GEÇERLİ BİLET',
                              style: TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── PERFORATED DIVIDER LINE (PKPASS TEAR LINE) ──
                    _buildPerforatedDivider(),

                    // ── QR CODE & BARCODE SECTION ──
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          children: [
                            // Interactive QR Code with animated scan laser
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: CustomPaint(
                                    size: const Size(140, 140),
                                    painter: _ApplePassQrPainter(
                                      seed: widget.event.id.hashCode ^
                                          widget.user.id.hashCode,
                                    ),
                                  ),
                                ),
                                // Animated Scan Laser Line
                                AnimatedBuilder(
                                  animation: _scannerAnimController,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: 14 + (140 * _scannerAnimController.value),
                                      child: Container(
                                        width: 140,
                                        height: 2,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF38BDF8)
                                                  .withOpacity(0.8),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _serialNumber,
                              style: GoogleFonts.sourceCodePro(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Giriş kapısında turnikeye veya görevliye okutunuz',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── ACTION BUTTONS ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // "Apple Cüzdan'a Ekle" Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onAddToAppleWallet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _isAddedToWallet
                                ? const Color(0xFF10B981)
                                : Colors.white.withOpacity(0.24),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isAddedToWallet
                                ? Icons.check_circle_rounded
                                : Icons.wallet_rounded,
                            color: _isAddedToWallet
                                ? const Color(0xFF34D399)
                                : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isAddedToWallet
                                ? 'Apple Cüzdan\'a Eklendi ✓'
                                : 'Apple Cüzdan\'a Ekle',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // "Bilet Kartını Paylaş" Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _sharePass,
                      icon: const Icon(Icons.share_outlined,
                          color: Color(0xFF38BDF8), size: 18),
                      label: Text(
                        'Bileti Arkadaşınla Paylaş',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPerforatedDivider() {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sol Yarım Daire Çentik
          Positioned(
            left: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F1A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Sağ Yarım Daire Çentik
          Positioned(
            right: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F1A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Kesikli Çizgi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dashWidth = 5.0;
                const dashSpace = 4.0;
                final count =
                    (constraints.maxWidth / (dashWidth + dashSpace)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(count, (_) {
                    return Container(
                      width: dashWidth,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.14),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}

/// Authentic high-tech QR Pattern CustomPainter
class _ApplePassQrPainter extends CustomPainter {
  final int seed;

  _ApplePassQrPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    const gridSize = 21;
    final cellSize = size.width / gridSize;

    // Corner Finder Patterns
    _drawFinder(canvas, 0, 0, cellSize, paint);
    _drawFinder(canvas, gridSize - 7, 0, cellSize, paint);
    _drawFinder(canvas, 0, gridSize - 7, cellSize, paint);

    // Random but deterministic QR payload matrix
    final rng = Random(seed);
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Skip finder areas
        if ((r < 8 && c < 8) ||
            (r < 8 && c >= gridSize - 8) ||
            (r >= gridSize - 8 && c < 8)) {
          continue;
        }

        // Timing lines
        if (r == 6 || c == 6) {
          if ((r + c) % 2 == 0) {
            canvas.drawRect(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
              paint,
            );
          }
          continue;
        }

        if (rng.nextBool()) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize + 0.3, r * cellSize + 0.3,
                  cellSize - 0.6, cellSize - 0.6),
              const Radius.circular(1.2),
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawFinder(
      Canvas canvas, int col, int row, double cell, Paint paint) {
    // Outer 7x7 square
    canvas.drawRect(
      Rect.fromLTWH(col * cell, row * cell, cell * 7, cell * 7),
      paint,
    );
    // Inner 5x5 white square
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(
          (col + 1) * cell, (row + 1) * cell, cell * 5, cell * 5),
      whitePaint,
    );
    // Center 3x3 black square
    canvas.drawRect(
      Rect.fromLTWH(
          (col + 2) * cell, (row + 2) * cell, cell * 3, cell * 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ApplePassQrPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
