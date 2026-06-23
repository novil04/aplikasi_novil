import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/mqtt_service.dart';
import '../models/sensor_data.dart';
import '../services/notification_manager.dart';
import 'notification_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final MqttService _mqttService = MqttService();
  final NotificationManager _notificationManager = NotificationManager();
  
  // Data dari sensor
  double suhu = 35.2;
  double berat = 420.0;
  double target = 280.0;
  
  // Data historis untuk grafik
  List<FlSpot> suhuHistory = [];
  List<FlSpot> beratHistory = [];
  double chartTimeCounter = 0;

  // Status relay
  bool heater = false;
  bool fanIn = false;
  bool lamp = false;
  bool exhaust = false;

  // Status sistem
  String statusSistem = 'DISCONNECTED';
  bool isConnected = false;
  String lastStatusMessage = 'Tekan tombol untuk memulai pengeringan';
  
  // Waktu mulai dan durasi
  DateTime? waktuMulai;
  Duration durasi = Duration.zero;

  // Current navigation index
  int _currentIndex = 0;

  // Status pengeringan
  bool modePengeringan = false;
  bool pengeringanSelesai = false;
  bool beratTersimpan = false;
  
  // Track previous status untuk notifikasi
  String _previousStatus = '';
  bool _previousBeratTersimpan = false;

  @override
  void initState() {
    super.initState();
    waktuMulai = DateTime.now(); // Inisialisasi waktu mulai
    _initializeChartData();
    _initializeNotifications();
    _connectMQTT();
    _startDurationTimer();
  }

  void _initializeNotifications() async {
    await _notificationManager.initialize();
  }

  void _initializeChartData() {
    // Initialize dengan data dummy untuk demo
    for (int i = 0; i < 10; i++) {
      suhuHistory.add(FlSpot(i.toDouble(), 35.0 + (i % 3) * 0.5));
      beratHistory.add(FlSpot(i.toDouble(), 450.0 - i * 3.0));
    }
    chartTimeCounter = 10;
  }

  void _startDurationTimer() {
    if (!mounted) return;
    
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      // Update durasi jika ada waktu mulai
      if (waktuMulai != null) {
        if (mounted) {
          setState(() {
            durasi = DateTime.now().difference(waktuMulai!);
          });
        }
      }
      
      // Lanjutkan timer
      _startDurationTimer();
    });
  }

  // Connect ke MQTT broker
  Future<void> _connectMQTT() async {
    if (!mounted) return;
    
    setState(() {
      statusSistem = 'CONNECTING';
    });

    try {
      // Tambahkan timeout untuk mencegah stuck
      final connected = await _mqttService.connectWithRetry()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ MQTT connection timeout');
              return false;
            },
          );
      
      if (!mounted) return;
      
      if (connected) {
        setState(() {
          isConnected = true;
          // Jangan set status BERJALAN otomatis, tunggu data dari ESP32
          if (statusSistem == 'DISCONNECTED' || statusSistem == 'CONNECTING') {
            statusSistem = 'READY';
            lastStatusMessage = 'Tekan tombol untuk memulai pengeringan';
          }
        });

        // Listen untuk data dari ESP32
        _mqttService.dataStream.listen((data) {
        if (mounted) {
          setState(() {
            try {
              final sensorData = SensorData.fromJson(data);
              suhu = sensorData.suhu;
              berat = sensorData.berat;
              target = sensorData.target;
              heater = sensorData.relay1;
              fanIn = sensorData.relay2;
              lamp = sensorData.relay3;
              exhaust = sensorData.relay4;
              
              // Update status sistem berdasarkan data dari ESP32
              String newStatus = sensorData.status;
              
              if (newStatus == 'START') {
                statusSistem = 'READY';
                modePengeringan = true;
                pengeringanSelesai = false;
                beratTersimpan = false;
                lastStatusMessage = 'Menunggu deteksi ikan...';
                if (waktuMulai == null) {
                  waktuMulai = DateTime.now();
                }
                
                // Notifikasi pengeringan dimulai
                if (_previousStatus != 'START') {
                  _notificationManager.notifyPengeringanDimulai();
                }
              } else if (newStatus == 'BERJALAN') {
                statusSistem = 'BERJALAN';
                modePengeringan = true;
                pengeringanSelesai = false;
                if (!beratTersimpan && target > 0) {
                  beratTersimpan = true;
                  lastStatusMessage = 'Proses pengeringan sedang berlangsung';
                  
                  // Notifikasi ikan terdeteksi (hanya sekali)
                  if (!_previousBeratTersimpan) {
                    _notificationManager.notifyIkanTerdeteksi(berat);
                  }
                } else if (!beratTersimpan) {
                  lastStatusMessage = 'Menunggu deteksi ikan...';
                } else {
                  lastStatusMessage = 'Proses pengeringan sedang berlangsung';
                }
              } else if (newStatus == 'SELESAI') {
                statusSistem = 'SELESAI';
                pengeringanSelesai = true;
                lastStatusMessage = 'Pengeringan selesai, tekan tombol untuk reset';
                
                // Notifikasi pengeringan selesai
                if (_previousStatus != 'SELESAI') {
                  _notificationManager.notifyPengeringanSelesai(berat);
                }
              } else {
                statusSistem = newStatus;
              }
              
              // Update previous status
              _previousStatus = newStatus;
              _previousBeratTersimpan = beratTersimpan;
              
              // Update chart data
              if (suhuHistory.length > 20) {
                suhuHistory.removeAt(0);
                beratHistory.removeAt(0);
                // Reindex
                for (int i = 0; i < suhuHistory.length; i++) {
                  suhuHistory[i] = FlSpot(i.toDouble(), suhuHistory[i].y);
                  beratHistory[i] = FlSpot(i.toDouble(), beratHistory[i].y);
                }
                chartTimeCounter = suhuHistory.length.toDouble();
              }
              suhuHistory.add(FlSpot(chartTimeCounter, suhu));
              beratHistory.add(FlSpot(chartTimeCounter, berat));
              chartTimeCounter++;
              
              print('📊 Data updated: $sensorData');
            } catch (e) {
              print('❌ Error parsing sensor data: $e');
            }
          });
        }
      });

      // Listen untuk status messages
      _mqttService.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            lastStatusMessage = status;
          });
        }
      });

      // Listen untuk connection status
      _mqttService.connectionStream.listen((state) {
        if (mounted) {
          setState(() {
            isConnected = state == MqttConnectionState.connected;
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          isConnected = false;
          statusSistem = 'DISCONNECTED';
          lastStatusMessage = 'Gagal terhubung ke server';
        });
      }
    }
    } catch (e) {
      print('❌ Error in _connectMQTT: $e');
      if (mounted) {
        setState(() {
          isConnected = false;
          statusSistem = 'DISCONNECTED';
          lastStatusMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  Widget _buildStatusCard() {
    // Tentukan warna dan icon berdasarkan status
    Color statusColor;
    IconData statusIcon;
    
    if (statusSistem == 'SELESAI') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (statusSistem == 'BERJALAN') {
      statusColor = Colors.blue;
      statusIcon = Icons.play_circle;
    } else if (statusSistem == 'READY') {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.info;
    }
    
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
        children: [
          Row(
            children: [
              // Icon status
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              // Status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Pengeringan',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSistem,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            lastStatusMessage,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Waktu dan durasi dalam row terpisah
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Waktu Mulai',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        waktuMulai != null 
                            ? DateFormat('HH:mm:ss').format(waktuMulai!)
                            : '--:--:--',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Durasi',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.timer, size: 13, color: statusColor),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _formatDuration(durasi),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    required String status,
    required List<FlSpot> chartData,
    required Color chartColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    // Hitung progress: dari berat awal ke target
    // Progress = (berat awal - berat sekarang) / (berat awal - target) * 100
    // Asumsi: berat awal = berat sekarang + (berat sekarang - target) jika berat > target
    double progress = 0;
    if (target > 0 && berat > target) {
      // Berat masih di atas target, hitung progress
      double beratAwal = berat + (berat - target); // estimasi berat awal
      progress = ((beratAwal - berat) / (beratAwal - target) * 100).clamp(0, 100);
    } else if (target > 0 && berat <= target) {
      // Sudah mencapai atau melewati target
      progress = 100;
    }
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Progres',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 75,
              height: 75,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 75,
                    height: 75,
                    child: CircularProgressIndicator(
                      value: progress / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  Text(
                    '${progress.toInt()}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Menuju Target',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    double sisaBerat = berat - target;
    if (sisaBerat < 0) sisaBerat = 0;
    
    // Hitung progress: semakin mendekati target, semakin tinggi progress
    double progressValue = 0;
    if (target > 0 && berat > target) {
      // Asumsi berat awal adalah 2x target atau berat saat ini + sisa
      double beratAwal = berat + sisaBerat;
      progressValue = ((beratAwal - berat) / (beratAwal - target)).clamp(0.0, 1.0);
    } else if (target > 0 && berat <= target) {
      progressValue = 1.0; // Sudah mencapai target
    }
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.water_drop, color: Colors.blue, size: 16),
              ),
              const SizedBox(width: 6),
              const Text(
                'Progress Pengeringan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sisa ${sisaBerat.toInt()} gram menuju target',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${berat.toInt()} g',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(Icons.flag, size: 8, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Text(
                      'Berat Saat Ini',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${target.toInt()} g',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      'Target Berat',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                      ),
                    ),
                  ],
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
    required String description,
    required bool status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: 18),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'info',
                    child: Text('Info'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: status ? iconColor.withOpacity(0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: status ? iconColor : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Toggle switch
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: status,
              onChanged: null, // Disabled karena mode monitoring
              activeColor: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedHeaterFanCard() {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'PTC Heater & Fan In',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: 16),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'info',
                    child: Text('Info'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // PTC Heater
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.whatshot, color: Colors.deepOrange, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PTC Heater',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Pemanas',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: heater ? Colors.deepOrange.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  heater ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: heater ? Colors.deepOrange : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Divider
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 10),
          
          // Fan In
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.air, color: Colors.blue, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fan In',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Kipas Masuk',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: fanIn ? Colors.blue.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  fanIn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: fanIn ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExhaustCard() {
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Exhaust Fan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, size: 16),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'info',
                    child: Text('Info'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Exhaust
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.wind_power, color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exhaust',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Kipas Keluar',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: exhaust ? Colors.teal.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  exhaust ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: exhaust ? Colors.teal : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildRealtimeChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.show_chart, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Grafik Real-time',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Suhu Chart
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Grafik Suhu (°C)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        int minutes = (value.toInt() * 6) % 60;
                        int hours = 10 + ((value.toInt() * 6) ~/ 60);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 20,
                maxY: 45,
                lineBarsData: [
                  LineChartBarData(
                    spots: suhuHistory,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        if (index == suhuHistory.length - 1) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: Colors.white,
                            strokeWidth: 2.5,
                            strokeColor: Colors.red,
                          );
                        }
                        return FlDotCirclePainter(
                          radius: 0,
                          color: Colors.transparent,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)}°C',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Berat Chart
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Grafik Berat (gram)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 100,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        int minutes = (value.toInt() * 6) % 60;
                        int hours = 10 + ((value.toInt() * 6) ~/ 60);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 600,
                lineBarsData: [
                  LineChartBarData(
                    spots: beratHistory,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        if (index == beratHistory.length - 1) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: Colors.white,
                            strokeWidth: 2.5,
                            strokeColor: Colors.blue,
                          );
                        }
                        return FlDotCirclePainter(
                          radius: 0,
                          color: Colors.transparent,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(0)}g',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // List of screens
    final List<Widget> screens = [
      _buildDashboardContent(),
      const NotificationScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _currentIndex == 0 ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                DateFormat('HH:mm:ss').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ) : null,
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifikasi',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await _connectMQTT();
        } catch (e) {
          print('❌ Error during refresh: $e');
          // Tetap selesaikan refresh meskipun error
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 12),
            
            // Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.thermostat,
                    iconColor: Colors.red,
                    label: 'Suhu',
                    value: suhu.toStringAsFixed(1),
                    unit: '°C',
                    status: 'Normal',
                    chartData: suhuHistory,
                    chartColor: Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.scale,
                    iconColor: Colors.blue,
                    label: 'Berat Ikan',
                    value: berat.toStringAsFixed(0),
                    unit: 'gram',
                    status: 'Berat Saat Ini',
                    chartData: beratHistory,
                    chartColor: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Target and Progress Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.flag,
                    iconColor: Colors.purple,
                    label: 'Target Berat',
                    value: target.toStringAsFixed(0),
                    unit: 'gram',
                    status: 'Berat Target',
                    chartData: const [],
                    chartColor: Colors.purple,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildProgressCard(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress Bar
            _buildProgressBar(),
            const SizedBox(height: 12),
            
            // Device Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildCombinedHeaterFanCard(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildExhaustCard(),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
