class UserModel {
  final String id;
  String name;
  String avatarUrl;
  String? age;
  String? aboutMe;
  double? latitude;
  double? longitude;

  UserModel({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.age,
    this.aboutMe,
    this.latitude,
    this.longitude,
  });
}
