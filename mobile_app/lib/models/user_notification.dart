class UserNotification {
  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  UserNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}
