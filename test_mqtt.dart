// Test MQTT Connection
// Run: dart test_mqtt.dart

import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() async {
  print('🧪 Testing MQTT Connection...\n');

  final brokers = [
    {'host': 'broker.hivemq.com', 'port': 1883},
    {'host': 'test.mosquitto.org', 'port': 1883},
    {'host': 'broker.emqx.io', 'port': 1883},
  ];

  for (var i = 0; i < brokers.length; i++) {
    final broker = brokers[i];
    final host = broker['host'] as String;
    final port = broker['port'] as int;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Testing Broker ${i + 1}/${brokers.length}');
    print('Host: $host');
    print('Port: $port');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final clientId = 'test_client_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(host, clientId, port);

    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 5000;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      print('🔌 Connecting...');
      await client.connect();

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        print('✅ SUCCESS! Connected to $host:$port\n');
        
        // Test subscribe
        print('📡 Testing subscribe to topics...');
        client.subscribe('novil/pengering/data', MqttQos.atLeastOnce);
        client.subscribe('novil/pengering/status', MqttQos.atLeastOnce);
        print('✅ Subscribed successfully\n');

        // Test publish
        print('📤 Testing publish...');
        final builder = MqttClientPayloadBuilder();
        final testData = {
          'suhu': 25.5,
          'berat': 350,
          'target': 280,
          'relay1': 'ON',
          'relay2': 'ON',
          'relay3': 'OFF',
          'relay4': 'OFF',
          'status': 'TEST'
        };
        builder.addString(jsonEncode(testData));
        client.publishMessage(
          'novil/pengering/data',
          MqttQos.atLeastOnce,
          builder.payload!,
        );
        print('✅ Published test data\n');

        // Listen for messages
        print('👂 Listening for messages (5 seconds)...');
        var messageReceived = false;
        
        client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
          final recMess = messages[0].payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          final topic = messages[0].topic;
          
          print('📨 Received message:');
          print('   Topic: $topic');
          print('   Payload: $payload');
          messageReceived = true;
        });

        await Future.delayed(const Duration(seconds: 5));
        
        if (messageReceived) {
          print('✅ Message received successfully\n');
        } else {
          print('⚠️  No messages received (this is normal if ESP32 is not running)\n');
        }

        client.disconnect();
        print('🔌 Disconnected\n');
        
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('✅ BROKER $host:$port IS WORKING!');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        // Jika broker pertama berhasil, tidak perlu test yang lain
        if (i == 0) {
          print('✅ Primary broker working. No need to test fallback brokers.\n');
          break;
        }
      } else {
        print('❌ FAILED: ${client.connectionStatus}\n');
      }
    } catch (e) {
      print('❌ ERROR: $e\n');
    }

    if (i < brokers.length - 1) {
      print('⏳ Waiting 2 seconds before next test...\n');
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🏁 Test Complete!');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}
