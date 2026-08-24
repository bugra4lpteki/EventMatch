class UserModel {
  String id;
  String name;
  String? username;
  String avatarUrl;
  List<String> avatarUrls;
  String? city;
  String? gender;
  String? aboutMe;
  DateTime? birthDate;
  List<String> socialLinks;
  double? latitude;
  double? longitude;
  List<String> tags;
  List<String> plannedEvents;
  List<String> pastEvents;
  int points;
  List<String> badges;
  String? checkedInEventId;
  bool isOnline;
  bool hideLastSeen;
  bool isPrivateProfile;
  bool hideEvents;
  bool enableLocationSharing;

  UserModel({
    required this.id,
    required this.name,
    this.username,
    required this.avatarUrl,
    this.city,
    this.gender,
    this.aboutMe,
    this.birthDate,
    this.socialLinks = const [],
    this.latitude,
    this.longitude,
    this.points = 0,
    this.checkedInEventId,
    this.isOnline = true,
    this.hideLastSeen = false,
    this.isPrivateProfile = false,
    this.hideEvents = false,
    this.enableLocationSharing = true,
    List<String>? badges,
    List<String>? tags,
    List<String>? avatarUrls,
    List<String>? plannedEvents,
    List<String>? pastEvents,
  })  : badges = badges ?? [],
        tags = tags ?? [],
        avatarUrls = avatarUrls ?? [],
        plannedEvents = plannedEvents ?? [],
        pastEvents = pastEvents ?? [];

  String? get age {
    if (birthDate == null) return null;
    final yearDiff = DateTime.now().year - birthDate!.year;
    return yearDiff.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatarUrl': avatarUrl,
      'avatarUrls': avatarUrls,
      'city': city,
      'gender': gender,
      'aboutMe': aboutMe,
      'birthDate': birthDate?.toIso8601String(),
      'socialLinks': socialLinks,
      'latitude': latitude,
      'longitude': longitude,
      'points': points,
      'checkedInEventId': checkedInEventId,
      'isOnline': isOnline,
      'hideLastSeen': hideLastSeen,
      'isPrivateProfile': isPrivateProfile,
      'hideEvents': hideEvents,
      'enableLocationSharing': enableLocationSharing,
      'badges': badges,
      'tags': tags,
      'plannedEvents': plannedEvents,
      'pastEvents': pastEvents,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Kullanıcı',
      username: map['username']?.toString(),
      avatarUrl: map['avatarUrl']?.toString() ?? '',
      avatarUrls: List<String>.from(map['avatarUrls'] ?? []),
      city: map['city']?.toString(),
      gender: map['gender']?.toString(),
      aboutMe: map['aboutMe']?.toString(),
      birthDate: map['birthDate'] != null ? DateTime.tryParse(map['birthDate'].toString()) : null,
      socialLinks: List<String>.from(map['socialLinks'] ?? []),
      latitude: map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : null,
      longitude: map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : null,
      points: map['points'] is int ? map['points'] : 0,
      checkedInEventId: map['checkedInEventId']?.toString(),
      isOnline: map['isOnline'] == true,
      hideLastSeen: map['hideLastSeen'] == true,
      isPrivateProfile: map['isPrivateProfile'] == true,
      hideEvents: map['hideEvents'] == true,
      enableLocationSharing: map['enableLocationSharing'] != false,
      badges: List<String>.from(map['badges'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      plannedEvents: List<String>.from(map['plannedEvents'] ?? []),
      pastEvents: List<String>.from(map['pastEvents'] ?? []),
    );
  }
}

