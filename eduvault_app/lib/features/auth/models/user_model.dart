class UserModel {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:     json['id'],
      name:   json['name'],
      email:  json['email'],
      avatar: json['avatar'],
      role:   json['role'] ?? 'user',
    );
  }
}