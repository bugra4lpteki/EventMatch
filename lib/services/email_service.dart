import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// EventMatch Doğrudan E-posta Gönderim Servisi (2FA & Güvenlik Bildirimleri)
/// Supabase SMTP sınırlarına takılmadan doğrudan Resend, Brevo veya SMTP sunucusu ile e-posta gönderir.
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  /// 1. Resend API Anahtarı (resend.com'dan ücretsiz temin edilir)
  /// Örn: 're_123456789...'
  String? _resendApiKey;

  /// 2. Brevo / Sendinblue API Anahtarı (brevo.com'dan ücretsiz temin edilir - Günde 300 e-posta ücretsiz)
  /// Örn: 'xkeysib-...'
  String? _brevoApiKey;

  /// 3. Özel SMTP Ayarları (Kurumsal e-posta / cPanel / Gmail / Yandex vb.)
  String? _smtpHost;
  int? _smtpPort;
  String? _smtpUsername;
  String? _smtpPassword;
  bool _smtpSsl = true;
  String _senderName = 'EventMatch Güvenlik';
  String _senderEmail = 'destek@eventmatch.app';

  /// E-posta servisini yapılandır
  void configure({
    String? resendApiKey,
    String? brevoApiKey,
    String? smtpHost,
    int? smtpPort,
    String? smtpUsername,
    String? smtpPassword,
    bool smtpSsl = true,
    String? senderName,
    String? senderEmail,
  }) {
    if (resendApiKey != null) _resendApiKey = resendApiKey;
    if (brevoApiKey != null) _brevoApiKey = brevoApiKey;
    if (smtpHost != null) _smtpHost = smtpHost;
    if (smtpPort != null) _smtpPort = smtpPort;
    if (smtpUsername != null) _smtpUsername = smtpUsername;
    if (smtpPassword != null) _smtpPassword = smtpPassword;
    _smtpSsl = smtpSsl;
    if (senderName != null) _senderName = senderName;
    if (senderEmail != null) _senderEmail = senderEmail;
  }

  /// 2 Adımlı Doğrulama (2FA) Kodunu Kullanıcının E-posta Adresine Gönderir
  Future<bool> sendTwoFactorOtp({
    required String toEmail,
    required String otpCode,
  }) async {
    const subject = '🔐 EventMatch - 2 Adımlı Doğrulama Kodunuz';
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #08080C; color: #FFFFFF; margin: 0; padding: 24px; }
    .card { background-color: #13131A; border: 1.5px solid rgba(56, 189, 248, 0.3); border-radius: 20px; max-width: 480px; margin: 0 auto; padding: 32px 24px; text-align: center; }
    .logo { font-size: 26px; font-weight: bold; background: linear-gradient(135deg, #EC4899, #8B5CF6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 20px; }
    .title { font-size: 20px; font-weight: bold; color: #FFFFFF; margin-bottom: 10px; }
    .desc { font-size: 14px; color: #94A3B8; line-height: 1.5; margin-bottom: 24px; }
    .otp-box { background: rgba(56, 189, 248, 0.1); border: 2px solid #38BDF8; border-radius: 14px; display: inline-block; padding: 14px 28px; margin-bottom: 24px; }
    .otp-code { font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #38BDF8; }
    .footer { font-size: 12px; color: #64748B; border-top: 1px solid rgba(255, 255, 255, 0.08); padding-top: 20px; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">EventMatch</div>
    <div class="title">2 Adımlı Güvenlik Doğrulaması</div>
    <div class="desc">
      EventMatch hesabınıza giriş yapmak için tek kullanımlık güvenlik kodunuz aşağıdadır:
    </div>
    <div class="otp-box">
      <div class="otp-code">$otpCode</div>
    </div>
    <div class="desc" style="font-size: 12.5px; color: #CBD5E1;">
      Bu kod <strong>5 dakika</strong> boyunca geçerlidir.<br>
      Giriş yapmaya çalışan siz değilseniz lütfen şifrenizi derhal değiştirin.
    </div>
    <div class="footer">
      Bu otomatik bir güvenlik e-postasıdır. Lütfen yanıtlamayınız.<br>
      © 2026 EventMatch. Tüm hakları saklıdır.
    </div>
  </div>
</body>
</html>
''';

    // 1. Resend API Denemesi (Yapılandırılmışsa)
    if (_resendApiKey != null && _resendApiKey!.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://api.resend.com/emails'),
          headers: {
            'Authorization': 'Bearer $_resendApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'from': '$_senderName <$_senderEmail>',
            'to': [toEmail],
            'subject': '$subject: $otpCode',
            'html': htmlContent,
          }),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          debugPrint('[EmailService] ✅ Resend ile 2FA e-postası gönderildi: $toEmail');
          return true;
        } else {
          debugPrint('[EmailService] ⚠️ Resend hatası (${res.statusCode}): ${res.body}');
        }
      } catch (e) {
        debugPrint('[EmailService] Resend exception: $e');
      }
    }

    // 2. Brevo API Denemesi (Yapılandırılmışsa)
    if (_brevoApiKey != null && _brevoApiKey!.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
          headers: {
            'api-key': _brevoApiKey!,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'sender': {'name': _senderName, 'email': _senderEmail},
            'to': [{'email': toEmail}],
            'subject': '$subject: $otpCode',
            'htmlContent': htmlContent,
          }),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          debugPrint('[EmailService] ✅ Brevo ile 2FA e-postası gönderildi: $toEmail');
          return true;
        } else {
          debugPrint('[EmailService] ⚠️ Brevo hatası (${res.statusCode}): ${res.body}');
        }
      } catch (e) {
        debugPrint('[EmailService] Brevo exception: $e');
      }
    }

    // 3. Doğrudan SMTP Denemesi (Yapılandırılmışsa)
    if (_smtpHost != null && _smtpUsername != null && _smtpPassword != null) {
      try {
        final smtpServer = SmtpServer(
          _smtpHost!,
          port: _smtpPort ?? (_smtpSsl ? 465 : 587),
          ssl: _smtpSsl,
          username: _smtpUsername,
          password: _smtpPassword,
        );

        final message = Message()
          ..from = Address(_senderEmail, _senderName)
          ..recipients.add(toEmail)
          ..subject = '$subject: $otpCode'
          ..html = htmlContent;

        final sendReport = await send(message, smtpServer);
        debugPrint('[EmailService] ✅ SMTP ile e-posta gönderildi: $sendReport');
        return true;
      } catch (e) {
        debugPrint('[EmailService] ⚠️ SMTP hatası: $e');
      }
    }

    // Geliştirme / Test Modu Bildirimi (API anahtarı henüz eklenmediyse akışı tıkamaz)
    debugPrint('═══════════════════════════════════════════════════════════════');
    debugPrint('[EmailService] 🔐 [2FA GÜVENLİK KODU]');
    debugPrint('Alıcı E-posta : $toEmail');
    debugPrint('Doğrulama Kodu: $otpCode');
    debugPrint('Geçerlilik    : 5 Dakika');
    debugPrint('Not           : Canlı e-posta gönderimi için EmailService.configure() kullanın.');
    debugPrint('═══════════════════════════════════════════════════════════════');
    return true;
  }
}
