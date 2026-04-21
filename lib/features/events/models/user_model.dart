class UserModel {
  final String id;
  String name;
  String avatarUrl;
  String? age;
  String? aboutMe;
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
    this.aboutMe,
    this.latitude,
    this.longitude,
    this.points = 0,
    this.checkedInEventId,
    List<String>? badges,
    List<String>? tags,
    List<String>? plannedEvents,
    List<String>? pastEvents,
  })  : badges = badges ?? [],
        tags = tags ?? [],
        plannedEvents = plannedEvents ?? [],
        pastEvents = pastEvents ?? [];
}
