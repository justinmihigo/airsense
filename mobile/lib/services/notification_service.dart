import 'package:dio/dio.dart';

enum NotifLevel { info, warning, critical }

class NotifModel {
  final String id;
  final String message;
  final NotifLevel level;
  final String? device;
  final String? field;
  final bool read;
  final DateTime createdAt;

  const NotifModel({
    required this.id,
    required this.message,
    required this.level,
    this.device,
    this.field,
    required this.read,
    required this.createdAt,
  });

  factory NotifModel.fromJson(Map<String, dynamic> json) => NotifModel(
        id: json['id'] as String,
        message: json['message'] as String,
        level: _parseLevel(json['level'] as String? ?? 'info'),
        device: json['device'] as String?,
        field: json['field'] as String?,
        read: (json['read'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  static NotifLevel _parseLevel(String l) => switch (l) {
        'warning' => NotifLevel.warning,
        'critical' => NotifLevel.critical,
        _ => NotifLevel.info,
      };
}

class NotificationService {
  final Dio _dio;

  NotificationService(this._dio);

  Future<List<NotifModel>> getNotifications({int limit = 50}) async {
    final res =
        await _dio.get('/api/notifications', queryParameters: {'limit': limit});
    final list = res.data as List<dynamic>;
    return list
        .map((e) => NotifModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String notificationId) =>
      _dio.patch('/api/notifications/$notificationId/read');
}
