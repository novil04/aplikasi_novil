class SensorData {
  final double suhu;
  final double berat;
  final double target;
  final bool relay1; // Heater
  final bool relay2; // Fan In
  final bool relay3; // Lamp
  final bool relay4; // Exhaust
  final String status;
  final String? timestamp;

  SensorData({
    required this.suhu,
    required this.berat,
    required this.target,
    required this.relay1,
    required this.relay2,
    required this.relay3,
    required this.relay4,
    required this.status,
    this.timestamp,
  });

  // Parse dari JSON MQTT (ESP32 → Flutter via MQTT)
  // Format: {"suhu":28.5,"berat":450,"target":315,"relay1":true,"relay2":true,"relay3":true,"relay4":false}
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      suhu: (json['suhu'] ?? 0).toDouble(),
      berat: (json['berat'] ?? 0).toDouble(),
      target: (json['target'] ?? 0).toDouble(),
      relay1: json['relay1'] == true || json['relay1'] == 1,
      relay2: json['relay2'] == true || json['relay2'] == 1,
      relay3: json['relay3'] == true || json['relay3'] == 1,
      relay4: json['relay4'] == true || json['relay4'] == 1,
      status: json['status'] ?? 'UNKNOWN',
      timestamp: json['timestamp'],
    );
  }

  // Parse dari JSON API (Backend → Flutter)
  // Format: {"suhu":28.5,"berat":450,"target":315,"relay1":true,"relay2":true,...,"status":"RUNNING","timestamp":"2026-05-28T10:30:00.000Z"}
  factory SensorData.fromApiJson(Map<String, dynamic> json) {
    return SensorData(
      suhu: (json['suhu'] ?? 0).toDouble(),
      berat: (json['berat'] ?? 0).toDouble(),
      target: (json['target'] ?? 0).toDouble(),
      relay1: json['relay1'] == true || json['relay1'] == 1,
      relay2: json['relay2'] == true || json['relay2'] == 1,
      relay3: json['relay3'] == true || json['relay3'] == 1,
      relay4: json['relay4'] == true || json['relay4'] == 1,
      status: _mapStatus(json['status'] ?? 'UNKNOWN'),
      timestamp: json['timestamp'],
    );
  }

  // Map status dari backend ke format Flutter
  static String _mapStatus(String backendStatus) {
    switch (backendStatus.toUpperCase()) {
      case 'CONNECTED':
        return 'CONNECTED';
      case 'READY':
        return 'READY';
      case 'RUNNING':
        return 'BERJALAN';
      case 'SCANNING':
        return 'SCANNING';
      case 'COMPLETED':
        return 'SELESAI';
      case 'ERROR':
        return 'ERROR';
      default:
        return backendStatus;
    }
  }

  // Convert ke JSON
  Map<String, dynamic> toJson() {
    return {
      'suhu': suhu,
      'berat': berat,
      'target': target,
      'relay1': relay1,
      'relay2': relay2,
      'relay3': relay3,
      'relay4': relay4,
      'status': status,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'SensorData(suhu: $suhu°C, berat: ${berat}g, target: ${target}g, status: $status)';
  }
}

