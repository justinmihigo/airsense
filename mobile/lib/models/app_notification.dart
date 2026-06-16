enum NotificationCategory { dailyUpdate, password, alert, system }

class AppNotification {
  final String id;
  final NotificationCategory category;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isDismissed;

  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isDismissed = false,
  });

  String get categoryLabel {
    switch (category) {
      case NotificationCategory.dailyUpdate:
        return 'Daily update';
      case NotificationCategory.password:
        return 'password';
      case NotificationCategory.alert:
        return 'Alert';
      case NotificationCategory.system:
        return 'System';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      category: NotificationCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => NotificationCategory.system,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isDismissed: json['isDismissed'] as bool? ?? false,
    );
  }
}
