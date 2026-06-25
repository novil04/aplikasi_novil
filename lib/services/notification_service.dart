import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for Android 13+
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      _initialized = true;
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // You can navigate to specific screen here if needed
  }

  // Show notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool playSound = true,
    bool showBadge = true,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'pengering_ikan_channel',
      'Pengering Ikan',
      channelDescription: 'Notifikasi untuk sistem pengering ikan',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: playSound,
      enableLights: true,
      color: const Color(0xFF2196F3),
      ledColor: const Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
      ongoing: false,
      autoCancel: true,
      channelShowBadge: showBadge,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
      print('📱 Notification shown: $title - $body');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  // Show notification for pengeringan selesai
  Future<void> notifyPengeringanSelesai(double beratAkhir) async {
    print('🔔 NotificationService: Showing pengeringan selesai notification');
    print('   Initialized: $_initialized');
    print('   Berat akhir: $beratAkhir');
    
    try {
      await showNotification(
        id: 4,
        title: '✅ Pengeringan Selesai',
        body: 'Target tercapai! Berat akhir: ${beratAkhir.toStringAsFixed(0)} gram',
        payload: 'pengeringan_selesai',
        playSound: true,
        showBadge: true,
      );
      print('✅ NotificationService: Notification sent successfully');
    } catch (e) {
      print('❌ NotificationService: Error sending notification: $e');
    }
  }

  // Show notification for suhu tinggi
  Future<void> notifySuhuTinggi(double suhu) async {
    await showNotification(
      id: 5,
      title: '⚠️ Peringatan Suhu Tinggi',
      body: 'Suhu mencapai ${suhu.toStringAsFixed(1)}°C',
      payload: 'suhu_tinggi',
    );
  }

  // Show notification for koneksi terputus
  Future<void> notifyKoneksiTerputus() async {
    await showNotification(
      id: 6,
      title: '❌ Koneksi Terputus',
      body: 'Koneksi ke sistem terputus',
      payload: 'koneksi_terputus',
    );
  }

  // Show notification for koneksi tersambung
  Future<void> notifyKoneksiTersambung() async {
    await showNotification(
      id: 7,
      title: '✅ Koneksi Tersambung',
      body: 'Terhubung ke sistem pengering ikan',
      payload: 'koneksi_tersambung',
    );
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
