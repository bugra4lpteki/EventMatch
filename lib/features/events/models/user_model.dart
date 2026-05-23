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
}
