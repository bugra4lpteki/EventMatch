import 'user_model.dart';

class GroupModel {
  final String id;
  final List<UserModel> members;
  final String name;
  final String? groupBio;
  final List<String> commonInterests;

  GroupModel({
    required this.id,
    required this.members,
    required this.name,
    this.groupBio,
    List<String>? commonInterests,
  }) : commonInterests = commonInterests ?? [];

  String get avatarUrl1 => members.isNotEmpty ? members[0].avatarUrl : '';
  String get avatarUrl2 => members.length > 1 ? members[1].avatarUrl : '';
}
