class UserTicketModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final DateTime eventDate;
  final String venueName;
  final String city;
  final String ticketCode;
  final String qrData;
  final String category;
  final double price;
  final String gate;
  final String seat;
  final String? imageUrl;
  final DateTime createdAt;

  const UserTicketModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.eventDate,
    required this.venueName,
    required this.city,
    required this.ticketCode,
    required this.qrData,
    required this.category,
    required this.price,
    required this.gate,
    required this.seat,
    this.imageUrl,
    required this.createdAt,
  });

  bool get isPast => eventDate.isBefore(DateTime.now());

  factory UserTicketModel.fromMap(Map<String, dynamic> map) {
    return UserTicketModel(
      id: map['id']?.toString() ?? '',
      eventId: map['event_id']?.toString() ?? '',
      eventTitle: map['event_title']?.toString() ?? 'Etkinlik Bileti',
      eventDate: map['event_date'] != null
          ? DateTime.tryParse(map['event_date'].toString()) ?? DateTime.now().add(const Duration(days: 3))
          : DateTime.now().add(const Duration(days: 3)),
      venueName: map['venue_name']?.toString() ?? 'Etkinlik Mekanı',
      city: map['city']?.toString() ?? 'İstanbul',
      ticketCode: map['ticket_code']?.toString() ?? 'EM-1001-2002',
      qrData: map['qr_data']?.toString() ?? 'EVENTMATCH:TICKET:${map['id']}',
      category: map['category']?.toString() ?? 'Etkinlik',
      price: (map['price'] is num) ? (map['price'] as num).toDouble() : 0.0,
      gate: map['gate']?.toString() ?? 'Kapı A1',
      seat: map['seat']?.toString() ?? 'Genel Giriş',
      imageUrl: map['image_url']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'event_title': eventTitle,
      'event_date': eventDate.toIso8601String(),
      'venue_name': venueName,
      'city': city,
      'ticket_code': ticketCode,
      'qr_data': qrData,
      'category': category,
      'price': price,
      'gate': gate,
      'seat': seat,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
