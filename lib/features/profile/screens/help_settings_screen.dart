import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class HelpSettingsScreen extends StatefulWidget {
  const HelpSettingsScreen({super.key});

  @override
  State<HelpSettingsScreen> createState() => _HelpSettingsScreenState();
}

class _HelpSettingsScreenState extends State<HelpSettingsScreen> {
  final _messageController = TextEditingController();
  String _selectedCategory = 'Genel Soru';
  bool _isSending = false;

  final List<Map<String, String>> _faqItems = [
    {
      'question': 'EventMatch nasıl çalışır?',
      'answer': 'EventMatch, çevrenizdeki konser, tiyatro, parti ve spor etkinliklerini keşfetmenizi ve bu etkinliklere gitmek isteyen yeni insanlarla eşleşip sosyalleşmenizi sağlar.'
    },
    {
      'question': 'Etkinliklere nasıl katılırım veya ev sahibi olurum?',
      'answer': 'Keşfet sayfasından dilediğiniz etkinliği seçip "Katıl" butonuna basabilir veya artı (+) butonunu kullanarak kendi özel etkinliğinizi oluşturabilirsiniz.'
    },
    {
      'question': 'Bilet satın alma işlemleri güvenli mi?',
      'answer': 'EventMatch sizi doğrudan Biletix, Biletinial, Bubilet veya Passo gibi resmi bilet sağlayıcılarına yönlendirir. Ödeme güvenliğiniz doğrudan bu sağlayıcılar tarafından güvence altındadır.'
    },
    {
      'question': 'Eşleştiğim biriyle mesajlaşmayı nasıl durdurabilirim?',
      'answer': 'Mesaj ekranının sağ üst köşesindeki ayarlar menüsünden kullanıcıyı engelleyebilir veya eşleşmeyi dilediğiniz an kaldırabilirsiniz.'
    },
    {
      'question': 'Şifremi unutursam ne yapmalıyım?',
      'answer': 'Giriş ekranında yer alan "Şifremi Unuttum" seçeneği ile kayıtlı e-posta adresinize sıfırlama bağlantısı gönderebilirsiniz.'
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen destek ekibimize iletmek istediğiniz mesajı yazın.', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() => _isSending = false);
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Talebiniz destek ekibimize iletildi! En kısa sürede e-posta ile dönüş yapılacaktır.', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Yardım & Destek', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ Section Header
            Row(
              children: [
                Icon(Icons.help_center_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Sıkça Sorulan Sorular',
                  style: GoogleFonts.outfit(color: AppColors.primaryVariant, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // FAQ ExpansionTiles Accordion
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: _faqItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            iconColor: AppColors.primary,
                            collapsedIconColor: AppColors.textSecondary,
                            title: Text(
                              item['question']!,
                              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                                child: Text(
                                  item['answer']!,
                                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index < _faqItems.length - 1)
                          Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Support Contact Form Header
            Row(
              children: [
                Icon(Icons.support_agent_rounded, color: AppColors.secondary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Destek Ekibine Yazın',
                  style: GoogleFonts.outfit(color: AppColors.secondary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contact Form Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konu Başlığı',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: AppColors.surface,
                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    items: ['Genel Soru', 'Teknik Hata', 'Bilet & Etkinlik', 'Şikayet & Bildirim']
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Mesajınız',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    maxLines: 4,
                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Sorununuzu veya önerinizi buraya detaylıca yazın...',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(
                        _isSending ? 'GÖNDERİLİYOR...' : 'DESTEK TALEBİ GÖNDER',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
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
}
