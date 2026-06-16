import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;

  List<NotifModel> _items = [];
  bool _isLoading = false;

  List<NotifModel> get items => _items;
  int get unreadCount => _items.where((n) => !n.read).length;
  bool get isLoading => _isLoading;

  NotificationProvider(this._service);

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _service.getNotifications();
    } on DioException {
      // ignore: empty_catches
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    await _service.markRead(id);
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _items[idx] = NotifModel(
        id: _items[idx].id,
        message: _items[idx].message,
        level: _items[idx].level,
        device: _items[idx].device,
        field: _items[idx].field,
        read: true,
        createdAt: _items[idx].createdAt,
      );
      notifyListeners();
    }
  }

  void dismiss(String id) {
    _items.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
