#include "esp_camera.h"
#include <WiFi.h>
#include <WebServer.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

#define CAMERA_MODEL_AI_THINKER
#include "camera_pins.h"

const char* ssid = "azerty1312a";
const char* password = "azerty1312";

String botToken = "8617997411:AAHwJavz-L2HaBO8XybmF7QsLW_9auRP5TA"; 
String chatID   = "8293026065";

#define FLASH_LED_PIN 4

WebServer server(80);

// ================== INPUT FROM ESP32 PRINCIPAL ==================
String motionState = "0";
String soundState  = "0";
String flameState  = "0";
String gasState    = "0";

String riskIA   = "";
String actionIA = "";

// ================== FLASH ==================
void setFlash(bool state) {
  digitalWrite(FLASH_LED_PIN, state ? HIGH : LOW);
}

// ================== ENCODE ==================
String encode(String msg) {
  msg.replace(" ", "%20");
  msg.replace("\n", "%0A");
  return msg;
}

// ================== TELEGRAM PHOTO ==================
void sendPhotoToTelegram() {

  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera failed");
    return;
  }

  uint8_t * jpg_buf = NULL;
  size_t jpg_len = 0;

  bool ok = frame2jpg(fb, 12, &jpg_buf, &jpg_len);
  esp_camera_fb_return(fb);

  if (!ok || jpg_len == 0) {
    Serial.println("JPEG failed");
    return;
  }

  WiFiClientSecure client;
  client.setInsecure();

  String boundary = "----esp32cam";

  String head =
    "--" + boundary + "\r\n"
    "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n" +
    chatID + "\r\n"
    "--" + boundary + "\r\n"
    "Content-Disposition: form-data; name=\"photo\"; filename=\"alert.jpg\"\r\n"
    "Content-Type: image/jpeg\r\n\r\n";

  String tail = "\r\n--" + boundary + "--\r\n";

  client.connect("api.telegram.org", 443);

  client.print("POST /bot" + botToken + "/sendPhoto HTTP/1.1\r\n");
  client.print("Host: api.telegram.org\r\n");
  client.print("Content-Type: multipart/form-data; boundary=" + boundary + "\r\n");
  client.print("Content-Length: " + String(head.length() + jpg_len + tail.length()) + "\r\n\r\n");

  client.print(head);
  client.write(jpg_buf, jpg_len);
  client.print(tail);

  free(jpg_buf);

  Serial.println("Photo sent");
}

// ================== TELEGRAM MESSAGE ==================
void sendMessageOnly(String msg) {

  WiFiClientSecure client;
  client.setInsecure();

  msg = encode(msg);

  String url =
    "https://api.telegram.org/bot" + botToken +
    "/sendMessage?chat_id=" + chatID +
    "&text=" + msg;

  HTTPClient http;
  http.begin(client, url);

  int code = http.GET();

  Serial.print("Telegram HTTP: ");
  Serial.println(code);

  http.end();
}

// ================== RISK MESSAGE ==================
String buildRiskMessage() {

  if (riskIA == "ELEVE") {
    return "🔴 Risque élevé détecté\nIntervention immédiate requise !";
  }

  else if (riskIA == "MOYEN") {
    return "🟠 Risque moyen détecté\nVigilance recommandée.";
  }

  else {
    return "🟢 Risque faible détecté\nSituation stable.";
  }
}

// ================== ALERT SYSTEM (UPDATED) ==================
void sendAlerte() {

  Serial.println("\n========== TRIGGER ==========");

  Serial.print("Risk IA  : "); Serial.println(riskIA);
  Serial.print("Action IA: "); Serial.println(actionIA);

  // MOVEMENT ALERT (kept simple)
  if (motionState == "1" && riskIA == "ELEVE") {

    Serial.println("ALERTE CRITIQUE");

    sendMessageOnly("🚨 Mouvement + Risque élevé détecté !");
    setFlash(true);
    delay(200);
    sendPhotoToTelegram();
    setFlash(false);

    return;
  }

  // NORMAL ALERT BASED ON IA
  String msg = buildRiskMessage() + "\nAction: " + actionIA;

  sendMessageOnly(msg);

  if (riskIA == "MOYEN" || riskIA == "ELEVE") {

    setFlash(true);
    delay(200);
    sendPhotoToTelegram();
    setFlash(false);
  }
}

// ================== HANDLE TRIGGER ==================
void handleTrigger() {

  motionState = server.arg("motion");
  soundState  = server.arg("sound");
  flameState  = server.arg("flame");
  gasState    = server.arg("gas");

  // NEW FROM ESP32 PRINCIPAL (IA)
  riskIA   = server.arg("risk");
  actionIA = server.arg("action");

  Serial.println("\n========== INPUT ==========");

  Serial.print("Motion: "); Serial.println(motionState);
  Serial.print("Sound : "); Serial.println(soundState);
  Serial.print("Flame : "); Serial.println(flameState);
  Serial.print("Gas   : "); Serial.println(gasState);

  Serial.print("Risk IA : "); Serial.println(riskIA);
  Serial.print("Action  : "); Serial.println(actionIA);

  server.send(200, "text/plain", "OK");

  sendAlerte();
}

// ================== STREAM ==================
void handleCapture() {

  WiFiClient client = server.client();

  String response =
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";

  server.sendContent(response);

  while (client.connected()) {

    camera_fb_t * fb = esp_camera_fb_get();

    if (!fb) continue;

    uint8_t * jpg_buf = NULL;
    size_t jpg_len = 0;

    bool converted = fmt2jpg(
        fb->buf,
        fb->len,
        fb->width,
        fb->height,
        PIXFORMAT_RGB565,
        12,
        &jpg_buf,
        &jpg_len
    );

    esp_camera_fb_return(fb);

    if (!converted) continue;

    String header =
      "--frame\r\n"
      "Content-Type: image/jpeg\r\n"
      "Content-Length: " + String(jpg_len) + "\r\n\r\n";

    server.sendContent(header);
    client.write(jpg_buf, jpg_len);
    server.sendContent("\r\n");

    free(jpg_buf);

    delay(30);
  }
}

// ================== SETUP ==================
void setup() {

  Serial.begin(115200);

  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);

  camera_config_t config;

  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;

  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;

  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;

  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;

  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_RGB565;

  config.frame_size = FRAMESIZE_240X240;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.fb_count = 2;

  esp_camera_init(&config);

  WiFi.begin(ssid, password);

  Serial.print("WiFi connecting");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi OK");
  Serial.println(WiFi.localIP());

  server.on("/trigger", handleTrigger);
  server.on("/capture", handleCapture);

  server.begin();

  Serial.println("Server ready");
}

// ================== LOOP ==================
void loop() {
  server.handleClient();
  delay(20);
}
