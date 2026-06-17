#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <DHT22.h>
#include <MQ135.h>
#include <DIYables_LCD_I2C.h>
#include <Wire.h>
#include <MQTT.h>
#include <InfluxDbClient.h>
#include <SoftwareSerial.h>
#include <TinyGPS++.h>

// =====================================================================
//  USER CONFIGURATION  —  edit these to match your environment
// =====================================================================

// --- Device identity ---
#define DEVICE_NAME "ESP8266_Indoor_AQI"

// --- Wi-Fi ---
const char* WIFI_SSID     = "HOME_WIFI_JUS-2G";
const char* WIFI_PASSWORD = "askme@456";

const char* WIFI_SSID1  = "Justin";
const char* WIFI_PASSWORD1 = "11110000";

const char* WIFI_SSID2  = "UR-CST";
const char* WIFI_PASSWORD2 = "";

// --- MQTT broker ---
const char* MQTT_HOST    = "34.224.153.254";
const int   MQTT_PORT    = 1884;
const char* MQTT_CLIENT  = "esp8266_indoor_01";
const char* MQTT_TOPIC   = "sensors/indoor/airquality";

// --- InfluxDB ---
// #define INFLUXDB_URL    "https://influxdb.airsense.dpdns.org"
#define INFLUXDB_URL    "http://34.224.153.254:8086"
#define INFLUXDB_TOKEN  "6DCitH0KN-1kzXdolI31Pb4i1ulbgDVtsgQ9qySLubpF1cszlntvIDa_8UCcmbbSIgSO9elROXhgZoPa2m0Ymw=="
#define INFLUXDB_ORG    "airsense"
#define INFLUXDB_BUCKET "Kigali"

// --- Google Geolocation ---
#define GEOLOCATION_API_KEY "AIzaSyD4zYVzDGNVvjx1EjY-n1z4Q4owqHXkhiY"

// --- Timing ---
const unsigned long UPDATE_INTERVAL_MS = 5000;   // how often we publish / refresh LCD

// How often the Google Geolocation fallback may run when GPS has no fix.
// Prevents an HTTPS request every cycle (saves API quota + latency).
const unsigned long GEO_FALLBACK_INTERVAL_MS = 300000UL;  // 5 minutes

// --- AQI weights (should sum to 1.0) ---
const float W_PM25 = 0.5f;
const float W_PM10 = 0.3f;
const float W_GAS  = 0.2f;

// =====================================================================
//  HARDWARE WIRING  —  must match how the board is connected
// =====================================================================

// Sensors
#define DHTPIN   13          // DHT22 data pin (NodeMCU D7 / GPIO13)
#define MQTPIN   A0          // MQ135 analog out

// PMS5003 is on HARDWARE Serial:
//   PMS5003 TX -> NodeMCU RX (D9 / GPIO3)
// Same Serial is also used for debug at 9600 baud.

// GPS module (NEO-6M) on SoftwareSerial:
//   GPS TX -> NodeMCU D2 (GPIO4).  GPS RX is unused.
//   NOTE: do NOT use D1/GPIO5 here — that pin is the LCD I2C SCL.
#define GPS_RX_PIN  D2       // GPIO4 — receives data FROM the GPS TX
#define GPS_TX_PIN  D3       // GPIO0 — dummy TX, leave nothing connected (boot pin)
static const uint32_t GPS_BAUD = 9600;

// RGB LED (matches reference sketch)
#define PIN_R    D0          // Red   (GPIO16 — on/off only, no true PWM)
#define PIN_G    D4          // Green (GPIO2  — supports PWM)
#define PIN_B    D8          // Blue  (GPIO15 — supports PWM; LED off at boot is fine)

// LCD on I2C: SDA -> D5, SCL -> D6

// PMS5003 frame
#define LENG     31          // 0x42 + 31 bytes = 32-byte frame

// =====================================================================
//  Globals (don't usually need to edit below this line)
// =====================================================================

DIYables_LCD_I2C lcd(0x27, 20, 4);
DHT22            dht(DHTPIN);
MQ135            gasSensor(MQTPIN);

WiFiClient       net;
MQTTClient       mqttclient(1024);
InfluxDBClient   influx_client(INFLUXDB_URL, INFLUXDB_ORG, INFLUXDB_BUCKET, INFLUXDB_TOKEN);

TinyGPSPlus      gps;
SoftwareSerial   gpsSerial(GPS_RX_PIN, GPS_TX_PIN);  // (RX, TX) from the ESP's point of view

unsigned long lastUpdateMillis = 0;
unsigned long lastGeoFallbackMillis = 0;
bool          geoFallbackEverRun = false;

float currentLat    = 0.0;
float currentLng    = 0.0;
bool  locationFound = false;

unsigned char buf[LENG];
int PM01Value  = 0;
int PM2_5Value = 0;
int PM10Value  = 0;

int    currentAQI         = 0;
String currentAQICategory = "Good";

// =====================================================================
//  AQI helpers (US EPA breakpoints + weighted composite)
// =====================================================================

int calcSubIndex(float conc, float cLow, float cHigh, int iLow, int iHigh) {
  return (int)(((iHigh - iLow) / (cHigh - cLow)) * (conc - cLow) + iLow);
}

int aqiPM25(float pm25) {
  if (pm25 <= 12.0)  return calcSubIndex(pm25, 0,     12.0,  0,   50);
  if (pm25 <= 35.4)  return calcSubIndex(pm25, 12.1,  35.4,  51,  100);
  if (pm25 <= 55.4)  return calcSubIndex(pm25, 35.5,  55.4,  101, 150);
  if (pm25 <= 150.4) return calcSubIndex(pm25, 55.5,  150.4, 151, 200);
  if (pm25 <= 250.4) return calcSubIndex(pm25, 150.5, 250.4, 201, 300);
  if (pm25 <= 500.4) return calcSubIndex(pm25, 250.5, 500.4, 301, 500);
  return 500;
}

int aqiPM10(float pm10) {
  if (pm10 <= 54)  return calcSubIndex(pm10, 0,   54,  0,   50);
  if (pm10 <= 154) return calcSubIndex(pm10, 55,  154, 51,  100);
  if (pm10 <= 254) return calcSubIndex(pm10, 155, 254, 101, 150);
  if (pm10 <= 354) return calcSubIndex(pm10, 255, 354, 151, 200);
  if (pm10 <= 424) return calcSubIndex(pm10, 355, 424, 201, 300);
  if (pm10 <= 604) return calcSubIndex(pm10, 425, 604, 301, 500);
  return 500;
}

int aqiGas(float ppm) {
  if (ppm <= 50)   return calcSubIndex(ppm, 0,    50,   0,   50);
  if (ppm <= 100)  return calcSubIndex(ppm, 50,   100,  51,  100);
  if (ppm <= 200)  return calcSubIndex(ppm, 100,  200,  101, 150);
  if (ppm <= 400)  return calcSubIndex(ppm, 200,  400,  151, 200);
  if (ppm <= 800)  return calcSubIndex(ppm, 400,  800,  201, 300);
  if (ppm <= 2000) return calcSubIndex(ppm, 800,  2000, 301, 500);
  return 500;
}

int calcWeightedAQI(float pm25, float pm10, float ppm) {
  int a25  = aqiPM25(pm25);
  int a10  = aqiPM10(pm10);
  int aGas = aqiGas(ppm);
  float weighted = W_PM25 * a25 + W_PM10 * a10 + W_GAS * aGas;
  return (int)round(weighted);
}

String aqiCategory(int aqi) {
  if (aqi <= 50)  return "Good";
  if (aqi <= 100) return "Moderate";
  if (aqi <= 150) return "Sensitive";
  if (aqi <= 200) return "Unhealthy";
  if (aqi <= 300) return "V.Unhealth";
  return "Hazardous";
}

// =====================================================================
//  RGB LED  (common-cathode: HIGH = ON. For common-anode, invert.)
// =====================================================================

void setRGB(int r, int g, int b) {
  analogWrite(PIN_R, r);   // GPIO16: effectively on/off
  analogWrite(PIN_G, g);
  analogWrite(PIN_B, b);
}

void updateRGB(int aqi) {
  // Values are in 0..1023, where 0 = full brightness, 1023 = off
  if      (aqi <= 50)  setRGB(1023,    0, 1023);  // Green    – Good
  else if (aqi <= 100) setRGB(   0,    0, 1023);  // Yellow   – Moderate          (R + G on)
  else if (aqi <= 150) setRGB(   0,  650, 1023);  // Orange   – Sensitive groups  (R full, G dim)
  else if (aqi <= 200) setRGB(   0, 1023, 1023);  // Red      – Unhealthy
  else if (aqi <= 300) setRGB( 132, 1023,  30);  // Purple   – Very unhealthy    (R + B mid)
  else                 setRGB(   0, 1023,  750);  // Pink/red – Hazardous         (R full, B faint)
}

// =====================================================================
//  PMS5003 parsing  (hardware Serial, just like your reference sketch)
// =====================================================================

char checkValue(unsigned char *thebuf, char leng) {
  int receiveSum = 0;
  for (int i = 0; i < (leng - 2); i++) receiveSum += thebuf[i];
  receiveSum += 0x42;
  return (receiveSum == ((thebuf[leng - 2] << 8) + thebuf[leng - 1])) ? 1 : 0;
}

int transmitPM01(unsigned char *thebuf)  { return ((thebuf[3] << 8) + thebuf[4]); }
int transmitPM2_5(unsigned char *thebuf) { return ((thebuf[5] << 8) + thebuf[6]); }
int transmitPM10(unsigned char *thebuf)  { return ((thebuf[7] << 8) + thebuf[8]); }

void readPMS() {
  if (Serial.find((char)0x42)) {
    Serial.readBytes(buf, LENG);
    if (buf[0] == 0x4d && checkValue(buf, LENG)) {
      PM01Value  = transmitPM01(buf);
      PM2_5Value = transmitPM2_5(buf);
      PM10Value  = transmitPM10(buf);
    }
  }
}

// =====================================================================
//  GPS  (SoftwareSerial + TinyGPS++)
// =====================================================================

// Drain whatever the GPS has sent so TinyGPS++ stays current.
// Call this often (every loop), like readPMS().
void readGPS() {
  while (gpsSerial.available() > 0) {
    gps.encode(gpsSerial.read());
  }
}

// =====================================================================
//  Geolocation (Google fallback — used only when GPS has no fix)
// =====================================================================

void getGeolocation() {
  Serial.println("Scanning Wi-Fi for Geolocation...");
  int n = WiFi.scanNetworks();
  if (n == 0) {
    Serial.println("No Wi-Fi networks found.");
    return;
  }

  StaticJsonDocument<1024> doc;
  JsonArray wifiAccessPoints = doc.createNestedArray("wifiAccessPoints");
  for (int i = 0; i < n && i < 10; ++i) {
    JsonObject ap = wifiAccessPoints.createNestedObject();
    ap["macAddress"]     = WiFi.BSSIDstr(i);
    ap["signalStrength"] = WiFi.RSSI(i);
  }

  String requestBody;
  serializeJson(doc, requestBody);

  WiFiClientSecure secureClient;
  secureClient.setInsecure();
  HTTPClient http;

  String url = "https://www.googleapis.com/geolocation/v1/geolocate?key=" + String(GEOLOCATION_API_KEY);
  http.begin(secureClient, url);
  http.addHeader("Content-Type", "application/json");

  int httpResponseCode = http.POST(requestBody);
  if (httpResponseCode > 0) {
    String response = http.getString();
    StaticJsonDocument<512> responseDoc;
    deserializeJson(responseDoc, response);
    currentLat    = responseDoc["location"]["lat"];
    currentLng    = responseDoc["location"]["lng"];
    locationFound = true;
    Serial.print("Loc OK (geo): ");
    Serial.print(currentLat, 6); Serial.print(","); Serial.println(currentLng, 6);
  } else {
    Serial.print("Geolocation HTTP error: "); Serial.println(httpResponseCode);
  }
  http.end();
}

// Decide where location comes from:
//   1. Use the GPS if it has a recent, valid fix.
//   2. Otherwise fall back to Google Geolocation — but no more often than
//      GEO_FALLBACK_INTERVAL_MS (and always at least once at startup).
void updateLocation() {
  if (gps.location.isValid() && gps.location.age() < 5000) {
    currentLat    = gps.location.lat();
    currentLng    = gps.location.lng();
    locationFound = true;
    Serial.print("Loc OK (GPS): ");
    Serial.print(currentLat, 6); Serial.print(","); Serial.println(currentLng, 6);
    return;
  }

  unsigned long now = millis();
  if (!geoFallbackEverRun || (now - lastGeoFallbackMillis >= GEO_FALLBACK_INTERVAL_MS)) {
    Serial.println("GPS no fix -> Google Geolocation fallback");
    getGeolocation();
    lastGeoFallbackMillis = now;
    geoFallbackEverRun = true;
  }
  // else: keep the last known location until the fallback interval elapses
}

// =====================================================================
//  MQTT
// =====================================================================

void connectMQTT() {
  Serial.print("Connecting MQTT");
  while (!mqttclient.connect(MQTT_CLIENT)) {
    Serial.print(".");
    delay(1000);
  }
  Serial.println(" OK");
}

// =====================================================================
//  Setup
// =====================================================================

void setup() {
  // Shared Serial: PMS5003 input + debug output, both at 9600 baud
  Serial.begin(9600);
  delay(10);
  Serial.println("\n--- SYSTEM BOOTING ---");

  // GPS serial
  gpsSerial.begin(GPS_BAUD);

  // RGB LED
  pinMode(PIN_R, OUTPUT);
  pinMode(PIN_G, OUTPUT);
  pinMode(PIN_B, OUTPUT);
  setRGB(0, 0, 0);

  // I2C & LCD
  Wire.begin(D5, D6);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("System Booting...");

  // Wi-Fi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID1,WIFI_PASSWORD1);
  Serial.print("WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.print(".");
  }
  Serial.println(" OK " + WiFi.localIP().toString());

  lcd.setCursor(0, 1);
  lcd.print("Finding Location...");

  // Give the GPS a brief window to deliver any early sentences,
  // then pick a location source (GPS first, geolocation fallback).
  unsigned long gpsWarmup = millis();
  while (millis() - gpsWarmup < 2000) {
    readGPS();
  }
  updateLocation();

  // MQTT
  mqttclient.begin(MQTT_HOST, MQTT_PORT, net);
  connectMQTT();

  // InfluxDB
  if (influx_client.validateConnection()) {
    Serial.println("InfluxDB OK");
  } else {
    Serial.println("InfluxDB FAIL: " + influx_client.getLastErrorMessage());
  }
  lcd.clear();
}

// =====================================================================
//  Main Loop
// =====================================================================

void loop() {
  mqttclient.loop();
  if (!mqttclient.connected()) connectMQTT();

  // Keep draining the PMS5003 and GPS streams
  readPMS();
  readGPS();

  if (millis() - lastUpdateMillis >= UPDATE_INTERVAL_MS) {
    lastUpdateMillis = millis();

    // 1. Sensors
    float t      = dht.getTemperature();
    float h      = dht.getHumidity();
    float aq_ppm = gasSensor.getPPM();

    // 1b. Location: GPS if it has a fix, otherwise Google Geolocation (rate-limited)
    updateLocation();

    // 2. Weighted AQI + RGB
    currentAQI         = calcWeightedAQI((float)PM2_5Value, (float)PM10Value, aq_ppm);
    currentAQICategory = aqiCategory(currentAQI);
    updateRGB(currentAQI);

    // 3. LCD (line 4 shows AQI instead of location)
    lcd.setCursor(0, 0);
    lcd.print("T:"); lcd.print(t, 1); lcd.print("C H:"); lcd.print(h, 0); lcd.print("%   ");

    lcd.setCursor(0, 1);
    lcd.print("Gas:"); lcd.print(aq_ppm, 0); lcd.print(" PPM       ");

    lcd.setCursor(0, 2);
    lcd.print("PM2.5:"); lcd.print(PM2_5Value);
    lcd.print(" PM10:"); lcd.print(PM10Value); lcd.print("  ");

    lcd.setCursor(0, 3);
    lcd.print("AQI:"); lcd.print(currentAQI);
    lcd.print(" "); lcd.print(currentAQICategory); lcd.print("   ");

    // 4. MQTT publish
    StaticJsonDocument<384> mqttDoc;
    mqttDoc["device"]       = DEVICE_NAME;
    mqttDoc["temperature"]  = t;
    mqttDoc["humidity"]     = h;
    mqttDoc["gas_ppm"]      = aq_ppm;
    mqttDoc["pm1_0"]        = PM01Value;
    mqttDoc["pm2_5"]        = PM2_5Value;
    mqttDoc["pm10"]         = PM10Value;
    mqttDoc["aqi"]          = currentAQI;
    mqttDoc["aqi_category"] = currentAQICategory;
    mqttDoc["latitude"]     = currentLat;
    mqttDoc["longitude"]    = currentLng;
    mqttDoc["rssi"]         = WiFi.RSSI();

    String mqttPayload;
    serializeJson(mqttDoc, mqttPayload);
    mqttclient.publish(MQTT_TOPIC, mqttPayload);

    // 5. InfluxDB write
    Point influxPoint("air_quality");
    influxPoint.addTag("device", DEVICE_NAME);
    influxPoint.addTag("ssid", WiFi.SSID());

    influxPoint.addField("temperature",  t);
    influxPoint.addField("humidity",     h);
    influxPoint.addField("gas_ppm",      aq_ppm);
    influxPoint.addField("pm1_0",        PM01Value);
    influxPoint.addField("pm2_5",        PM2_5Value);
    influxPoint.addField("pm10",         PM10Value);
    influxPoint.addField("aqi",          currentAQI);
    influxPoint.addField("aqi_category", currentAQICategory);
    influxPoint.addField("rssi",         WiFi.RSSI());
    if (locationFound) {
      influxPoint.addField("latitude",  currentLat);
      influxPoint.addField("longitude", currentLng);
    }

    if (!influx_client.writePoint(influxPoint)) {
      Serial.print("Influx FAIL: ");
      Serial.println(influx_client.getLastErrorMessage());
    } else {
      Serial.print("AQI=");
      Serial.print(currentAQI);
      Serial.print(" (");
      Serial.print(currentAQICategory);
      Serial.println(")");
    }
  }
}