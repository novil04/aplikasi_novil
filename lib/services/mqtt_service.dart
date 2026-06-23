import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // Singleton pattern
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // MQTT Client
  late MqttServerClient client;

  // MQTT Configuration - Multiple brokers untuk fallback
  // Menggunakan WebSocket untuk bypass firewall
  final List<Map<String, dynamic>> brokers = [
    {'host': 'broker.hivemq.com', 'port': 1883, 'useWs': false},
    {'host': 'broker.emqx.io', 'port': 1883, 'useWs': false},
    {'host': 'test.mosquitto.org', 'port': 1883, 'useWs': false},
  ];
  
  int currentBrokerIndex = 0;
  String get broker => brokers[currentBrokerIndex]['host'];
  int get port => brokers[currentBrokerIndex]['port'];
  bool get useWebSocket => brokers[currentBrokerIndex]['useWs'] ?? false;
  
  final String clientId = 'flutter_pengering_ikan_${DateTime.now().millisecondsSinceEpoch}';

  // Topics
  final String topicData = 'novil/pengering/data';
  final String topicStatus = 'novil/pengering/status';
  final String topicControl = 'novil/pengering/control';

  // Stream Controllers untuk data
  final StreamController<Map<String, dynamic>> _dataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<MqttConnectionState> _connectionController =
      StreamController<MqttConnectionState>.broadcast();

  // Getters untuk streams
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<MqttConnectionState> get connectionStream => _connectionController.stream;

  // Connection status
  bool get isConnected => client.connectionStatus?.state == MqttConnectionState.connected;

  // Data terakhir
  Map<String, dynamic>? lastData;
  String? lastStatus;

  // Connect dengan retry ke multiple brokers
  Future<bool> connectWithRetry() async {
    for (int i = 0; i < brokers.length; i++) {
      currentBrokerIndex = i;
      print('🔄 Trying broker ${i + 1}/${brokers.length}: $broker:$port');
      
      final connected = await connect();
      if (connected) {
        print('✅ Successfully connected to $broker:$port');
        return true;
      }
      
      print('❌ Failed to connect to $broker:$port');
      
      // Wait sebelum mencoba broker berikutnya
      if (i < brokers.length - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    print('❌ All brokers failed');
    return false;
  }

  // Connect ke MQTT Broker
  Future<bool> connect() async {
    try {
      client = MqttServerClient.withPort(broker, clientId, port);
      client.logging(on: true); // Enable logging untuk debugging
      client.keepAlivePeriod = 20;
      client.autoReconnect = true;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;
      client.onSubscribed = _onSubscribed;
      client.onAutoReconnect = _onAutoReconnect;
      client.onAutoReconnected = _onAutoReconnected;

      // Set connection timeout
      client.connectTimeoutPeriod = 5000; // 5 detik

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      client.connectionMessage = connMessage;

      print('🔌 Connecting to MQTT broker: $broker:$port');
      print('🆔 Client ID: $clientId');
      
      await client.connect();

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        print('✅ Connected to MQTT broker');
        
        // Subscribe ke topics
        _subscribeToTopics();
        
        // Listen untuk messages
        client.updates?.listen(_onMessage);
        
        _connectionController.add(MqttConnectionState.connected);
        return true;
      } else {
        print('❌ Connection failed - status: ${client.connectionStatus}');
        print('❌ Return code: ${client.connectionStatus?.returnCode}');
        client.disconnect();
        _connectionController.add(MqttConnectionState.disconnected);
        return false;
      }
    } catch (e) {
      print('❌ Connection exception: $e');
      try {
        client.disconnect();
      } catch (_) {}
      _connectionController.add(MqttConnectionState.disconnected);
      return false;
    }
  }

  // Subscribe ke semua topics
  void _subscribeToTopics() {
    client.subscribe(topicData, MqttQos.atLeastOnce);
    client.subscribe(topicStatus, MqttQos.atLeastOnce);
    print('📡 Subscribed to topics: $topicData, $topicStatus');
  }

  // Callback saat connected
  void _onConnected() {
    print('✅ MQTT Connected');
    _connectionController.add(MqttConnectionState.connected);
  }

  // Callback saat disconnected
  void _onDisconnected() {
    print('❌ MQTT Disconnected');
    _connectionController.add(MqttConnectionState.disconnected);
  }

  // Callback saat subscribed
  void _onSubscribed(String topic) {
    print('📡 Subscribed to: $topic');
  }

  // Callback saat auto reconnect
  void _onAutoReconnect() {
    print('🔄 Auto reconnecting...');
    _connectionController.add(MqttConnectionState.connecting);
  }

  // Callback saat auto reconnected
  void _onAutoReconnected() {
    print('✅ Auto reconnected');
    _subscribeToTopics();
    _connectionController.add(MqttConnectionState.connected);
  }

  // Handle incoming messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    final recMess = messages[0].payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final topic = messages[0].topic;

    print('📨 Message from $topic: $payload');

    if (topic == topicData) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        lastData = data;
        _dataController.add(data);
      } catch (e) {
        print('❌ Error parsing data: $e');
      }
    } else if (topic == topicStatus) {
      lastStatus = payload;
      _statusController.add(payload);
    }
  }

  // Publish control command (tidak digunakan dalam mode monitoring)
  // Fungsi ini tetap ada untuk kompatibilitas, tapi tidak dipanggil dari UI
  void publishControl(String command) {
    if (!isConnected) {
      print('❌ Not connected to MQTT broker');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(command);
    
    client.publishMessage(
      topicControl,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    print('📤 Published to $topicControl: $command');
  }

  // Disconnect
  void disconnect() {
    client.disconnect();
    print('🔌 Disconnected from MQTT broker');
  }

  // Dispose
  void dispose() {
    _dataController.close();
    _statusController.close();
    _connectionController.close();
    disconnect();
  }
}
