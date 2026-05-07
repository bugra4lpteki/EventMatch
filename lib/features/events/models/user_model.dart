class UserModel {
  final String id;
  String name;
  String avatarUrl;
  List<String> avatarUrls;
  String? age;
  String? gender;
  String? aboutMe;
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
    required this.avatarUrl,
    this.age,
    this.gender,
    this.aboutMe,
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
}
