import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../../features/events/services/moderation_service.dart';

class ReportBlockSheet {
  /// Kullanıcı için Seçenekler (Şikayet Et, Engelle)
  static void showOptionsModal(
    BuildContext context, {
    required String userId,
    required String userName,
    VoidCallback? onUserBlocked,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$userName ile İlgili İşlem',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 20),
                ),
                title: const Text(
                  'Kullanıcıyı Şikayet Et',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Topluluk kurallarına aykırı davranış veya içerikleri bildirin',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  showReportDialog(context, userId: userId, userName: userName, onUserBlocked: onUserBlocked);
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                ),
                title: const Text(
                  'Kullanıcıyı Engelle',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Bu kullanıcıyı bir daha görmezsiniz ve size mesaj atamaz',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  showBlockConfirmationDialog(context, userId: userId, userName: userName, onUserBlocked: onUserBlocked);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
      },
    );
  }

  /// Gönderi / Etkinlik Seçenekleri (Akıştan Kaldır, Şikayet Et, Düzenleyeni Engelle)
  static void showEventOptionsModal(
    BuildContext context, {
    required String eventId,
    required String eventTitle,
    String? organizerId,
    String? organizerName,
    VoidCallback? onEventHidden,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Etkinlik Seçenekleri',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                eventTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              // Akıştan Hemen Kaldır
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.visibility_off_rounded, color: Colors.blueAccent, size: 20),
                ),
                title: const Text(
                  'Bu Gönderiyi Akışımdan Kaldır',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Bu etkinliği ana sayfanızda bir daha görmezsiniz',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  await ModerationService().hideEvent(eventId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Etkinlik akışınızdan kaldırıldı.'),
                        backgroundColor: Colors.black87,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  onEventHidden?.call();
                },
              ),
              const Divider(color: Colors.white10),
              // Şikayet Et
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 20),
                ),
                title: const Text(
                  'Etkinliği Şikayet Et',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Uygunsuz veya yanıltıcı içerik bildirimi yapın (24 saatte incelenir)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  showReportEventDialog(
                    context,
                    eventId: eventId,
                    eventTitle: eventTitle,
                    organizerId: organizerId,
                    onEventHidden: onEventHidden,
                  );
                },
              ),
              if (organizerId != null && organizerId.isNotEmpty) ...[
                const Divider(color: Colors.white10),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 20),
                  ),
                  title: Text(
                    '${organizerName ?? "Düzenleyiciyi"} Engelle',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Bu kullanıcının etkinliklerini ve mesajlarını tamamen engelle',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    showBlockConfirmationDialog(
                      context,
                      userId: organizerId,
                      userName: organizerName ?? 'Düzenleyici',
                      onUserBlocked: onEventHidden,
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
      },
    );
  }

  /// Mesaj Seçenekleri (Mekân ve Birebir Sohbet için)
  static void showMessageOptionsModal(
    BuildContext context, {
    required String messageId,
    required String senderId,
    required String senderName,
    required String messageText,
    VoidCallback? onActionDone,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mesaj Seçenekleri',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 20),
                ),
                title: const Text(
                  'Mesajı ve Göndereni Şikayet Et',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Uygunsuz içerik / taciz bildirimi (24 saat içinde incelenir)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  showReportDialog(
                    context,
                    userId: senderId,
                    userName: senderName,
                    onUserBlocked: onActionDone,
                  );
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                ),
                title: Text(
                  '$senderName Adlı Kullanıcıyı Engelle',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Bu kullanıcının mesajları sizden gizlenecektir',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  showBlockConfirmationDialog(
                    context,
                    userId: senderId,
                    userName: senderName,
                    onUserBlocked: onActionDone,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
      },
    );
  }

  static void showBlockConfirmationDialog(
    BuildContext context, {
    required String userId,
    required String userName,
    VoidCallback? onUserBlocked,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            '$userName Engellensin mi?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          content: Text(
            'Bu kullanıcı engellendiğinde karşılıklı eşleşme havuzunuzdan, etkinliklerden ve mesajlarınızdan anında tamamen kaldırılacaktır.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await ModerationService().blockUser(userId, userName: userName);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🚫 $userName başarıyla engellendi.'),
                      backgroundColor: Colors.black87,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
                onUserBlocked?.call();
              },
              child: const Text('Engelle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Kullanıcı Şikayet Penceresi
  static void showReportDialog(
    BuildContext context, {
    required String userId,
    required String userName,
    VoidCallback? onUserBlocked,
  }) {
    final reasons = [
      'Taciz, Tehdit veya Rahatsız Edici Davranış',
      'Uygunsuz veya Müstehcen Fotoğraf / İçerik',
      'Sahte Profil veya Başkasını Taklit Etme',
      'Spam, Dolandırıcılık veya İstenmeyen Reklam',
      'Nefret Söylemi veya Ayrımcılık',
      'Diğer Sakıncalı Davranış',
    ];
    String selectedReason = reasons.first;
    final detailsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (reportContext) {
        return StatefulBuilder(
          builder: (context, setReportState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Şikayet Et: $userName',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Apple 1.2 Zorunlu Taahhüt Kutusu
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '🛡️ EventMatch sıfır tolerans politikası: Şikayetiniz en geç 24 saat içinde incelenir, sakıncalı içerik yayından kaldırılır ve kural ihlali yapan kullanıcı platformdan ihraç edilir.\nGeliştirici İletişim: guvenlik@eventmatch.app',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...reasons.map((r) {
                    final isSelected = selectedReason == r;
                    return InkWell(
                      onTap: () {
                        setReportState(() {
                          selectedReason = r;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? AppColors.primary : Colors.white38,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ek ayrıntı ekleyin (İsteğe bağlı)...',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await ModerationService().reportUser(
                          reportedUserId: userId,
                          reportedUserName: userName,
                          reason: selectedReason,
                          details: detailsController.text.trim(),
                        );

                        if (reportContext.mounted) Navigator.pop(reportContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Şikayetiniz alındı. 24 saat içinde incelenecektir. Kullanıcı engellendi.'),
                              backgroundColor: Colors.black87,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                        onUserBlocked?.call();
                      },
                      child: const Text(
                        'ŞİKAYETİ GÖNDER & ENGELLE',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Etkinlik Şikayet Penceresi
  static void showReportEventDialog(
    BuildContext context, {
    required String eventId,
    required String eventTitle,
    String? organizerId,
    VoidCallback? onEventHidden,
  }) {
    final reasons = [
      'Uygunsuz veya Müstehcen İçerik/Fotoğraf',
      'Yanıltıcı, Sahte veya Dolandırıcılık Amaçlı',
      'Yasadışı Faaliyet veya Şiddet Teşviki',
      'Nefret Söylemi veya Hakaret',
      'Spam veya Ticari Reklam',
      'Diğer Kural İhlali',
    ];
    String selectedReason = reasons.first;
    final detailsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (reportContext) {
        return StatefulBuilder(
          builder: (context, setReportState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Etkinliği Şikayet Et',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '🛡️ Şikayet edilen etkinlik akışınızdan derhal kaldırılır ve ekibimiz tarafından 24 saat içinde incelenerek uygunsuz ise kalıcı olarak silinir.\nGeliştirici İletişim: guvenlik@eventmatch.app',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...reasons.map((r) {
                    final isSelected = selectedReason == r;
                    return InkWell(
                      onTap: () {
                        setReportState(() {
                          selectedReason = r;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? AppColors.primary : Colors.white38,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ayrıntılı açıklama ekleyin...',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await ModerationService().reportEvent(
                          eventId: eventId,
                          eventTitle: eventTitle,
                          organizerId: organizerId,
                          reason: selectedReason,
                          details: detailsController.text.trim(),
                        );

                        if (reportContext.mounted) Navigator.pop(reportContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Etkinlik şikayet edildi ve akışınızdan kaldırıldı.'),
                              backgroundColor: Colors.black87,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                        onEventHidden?.call();
                      },
                      child: const Text(
                        'ŞİKAYETİ BİLDİR VE AKIŞTAN KALDIR',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
