import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../events/models/event_model.dart';
import '../../events/models/user_model.dart';
import '../models/user_ticket_model.dart';

class TicketWalletService extends ChangeNotifier {
  static final TicketWalletService _instance = TicketWalletService._internal();
  factory TicketWalletService() => _instance;

  TicketWalletService._internal() {
    _initSeedTickets();
  }

  final List<UserTicketModel> _tickets = [];

  List<UserTicketModel> get allTickets => List.unmodifiable(_tickets);
  List<UserTicketModel> get activeTickets =>
      _tickets.where((t) => !t.isPast).toList();
  List<UserTicketModel> get pastTickets =>
      _tickets.where((t) => t.isPast).toList();

  void _initSeedTickets() {
    _tickets.addAll([
      UserTicketModel(
        id: 'ticket_sample_1',
        eventId: '1',
        eventTitle: 'Duman & Mor ve Ötesi Açık Hava Konseri',
        eventDate: DateTime.now().add(const Duration(days: 3, hours: 4)),
        venueName: 'KüçükÇiftlik Park, Maçka',
        city: 'İstanbul',
        ticketCode: 'EM-8291-7412',
        qrData: 'EVENTMATCH:TICKET:EM-8291-7412:DUMAN',
        category: 'Konser',
        price: 450.0,
        gate: 'Kapı B / Sahne Önü',
        seat: 'Protokol Alanı • Sıra 3 Koltuk 14',
        imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      UserTicketModel(
        id: 'ticket_sample_2',
        eventId: '2',
        eventTitle: 'Doğu Demirkol Tek Kişilik Stand-Up',
        eventDate: DateTime.now().add(const Duration(days: 7, hours: 2)),
        venueName: 'Bostancı Gösteri Merkezi',
        city: 'İstanbul',
        ticketCode: 'EM-3912-9018',
        qrData: 'EVENTMATCH:TICKET:EM-3912-9018:DOGU',
        category: 'Stand-Up',
        price: 350.0,
        gate: 'Ana Giriş • Balkon 1',
        seat: 'Kategori 1 • Sıra 5 Koltuk 20',
        imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      UserTicketModel(
        id: 'ticket_sample_past',
        eventId: 'past_1',
        eventTitle: 'Boğazda Gün Batımı Jazz Gecesi',
        eventDate: DateTime.now().subtract(const Duration(days: 15)),
        venueName: 'Moda Sahnesi, Kadıköy',
        city: 'İstanbul',
        ticketCode: 'EM-1945-3312',
        qrData: 'EVENTMATCH:TICKET:EM-1945-3312:JAZZ',
        category: 'Konser',
        price: 250.0,
        gate: 'A Kapısı',
        seat: 'Masa 8',
        imageUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=800',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
    ]);
  }

  Future<void> fetchUserTickets(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase
          .from('user_tickets')
          .select()
          .eq('user_id', userId)
          .order('event_date', ascending: true);

      final fetched = (res as List)
          .map((item) => UserTicketModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (fetched.isNotEmpty) {
        // Merge without duplicates
        for (final t in fetched) {
          if (!_tickets.any((existing) => existing.id == t.id || existing.ticketCode == t.ticketCode)) {
            _tickets.insert(0, t);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TicketWalletService] Supabase tickets fetch fallback: $e');
    }
  }

  Future<UserTicketModel> addTicketFromEvent(EventModel event, UserModel user) async {
    final existing = _tickets.firstWhere(
      (t) => t.eventId == event.id,
      orElse: () => UserTicketModel(
        id: '',
        eventId: '',
        eventTitle: '',
        eventDate: DateTime.now(),
        venueName: '',
        city: '',
        ticketCode: '',
        qrData: '',
        category: '',
        price: 0,
        gate: '',
        seat: '',
        createdAt: DateTime.now(),
      ),
    );

    if (existing.id.isNotEmpty) {
      return existing;
    }

    final hash1 = (event.id.hashCode.abs() % 90000) + 10000;
    final hash2 = (user.id.hashCode.abs() % 9000) + 1000;
    final code = 'EM-$hash1-$hash2';

    final newTicket = UserTicketModel(
      id: 'ticket_${DateTime.now().millisecondsSinceEpoch}',
      eventId: event.id,
      eventTitle: event.title,
      eventDate: event.dateTime,
      venueName: event.location.isNotEmpty ? event.location : 'Etkinlik Alanı',
      city: event.city.isNotEmpty ? event.city : 'İstanbul',
      ticketCode: code,
      qrData: 'EVENTMATCH:PASS:$code:${event.id}',
      category: event.category,
      price: double.tryParse(event.price?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0.0,
      gate: user.hasActiveVip ? 'VIP Girişi / Öncelikli Kapı' : 'Genel Giriş Kapısı A',
      seat: user.hasActiveVip ? 'VIP Lounge / Sahne Önü' : 'Genel Katılım',
      imageUrl: event.imageUrl,
      createdAt: DateTime.now(),
    );

    _tickets.insert(0, newTicket);
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('user_tickets').insert({
        'user_id': user.id,
        'event_id': event.id,
        'event_title': event.title,
        'event_date': event.dateTime.toIso8601String(),
        'venue_name': event.location,
        'ticket_code': code,
        'qr_data': 'EVENTMATCH:PASS:$code:${event.id}',
        'price': double.tryParse(event.price?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0.0,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[TicketWalletService] Supabase ticket save fallback: $e');
    }

    return newTicket;
  }
}
