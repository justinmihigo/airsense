import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/device_service.dart';

class DeviceProvider extends ChangeNotifier {
  final DeviceService _service;

  List<DeviceModel> _devices = [];
  bool _isLoading = false;
  String? _error;

  List<DeviceModel> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DeviceProvider(this._service);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _devices = await _service.getDevices();
    } on DioException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    await _service.deleteDevice(deviceId);
    _devices.removeWhere((d) => d.deviceId == deviceId);
    notifyListeners();
  }

  Future<void> refresh() => load();
}
