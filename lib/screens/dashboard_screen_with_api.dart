// CONTOH IMPLEMENTASI DASHBOARD DENGAN API SERVICE
// File ini adalah contoh, copy kode yang diperlukan ke dashboard_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_manager.dart';
import '../models/sensor_data.dart';

class DashboardScreenWithApi extends StatefulWidget {
  const DashboardScreenWithApi({super.key});

  @override
  State<DashboardScreenWithApi> createState() => _DashboardScreenWithApiState();
}

class _DashboardScreenWithApiState extends State<DashboardScreenWithApi> {
  final ApiService _apiService = ApiService();
  final NotificationManager _notificationManager = NotificationManager();
  
  // Data dari sensor
  double suhu = 0.0;
  double berat = 0.0;
  double target = 0.0;
  
  // Status relay
  bool heater = false;
  bool fanIn = false;
  bool exhaust = false;

  // Status sistem
  String statusSistem = 'DISCONNECTED';
  bool isApiConnected = false;
  String lastStatusMessage = 'Menghubungkan...';
  
  // Track previous status untuk notifikasi
  String _previousStatus = '';
  
  // Timer untuk auto-update
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initializeConnections();
    _startPolling();
  }
  
  // Initialize notifications
  Future<void> _initializeNotifications() async {
    await _notificationManager.initialize();
  }
  
  // Auto-update data setiap 5 detik
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && isApiConnected) {
        _loadLatestData();
      }
    });
  }

  Future<void> _initializeConnections() async {
    // Test API connection
    final apiConnected = await _apiService.testConnection();
    setState(() {
      isApiConnected = apiConnected;
      // Set status langsung ke READY jika API connected
      if (apiConnected) {
        statusSistem = 'READY';
        lastStatusMessage = 'Terhubung ke server';
      } else {
        statusSistem = 'DISCONNECTED';
        lastStatusMessage = 'Gagal terhubung ke server';
      }
    });

    if (apiConnected) {
      print('✅ API connected');
      
      // Load initial data from API
      await _loadLatestData();
    }
    
    // MQTT dihapus - hanya pakai API polling
  }

  Future<void> _loadLatestData() async {
    try {
      final data = await _apiService.getLatestData();
      if (data != null && mounted) {
        setState(() {
          suhu = data.suhu;
          berat = data.berat;
          target = data.target;
          heater = data.relay1;
          fanIn = data.relay2;
          exhaust = data.relay4;
          
          // Update status dan trigger notifikasi
          String newStatus = data.status;
          
          // Notifikasi berdasarkan perubahan status
          if (newStatus != _previousStatus) {
            if (newStatus == 'READY' && _previousStatus != 'READY') {
              _notificationManager.notifyPengeringanDimulai();
            } else if (newStatus == 'BERJALAN' && _previousStatus != 'BERJALAN') {
              _notificationManager.notifyIkanTerdeteksi(berat);
            } else if (newStatus == 'SELESAI' && _previousStatus != 'SELESAI') {
              _notificationManager.notifyPengeringanSelesai(berat);
            }
            
            _previousStatus = newStatus;
          }
          
          statusSistem = newStatus;
        });
      } else if (mounted) {
        // Data null, tampilkan error
        _showErrorSnackBar('Gagal memuat data dari server');
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  // =====================================================
  // UI HELPERS
  // =====================================================

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    // Jangan disconnect MQTT karena singleton
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Pengering Ikan'),
        actions: [
          // API status only
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              isApiConnected ? Icons.cloud_done : Icons.cloud_off,
              color: isApiConnected ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLatestData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(),
              const SizedBox(height: 16),
              
              // Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.thermostat,
                      iconColor: Colors.orange,
                      label: 'Suhu',
                      value: suhu.toStringAsFixed(1),
                      unit: '°C',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.scale,
                      iconColor: Colors.blue,
                      label: 'Berat',
                      value: berat.toStringAsFixed(0),
                      unit: 'g',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Target
              _buildMetricCard(
                icon: Icons.flag,
                iconColor: Colors.green,
                label: 'Target Berat',
                value: target.toStringAsFixed(0),
                unit: 'g',
              ),
              const SizedBox(height: 16),
              
              // Devices
              const Text(
                'Perangkat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
                children: [
                  _buildDeviceCard(
                    icon: Icons.whatshot,
                    iconColor: Colors.deepOrange,
                    label: 'Heater',
                    status: heater,
                  ),
                  _buildDeviceCard(
                    icon: Icons.air,
                    iconColor: Colors.blue,
                    label: 'Fan',
                    status: fanIn,
                  ),
                  _buildDeviceCard(
                    icon: Icons.wind_power,
                    iconColor: Colors.teal,
                    label: 'Exhaust',
                    status: exhaust,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    
    switch (statusSistem) {
      case 'SELESAI':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'BERJALAN':
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle;
        break;
      case 'READY':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'SCANNING':
        statusColor = Colors.purple;
        statusIcon = Icons.search;
        break;
      case 'CONNECTED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'DISCONNECTED':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      case 'CONNECTING':
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Sistem',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusSistem,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lastStatusMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool status,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status ? iconColor.withOpacity(0.1) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: status ? iconColor : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: status ? iconColor.withOpacity(0.15) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: status ? iconColor : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
