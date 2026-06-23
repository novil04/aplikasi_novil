import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class NotificationManager extends ChangeNotifier {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final List<NotificationItem> _notifications = [];
  final NotificationService _notificationService = NotificationService();
  
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Initialize
  Future<void> initialize() async {
    await _notificationService.initialize();
    await _loadNotifications();
  }

  // Add notification
  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    bool showPush = true,
  }) async {
    final notification = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
    );

    _notifications.insert(0, notification);
    
    // Show push notification
    if (showPush) {
      await _notificationService.showNotification(
        id: notification.timestamp.millisecondsSinceEpoch % 100000,
        title: title,
        body: message,
        payload: notification.id,
      );
    }

    await _saveNotifications();
    notifyListeners();
  }

  // Mark as read
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      _saveNotifications();
      notifyListeners();
    }
  }

  // Mark all as read
  void markAllAsRead() {
    for (var notification in _notifications) {
      notification.isRead = true;
    }
    _saveNotifications();
    notifyListeners();
  }

  // Delete notification
  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _saveNotifications();
    notifyListeners();
  }

  // Clear all
  void clearAll() {
    _notifications.clear();
    _saveNotifications();
    notifyListeners();
  }

  // Save to local storage
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString('notifications', jsonEncode(jsonList));
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  // Load from local storage
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('notifications');
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        _notifications.clear();
        _notifications.addAll(
          jsonList.map((json) => NotificationItem.fromJson(json)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  // Notification helpers for specific events
  Future<void> notifyPengeringanDimulai() async {
    await addNotification(
      title: 'Pengeringan Dimulai',
      message: 'Proses pengeringan ikan telah dimulai',
      type: NotificationType.info,
    );
  }

  Future<void> notifyIkanTerdeteksi(double berat) async {
    await addNotification(
      title: 'Ikan Terdeteksi',
      message: 'Berat ikan: ${berat.toStringAsFixed(0)} gram',
      type: NotificationType.info,
    );
  }

  Future<void> notifyPengeringanBerjalan(double berat, double target) async {
    await addNotification(
      title: 'Pengeringan Berjalan',
      message: 'Berat: ${berat.toStringAsFixed(0)}g | Target: ${target.toStringAsFixed(0)}g',
      type: NotificationType.info,
      showPush: false, // Don't show push for regular updates
    );
  }

  Future<void> notifyPengeringanSelesai(double beratAkhir) async {
    await addNotification(
      title: 'Pengeringan Selesai',
      message: 'Target tercapai! Berat akhir: ${beratAkhir.toStringAsFixed(0)} gram',
      type: NotificationType.success,
    );
  }

  Future<void> notifySuhuTinggi(double suhu) async {
    await addNotification(
      title: 'Peringatan Suhu Tinggi',
      message: 'Suhu mencapai ${suhu.toStringAsFixed(1)}°C',
      type: NotificationType.warning,
    );
  }

  Future<void> notifyKoneksiTerputus() async {
    await addNotification(
      title: 'Koneksi Terputus',
      message: 'Koneksi ke sistem terputus',
      type: NotificationType.error,
    );
  }

  Future<void> notifyKoneksiTersambung() async {
    await addNotification(
      title: 'Koneksi Tersambung',
      message: 'Terhubung ke sistem pengering ikan',
      type: NotificationType.success,
    );
  }
}
