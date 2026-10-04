import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/services/moderation_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ModerationService _modService = ModerationService();

  @override
  void initState() {
    super.initState();
    _modService.addListener(_onModChanged);
  }

  @override
  void dispose() {
    _modService.removeListener(_onModChanged);
    super.dispose();
  }

  void _onModChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final blockedIds = _modService.blockedUserIds.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Engellenen Kullanıcılar',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: blockedIds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: const Icon(Icons.block_rounded, size: 48, color: Colors.white38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Engellenen Kullanıcı Yok',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Engellediğiniz kullanıcılar burada listelenir ve size mesaj atamaz, etkinliklerinizi göremez.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: blockedIds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final id = blockedIds[index];
                final name = _modService.getBlockedUserName(id);
                final displayName = name.isNotEmpty ? name : 'Kullanıcı (${id.substring(0, id.length > 6 ? 6 : id.length)})';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                        child: const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Engellendi',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _modService.unblockUser(id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$displayName engeli kaldırıldı.'),
                                backgroundColor: Colors.black87,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Engeli Kaldır', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
