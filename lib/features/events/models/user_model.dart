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
  bool isVerified;

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
    this.isVerified = false,
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

  static bool isMaleGender(String? g) {
    if (g == null) return false;
    final lower = g.trim().toLowerCase();
    return lower == 'erkek' || lower == 'male' || lower == 'man' || lower == 'e' || lower == 'm';
  }

  static bool isFemaleGender(String? g) {
    if (g == null) return false;
    final lower = g.trim().toLowerCase();
    return lower == 'kadın' || lower == 'kadin' || lower == 'female' || lower == 'woman' || lower == 'k' || lower == 'f';
  }

  bool get isMale => isMaleGender(gender);
  bool get isFemale => isFemaleGender(gender);

  /// Fotoğrafın kullanıcı tarafından yüklenmiş gerçek bir fotoğraf olup olmadığını doğrular.
  /// Yapay zeka veya varsayılan Unsplash/placeholder fotoğraflarını geçersiz sayar.
  static bool isValidPhotoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http') && !trimmed.startsWith('assets/')) return false;
    if (trimmed.contains('unsplash.com')) return false;
    if (trimmed.contains('user_avatar.jpg')) return false;
    if (trimmed.contains('pravatar.cc')) return false;
    if (trimmed.contains('randomuser.me')) return false;
    return true;
  }

  bool get hasRealPhoto => isValidPhotoUrl(avatarUrl) || avatarUrls.any(isValidPhotoUrl);

  String get validAvatarUrl {
    if (isValidPhotoUrl(avatarUrl)) return avatarUrl.trim();
    for (var u in avatarUrls) {
      if (isValidPhotoUrl(u)) return u.trim();
    }
    return '';
  }

  List<String> get validAvatarUrls => avatarUrls.where(isValidPhotoUrl).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatarUrl': validAvatarUrl,
      'avatarUrls': validAvatarUrls,
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
      'is_verified': isVerified,
      'isVerified': isVerified,
      'badges': badges,
      'tags': tags,
      'plannedEvents': plannedEvents,
      'pastEvents': pastEvents,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawAvatar = map['avatarUrl']?.toString() ?? '';
    final rawAvatars = List<String>.from(map['avatarUrls'] ?? []);
    final cleanAvatars = rawAvatars.where(UserModel.isValidPhotoUrl).toList();
    final cleanAvatar = UserModel.isValidPhotoUrl(rawAvatar)
        ? rawAvatar
        : (cleanAvatars.isNotEmpty ? cleanAvatars.first : '');

    return UserModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Kullanıcı',
      username: map['username']?.toString(),
      avatarUrl: cleanAvatar,
      avatarUrls: cleanAvatars,
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
      isVerified: map['is_verified'] == true ||
          map['isVerified'] == true ||
          (map['badges'] is List && (map['badges'] as List).contains('verified')),
      badges: List<String>.from(map['badges'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      plannedEvents: List<String>.from(map['plannedEvents'] ?? []),
      pastEvents: List<String>.from(map['pastEvents'] ?? []),
    );
  }
}

