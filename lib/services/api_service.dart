import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Base URL Railway
  static const String baseUrl = 'https://web-production-47eb.up.railway.app';
  
  // Timeout
  static const Duration timeout = Duration(seconds: 10);

  // =====================================================
  // GET LATEST DATA
  // =====================================================
  Future<SensorData?> getLatestData() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/data/latest'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          return SensorData.fromApiJson(jsonData['data']);
        }
      }
      
      print('❌ Failed to get latest data: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting latest data: $e');
      return null;
    }
  }

  // =====================================================
  // GET DATA HISTORY
  // =====================================================
  Future<List<SensorData>> getDataHistory({int limit = 50}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/data/history?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> dataList = jsonData['data'];
          return dataList
              .map((item) => SensorData.fromApiJson(item))
              .toList();
        }
      }
      
      print('❌ Failed to get data history: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error getting data history: $e');
      return [];
    }
  }

  // =====================================================
  // GET STATUS HISTORY
  // =====================================================
  Future<List<Map<String, dynamic>>> getStatusHistory({int limit = 50}) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/status/history?limit=$limit'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        }
      }
      
      print('❌ Failed to get status history: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error getting status history: $e');
      return [];
    }
  }

  // =====================================================
  // GET STATISTICS
  // =====================================================
  Future<Map<String, dynamic>?> getStatistics() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/stats'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['stats'] != null) {
          return jsonData['stats'];
        }
      }
      
      print('❌ Failed to get statistics: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting statistics: $e');
      return null;
    }
  }

  // =====================================================
  // SEND CONTROL COMMAND
  // =====================================================
  Future<bool> sendCommand(String command) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/control'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'command': command}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          print('✅ Command sent: $command');
          return true;
        }
      }
      
      print('❌ Failed to send command: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error sending command: $e');
      return false;
    }
  }

  // =====================================================
  // CONTROL COMMANDS
  // =====================================================
  
  // System commands
  Future<bool> startPengeringan() => sendCommand('START');
  Future<bool> resetPengeringan() => sendCommand('RESET');
  
  // Heater commands
  Future<bool> heaterOn() => sendCommand('HEATER_ON');
  Future<bool> heaterOff() => sendCommand('HEATER_OFF');
  
  // Fan commands
  Future<bool> fanOn() => sendCommand('FAN_ON');
  Future<bool> fanOff() => sendCommand('FAN_OFF');
  
  // Lamp commands
  Future<bool> lampOn() => sendCommand('LAMP_ON');
  Future<bool> lampOff() => sendCommand('LAMP_OFF');
  
  // Exhaust commands
  Future<bool> exhaustOn() => sendCommand('EXHAUST_ON');
  Future<bool> exhaustOff() => sendCommand('EXHAUST_OFF');

  // =====================================================
  // CLEAR HISTORY
  // =====================================================
  Future<bool> clearHistory() async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/history/clear'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          print('✅ History cleared');
          return true;
        }
      }
      
      print('❌ Failed to clear history: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error clearing history: $e');
      return false;
    }
  }

  // =====================================================
  // TEST CONNECTION
  // =====================================================
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'OK') {
          print('✅ API connection successful');
          return true;
        }
      }
      
      print('❌ API connection failed: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error testing API connection: $e');
      return false;
    }
  }
}
