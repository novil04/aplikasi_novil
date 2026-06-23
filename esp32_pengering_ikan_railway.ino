#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <LiquidCrystal_PCF8574.h>
#include <DHT.h>
#include "HX711.h"

// =====================================================
// WIFI
// =====================================================
const char* ssid = "Bemby 1";
const char* password = "BISMILLAH88";

// =====================================================
// MQTT
// =====================================================
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;
WiFiClient espClient;
PubSubClient client(espClient);

// =====================================================
// MQTT TOPIC (Sesuai dengan Backend Railway)
// =====================================================
const char* topicData    = "novil/pengering/data";
const char* topicStatus  = "novil/pengering/status";
const char* topicControl = "novil/pengering/control";
const char* topicButton  = "novil/pengering/button";

// =====================================================
// LCD
// =====================================================
LiquidCrystal_PCF8574 lcd(0x27);

// =====================================================
// BUTTON
// =====================================================
#define BUTTON_PIN 18
bool lastButtonState = HIGH;

// =====================================================
// DHT22
// =====================================================
#define DHTPIN 4
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

// =====================================================
// HX711
// =====================================================
#define DT1 25
#define SCK1 26
#define DT2 32
#define SCK2 33
HX711 scale1;
HX711 scale2;

// =====================================================
// RELAY
// =====================================================
#define RELAY_HEATER1  13  // RELAY1 - Heater 1
#define RELAY_HEATER2  12  // RELAY2 - Heater 2
#define RELAY_FAN      14  // RELAY3 - Fan
#define RELAY_EXHAUST  27  // RELAY4 - Exhaust

// =====================================================
// KALIBRASI
// =====================================================
float calibration_factor1 = 208.0;
float calibration_factor2 = 208.0;

// =====================================================
// VARIABEL
// =====================================================
float berat_awal    = 0;
float berat_trigger = 0;
bool modePengeringan    = false;
bool pengeringanSelesai = false;
bool beratTersimpan     = false;
unsigned long waktuMulaiBerat = 0;

// =====================================================
// FUNCTION
// =====================================================
void tampilReady();
void tampilSelesai();
void kirimStatusRelay(float suhu, float berat);
void kirimDataMQTT(float suhu, float berat);

// =====================================================
// WIFI CONNECT
// =====================================================
void setup_wifi() {
  Serial.println();
  Serial.println("Starting WiFi connection...");
  
  // Tampilkan status connecting di LCD
  lcd.clear();
  delay(50);
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");
  lcd.setCursor(0, 1);
  lcd.print("Please wait...");
  
  Serial.print("Connecting to: ");
  Serial.println(ssid);
  
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("WiFi Connected");
    Serial.print("IP Address : ");
    Serial.println(WiFi.localIP());
    
    // Tampilkan WiFi connected di LCD
    lcd.clear();
    delay(50);
    lcd.setCursor(0, 0);
    lcd.print("WiFi Connected!");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP());
    delay(2000);
  } else {
    Serial.println();
    Serial.println("WiFi Connection Failed!");
    
    // Tampilkan error di LCD
    lcd.clear();
    delay(50);
    lcd.setCursor(0, 0);
    lcd.print("WiFi Failed!");
    lcd.setCursor(0, 1);
    lcd.print("Check settings");
    delay(3000);
  }
}

// =====================================================
// MQTT CALLBACK
// =====================================================
void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.print("MQTT Message [");
  Serial.print(topic);
  Serial.print("] : ");
  Serial.println(message);
  
  if (String(topic) == topicControl) {
    // =================================================
    // HEATER 1
    // =================================================
    if (message == "HEATER_ON") {
      digitalWrite(RELAY_HEATER1, LOW);
      digitalWrite(RELAY_HEATER2, LOW);
      Serial.println("HEATER 1 & 2 ON");
    }
    else if (message == "HEATER_OFF") {
      digitalWrite(RELAY_HEATER1, HIGH);
      digitalWrite(RELAY_HEATER2, HIGH);
      Serial.println("HEATER 1 & 2 OFF");
    }
    // =================================================
    // FAN
    // =================================================
    else if (message == "FAN_ON") {
      digitalWrite(RELAY_FAN, LOW);
      Serial.println("FAN ON");
    }
    else if (message == "FAN_OFF") {
      digitalWrite(RELAY_FAN, HIGH);
      Serial.println("FAN OFF");
    }
    // =================================================
    // LAMP (tidak digunakan, untuk kompatibilitas)
    // =================================================
    else if (message == "LAMP_ON") {
      Serial.println("LAMP ON (tidak tersedia)");
    }
    else if (message == "LAMP_OFF") {
      Serial.println("LAMP OFF (tidak tersedia)");
    }
    // =================================================
    // EXHAUST
    // =================================================
    else if (message == "EXHAUST_ON") {
      digitalWrite(RELAY_EXHAUST, LOW);
      Serial.println("EXHAUST ON");
    }
    else if (message == "EXHAUST_OFF") {
      digitalWrite(RELAY_EXHAUST, HIGH);
      Serial.println("EXHAUST OFF");
    }
    // =================================================
    // START MQTT (dari Flutter via Backend)
    // =================================================
    else if (message == "START") {
      if (modePengeringan || pengeringanSelesai) {
        Serial.println("START DIABAIKAN - Sistem sedang berjalan atau selesai");
        client.publish(topicStatus, "TIDAK BISA START SEKARANG");
        return;
      }
      
      Serial.println("START MQTT (dari aplikasi)");
      
      // Tare HX711 saat mulai pengeringan dengan timeout
      Serial.println("Taring scales...");
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Calibrating...");
      lcd.setCursor(0, 1);
      lcd.print("Please wait");
      
      // Cek apakah scale ready sebelum tare
      bool scale1Ready = scale1.is_ready();
      bool scale2Ready = scale2.is_ready();
      
      Serial.print("Scale 1 ready: ");
      Serial.println(scale1Ready ? "YES" : "NO");
      Serial.print("Scale 2 ready: ");
      Serial.println(scale2Ready ? "YES" : "NO");
      
      if (scale1Ready) {
        scale1.tare();
        delay(100);
        Serial.println("Scale 1 tared");
      } else {
        Serial.println("Scale 1 NOT READY - skipping tare");
      }
      
      if (scale2Ready) {
        scale2.tare();
        delay(100);
        Serial.println("Scale 2 tared");
      } else {
        Serial.println("Scale 2 NOT READY - skipping tare");
      }
      
      Serial.println("Scales tare complete");
      
      modePengeringan    = true;
      pengeringanSelesai = false;
      beratTersimpan     = false;
      berat_awal      = 0;
      berat_trigger   = 0;
      waktuMulaiBerat = 0;
      lcd.clear();
      client.publish(topicStatus, "PENGERINGAN DIMULAI");
    }
    // =================================================
    // RESET MQTT (dari Flutter via Backend)
    // =================================================
    else if (message == "RESET") {
      Serial.println("RESET MQTT (dari aplikasi)");
      modePengeringan    = false;
      pengeringanSelesai = false;
      beratTersimpan     = false;
      berat_awal      = 0;
      berat_trigger   = 0;
      waktuMulaiBerat = 0;
      
      // Matikan semua relay
      digitalWrite(RELAY_HEATER1, HIGH);
      digitalWrite(RELAY_HEATER2, HIGH);
      digitalWrite(RELAY_FAN, HIGH);
      digitalWrite(RELAY_EXHAUST, HIGH);
      
      lcd.clear();
      tampilReady();
      client.publish(topicStatus, "PENGERINGAN SIAP");
    }
  }
}

// =====================================================
// MQTT CONNECT
// =====================================================
void reconnect() {
  int attempts = 0;
  while (!client.connected() && attempts < 3) {
    Serial.println("Connecting MQTT...");
    
    // Tampilkan status di LCD saat connecting MQTT pertama kali
    if (attempts == 0 && modePengeringan == false && pengeringanSelesai == false) {
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Connecting MQTT");
      lcd.setCursor(0, 1);
      lcd.print("Please wait...");
    }
    
    // Generate unique client ID
    String clientId = "ESP32_PENGERING_";
    clientId += String(random(0xffff), HEX);
    
    if (client.connect(clientId.c_str())) {
      Serial.println("MQTT Connected");
      Serial.print("Client ID: ");
      Serial.println(clientId);
      
      // Subscribe ke topic control
      client.subscribe(topicControl);
      Serial.print("Subscribed to: ");
      Serial.println(topicControl);
      
      // Publish status connected
      client.publish(topicStatus, "ESP32 CONNECTED");
      
      // Tampilkan MQTT connected di LCD
      if (modePengeringan == false && pengeringanSelesai == false) {
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("MQTT Connected!");
        lcd.setCursor(0, 1);
        lcd.print("System Ready");
        delay(2000);
      }
    }
    else {
      Serial.print("MQTT Failed : ");
      Serial.println(client.state());
      attempts++;
      delay(2000);
    }
  }
}

// =====================================================
// SETUP
// =====================================================
void setup() {
  Serial.begin(115200);
  delay(1000); // Beri waktu serial monitor untuk ready
  
  Serial.println();
  Serial.println("=================================");
  Serial.println("ESP32 Pengering Ikan - Railway");
  Serial.println("=================================");
  
  // Setup I2C untuk LCD
  Serial.println("Initializing I2C...");
  Wire.begin(21, 22);
  delay(100);
  
  // Setup LCD dengan error handling
  Serial.println("Initializing LCD...");
  lcd.begin(16, 2);
  delay(100);
  
  lcd.setBacklight(255);
  delay(100);
  
  lcd.clear();
  delay(100);
  
  // Test LCD - tampilkan pesan booting
  lcd.setCursor(0, 0);
  lcd.print("ESP32 Pengering");
  lcd.setCursor(0, 1);
  lcd.print("Initializing...");
  delay(2000);
  
  Serial.println("LCD initialized successfully");
  
  // Setup WiFi
  setup_wifi();
  
  // Setup MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  client.setKeepAlive(60);
  
  // Setup Button
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  // Setup DHT22
  Serial.println("Initializing DHT22...");
  dht.begin();
  delay(100);
  
  // Setup HX711 - SKIP TARE untuk cepat boot
  Serial.println("Initializing HX711...");
  scale1.begin(DT1, SCK1);
  scale2.begin(DT2, SCK2);
  delay(100);
  
  scale1.set_scale(calibration_factor1);
  scale2.set_scale(calibration_factor2);
  delay(100);
  
  // SKIP tare - akan dilakukan saat mulai pengeringan
  // scale1.tare();
  // scale2.tare();
  
  Serial.println("HX711 initialized (tare skipped)");
  
  // Setup Relay (Active LOW)
  pinMode(RELAY_HEATER1, OUTPUT);
  pinMode(RELAY_HEATER2, OUTPUT);
  pinMode(RELAY_FAN, OUTPUT);
  pinMode(RELAY_EXHAUST, OUTPUT);
  
  // Matikan semua relay
  digitalWrite(RELAY_HEATER1, HIGH);
  digitalWrite(RELAY_HEATER2, HIGH);
  digitalWrite(RELAY_FAN, HIGH);
  digitalWrite(RELAY_EXHAUST, HIGH);
  
  // Tampilkan ready
  lcd.clear();
  delay(100);
  tampilReady();
  delay(500);
  
  Serial.println("Setup Complete!");
  Serial.println("=================================");
}

// =====================================================
// LOOP
// =====================================================
void loop() {
  // =====================================================
  // MQTT Connection Check
  // =====================================================
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
  
  // =====================================================
  // BUTTON
  // =====================================================
  bool buttonState = digitalRead(BUTTON_PIN);
  if (lastButtonState == HIGH && buttonState == LOW) {
    Serial.println("BUTTON PRESSED");
    client.publish(topicButton, "BUTTON PRESSED");
    
    // =================================================
    // STATE: READY TO DRY
    // Tekan button → mulai pengeringan
    // =================================================
    if (!modePengeringan && !pengeringanSelesai) {
      Serial.println("START PENGERINGAN");
      
      // Tare HX711 saat mulai pengeringan dengan timeout
      Serial.println("Taring scales...");
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Calibrating...");
      lcd.setCursor(0, 1);
      lcd.print("Please wait");
      
      // Cek apakah scale ready sebelum tare
      bool scale1Ready = scale1.is_ready();
      bool scale2Ready = scale2.is_ready();
      
      Serial.print("Scale 1 ready: ");
      Serial.println(scale1Ready ? "YES" : "NO");
      Serial.print("Scale 2 ready: ");
      Serial.println(scale2Ready ? "YES" : "NO");
      
      if (scale1Ready) {
        scale1.tare();
        delay(100);
        Serial.println("Scale 1 tared");
      } else {
        Serial.println("Scale 1 NOT READY - skipping tare");
      }
      
      if (scale2Ready) {
        scale2.tare();
        delay(100);
        Serial.println("Scale 2 tared");
      } else {
        Serial.println("Scale 2 NOT READY - skipping tare");
      }
      
      Serial.println("Scales tare complete");
      
      // Publish ke topicButton dan topicControl
      client.publish(topicButton, "START_BUTTON");
      client.publish(topicControl, "START");
      
      modePengeringan    = true;
      pengeringanSelesai = false;
      beratTersimpan     = false;
      berat_awal      = 0;
      berat_trigger   = 0;
      waktuMulaiBerat = 0;
      
      lcd.clear();
      client.publish(topicStatus, "PENGERINGAN DIMULAI");
    }
    
    delay(300);
  }
  lastButtonState = buttonState;
  
  // =====================================================
  // MODE READY — belum ada button press
  // =====================================================
  if (!modePengeringan) {
    tampilReady();
    delay(500);
    return;
  }
  
  // =====================================================
  // MODE PENGERINGAN
  // =====================================================
  
  // =====================================================
  // DHT22
  // =====================================================
  float suhu = dht.readTemperature();
  if (isnan(suhu)) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("DHT ERROR");
    Serial.println("DHT ERROR");
    client.publish(topicStatus, "DHT ERROR");
    delay(1000);
    return;
  }
  
  // =====================================================
  // HX711
  // =====================================================
  float berat1 = 0;
  float berat2 = 0;
  
  // Cek scale ready dengan timeout untuk menghindari hang
  if (scale1.wait_ready_timeout(200)) {
    if (scale1.is_ready()) {
      berat1 = scale1.get_units(5);
    }
  } else {
    Serial.println("Scale 1 timeout");
  }
  
  if (scale2.wait_ready_timeout(200)) {
    if (scale2.is_ready()) {
      berat2 = scale2.get_units(5);
    }
  } else {
    Serial.println("Scale 2 timeout");
  }
  
  // =====================================================
  // ANTI NOISE
  // =====================================================
  if (abs(berat1) < 0.5) berat1 = 0;
  if (abs(berat2) < 0.5) berat2 = 0;
  
  // =====================================================
  // TOTAL BERAT (Jumlah dari kedua load cell)
  // =====================================================
  float berat = berat1 + berat2;
  
  // =====================================================
  // DETEKSI IKAN
  // =====================================================
  if (!beratTersimpan && berat > 50 && waktuMulaiBerat == 0) {
    waktuMulaiBerat = millis();
    Serial.println("IKAN TERDETEKSI");
    client.publish(topicStatus, "SCAN BERAT...");
  }
  
  // =====================================================
  // SIMPAN BERAT AWAL
  // =====================================================
  if (!beratTersimpan && 
      waktuMulaiBerat > 0 && 
      millis() - waktuMulaiBerat >= 5000) {
    
    berat_awal = berat;
    float berat_daging   = berat_awal * 0.3;
    float berat_air_awal = berat_awal * 0.7;
    float sisa_air       = berat_air_awal * 0.4;
    berat_trigger = berat_daging + sisa_air;
    beratTersimpan = true;
    
    Serial.println("BERAT AWAL TERSIMPAN");
    Serial.print("Berat Awal : ");
    Serial.println(berat_awal);
    Serial.print("Target     : ");
    Serial.println(berat_trigger);
    
    String msg = "PENGERINGAN BERJALAN - Awal:";
    msg += String(berat_awal, 0);
    msg += "g Target:";
    msg += String(berat_trigger, 0);
    msg += "g";
    client.publish(topicStatus, msg.c_str());
  }
  
  // =====================================================
  // TARGET TERCAPAI → SELESAI
  // =====================================================
  if (beratTersimpan && berat <= berat_trigger) {
    modePengeringan    = false;
    pengeringanSelesai = true;
    
    // Matikan heater 1, 2 dan fan, nyalakan exhaust untuk cooling
    digitalWrite(RELAY_HEATER1, HIGH);
    digitalWrite(RELAY_HEATER2, HIGH);
    digitalWrite(RELAY_FAN, HIGH);
    digitalWrite(RELAY_EXHAUST, LOW);  // EXHAUST ON
    
    Serial.println("PENGERINGAN SELESAI");
    client.publish(topicStatus, "PENGERINGAN SELESAI");
    
    // Tampilkan selesai selama 5 detik
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("PENGERINGAN");
    lcd.setCursor(0, 1);
    lcd.print("SELESAI");
    delay(5000);
    
    // Exhaust jalan 20 detik untuk buang panas
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Cooling down...");
    lcd.setCursor(0, 1);
    lcd.print("20 seconds");
    
    // Countdown 20 detik
    for (int i = 20; i > 0; i--) {
      lcd.setCursor(0, 1);
      lcd.print("                ");
      lcd.setCursor(0, 1);
      lcd.print(String(i) + " seconds left");
      delay(1000);
      
      // Tetap kirim MQTT status relay saat cooling
      kirimStatusRelay(suhu, berat);
      client.loop();
    }
    
    // Matikan exhaust dan kembali ke ready
    digitalWrite(RELAY_EXHAUST, HIGH);  // EXHAUST OFF
    
    // Reset variabel
    pengeringanSelesai = false;
    beratTersimpan     = false;
    berat_awal      = 0;
    berat_trigger   = 0;
    waktuMulaiBerat = 0;
    
    lcd.clear();
    tampilReady();
    client.publish(topicStatus, "PENGERINGAN SIAP");
    
    // Kirim status relay setelah reset
    kirimStatusRelay(suhu, berat);
    
    Serial.println("Sistem kembali ke READY");
    
    delay(500);
    return;
  }
  
  // =====================================================
  // RELAY CONTROL berdasarkan suhu
  // Heater 1 & 2 ON, Fan ON
  // Exhaust ON jika suhu >= 60°C
  // =====================================================
  digitalWrite(RELAY_HEATER1, LOW);  // HEATER 1 ON
  digitalWrite(RELAY_HEATER2, LOW);  // HEATER 2 ON
  digitalWrite(RELAY_FAN, LOW);      // FAN ON
  
  // Exhaust kontrol otomatis berdasarkan suhu
  if (suhu >= 60.0) {
    digitalWrite(RELAY_EXHAUST, LOW);  // EXHAUST ON
    Serial.println("EXHAUST ON (Suhu >= 60C)");
  } else {
    digitalWrite(RELAY_EXHAUST, HIGH); // EXHAUST OFF
  }
  
  // =====================================================
  // LCD BARIS 1
  // =====================================================
  lcd.setCursor(0, 0);
  lcd.print("                ");
  lcd.setCursor(0, 0);
  lcd.print("S:");
  lcd.print(suhu, 1);
  lcd.print("C");
  lcd.setCursor(9, 0);
  lcd.print("B:");
  lcd.print(berat, 0);
  lcd.print("g");
  
  // =====================================================
  // LCD BARIS 2
  // =====================================================
  lcd.setCursor(0, 1);
  lcd.print("                ");
  lcd.setCursor(0, 1);
  if (!beratTersimpan) {
    lcd.print("Scan Berat...");
  }
  else {
    lcd.print("T:");
    lcd.print(berat_trigger, 0);
    lcd.print("g");
  }
  
  // =====================================================
  // MQTT DATA (kirim ke Backend Railway)
  // =====================================================
  kirimStatusRelay(suhu, berat);
  
  delay(1000);
}

// =====================================================
// MQTT DATA dengan Status Relay (Format JSON untuk Backend Railway)
// =====================================================
void kirimStatusRelay(float suhu, float berat) {
  // Baca status relay saat ini
  bool heater1_on = (digitalRead(RELAY_HEATER1) == LOW);
  bool heater2_on = (digitalRead(RELAY_HEATER2) == LOW);
  bool fan_on = (digitalRead(RELAY_FAN) == LOW);
  bool exhaust_on = (digitalRead(RELAY_EXHAUST) == LOW);
  
  // Format JSON dengan status relay
  String payload = "{";
  payload += "\"suhu\":" + String(suhu, 1) + ",";
  payload += "\"berat\":" + String(berat, 0) + ",";
  payload += "\"target\":" + String(berat_trigger, 0) + ",";
  payload += "\"relay1\":" + String(heater1_on ? "true" : "false") + ",";
  payload += "\"relay2\":" + String(heater2_on ? "true" : "false") + ",";
  payload += "\"relay3\":" + String(fan_on ? "true" : "false") + ",";
  payload += "\"relay4\":" + String(exhaust_on ? "true" : "false");
  payload += "}";
  
  // Publish ke topic data
  bool success = client.publish(topicData, payload.c_str());
  
  if (success) {
    Serial.print("MQTT Data Sent: ");
    Serial.println(payload);
  } else {
    Serial.println("MQTT Data Failed to Send");
  }
}

// =====================================================
// MQTT DATA (Backward compatibility - deprecated)
// =====================================================
void kirimDataMQTT(float suhu, float berat) {
  kirimStatusRelay(suhu, berat);
}

// =====================================================
// READY LCD
// =====================================================
void tampilReady() {
  lcd.setCursor(0, 0);
  lcd.print("                ");
  lcd.setCursor(0, 0);
  lcd.print("Ready to Dry");
  
  lcd.setCursor(0, 1);
  lcd.print("                ");
  lcd.setCursor(0, 1);
  lcd.print("Press Button");
}

// =====================================================
// SELESAI LCD
// =====================================================
void tampilSelesai() {
  lcd.setCursor(0, 0);
  lcd.print("                ");
  lcd.setCursor(0, 0);
  lcd.print("PENGERINGAN");
  
  lcd.setCursor(0, 1);
  lcd.print("                ");
  lcd.setCursor(0, 1);
  lcd.print("SELESAI");
}
