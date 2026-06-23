#include <WiFi.h>
#include <HTTPClient.h>

const char* ssid = "azerty1312a";
const char* password = "azerty1312";

String camIP = "10.26.249.20";
String apiKey = "NSLTC3Q47E2WAJVF";

#define FLAME_PIN 25
#define MOTION_PIN 27
#define SOUND_PIN 26
#define LIGHT_PIN 35
#define GAS_PIN 34

unsigned long lastSend = 0;
int interval = 30000;

String riskLevel;
String actionIA;

// ================== GAS TRACKING ==================
int lastGas = 0;
String robotCommand = "STOP";

// ================== ARBRE RISQUE ==================
String decisionRisque(int flamme, int gaz, int son) {

  if (flamme > 0.5)
    return "ELEVE";

  if (gaz <= 71) {

    if (gaz <= 31) {

      if (son <= 62.5)
        return "FAIBLE";
      else
        return "MOYEN";
    } else {
      return "MOYEN";
    }

  } else {
    return "ELEVE";
  }
}

// ================== ARBRE ACTION ==================
String decisionAction(int flamme, int gaz, int son, int lumiere, int mouvement) {

  if (flamme <= 0.5) {

    if (gaz <= 71) {

      if (son <= 57.5) {

        if (gaz <= 38.5)
          return "AVANCER";
        else
          return "TOURNER_GAUCHE";
      } else {

        if (lumiere <= 15)
          return "TOURNER_GAUCHE";
        else
          return "TOURNER_DROITE";
      }

    } else {

      if (son <= 77)
        return "RECULER";
      else
        return "STOP";
    }

  } else {

    if (son <= 92.5) {

      if (gaz <= 19.5)
        return "STOP";

      if (mouvement == 0)
        return "STOP";
      else
        return "RECULER";
    }

    return "STOP";
  }
}

void setup() {
  Serial.begin(115200);

  // Serial ver Arduino
  Serial2.begin(9600, SERIAL_8N1, 16, 17); 

  pinMode(FLAME_PIN, INPUT_PULLDOWN);
  pinMode(MOTION_PIN, INPUT_PULLDOWN);
  pinMode(SOUND_PIN, INPUT);
  pinMode(GAS_PIN, INPUT);
  pinMode(LIGHT_PIN, INPUT);

  WiFi.begin(ssid, password);

  Serial.print("Connexion WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi OK");
  Serial.println(WiFi.localIP());
}

void loop() {

  // ================== SENSORS ==================
  int flame = digitalRead(FLAME_PIN);
  int motion = digitalRead(MOTION_PIN);
  int sound  = analogRead(SOUND_PIN);
  int gas    = analogRead(GAS_PIN);
  int light  = analogRead(LIGHT_PIN);

  bool night = (light > 1500);

  // ================== GAS TRACKING (NEW FEATURE) ==================

  if (gas > lastGas) {
    robotCommand = "FORWARD";
  } else {
    robotCommand = "TURN";
  }

  Serial2.println(robotCommand);
  lastGas = gas;

  // ================== IA ==================
  riskLevel = decisionRisque(flame, gas, sound);

  actionIA = decisionAction(
                flame,
                gas,
                sound,
                light,
                motion);

  // ================== INTERVAL ==================
  if (riskLevel == "FAIBLE") interval = 30000;
  else if (riskLevel == "MOYEN") interval = 25000;
  else interval = 15000;

  // ================== SEND DATA ==================
  if (millis() - lastSend > interval) {

    if (WiFi.status() == WL_CONNECTED) {

      HTTPClient http;

      String url =
        "http://api.thingspeak.com/update?api_key=" + apiKey +
        "&field1=" + String(flame) +
        "&field2=" + String(night) +
        "&field3=" + String(motion) +
        "&field4=" + String(sound) +
        "&field5=" + String(gas) +
        "&field6=" + riskLevel +
        "&field7=" + String(light);

      http.begin(url);
      int code = http.GET();
      http.end();

      Serial.print("ThingSpeak HTTP: ");
      Serial.println(code);
    }

    // ================== CAM ==================
    String urlCam =
      "http://" + camIP + "/trigger?"
      "photo=1"
      "&flash=" + String(night ? 1 : 0) +
      "&risk=" + riskLevel +
      "&action=" + actionIA +
      "&flame=" + String(flame) +
      "&motion=" + String(motion) +
      "&sound=" + String(sound) +
      "&gas=" + String(gas);

    Serial.println("\n===== URL CAM =====");
    Serial.println(urlCam);

    HTTPClient http2;
    http2.begin(urlCam);

    int code2 = http2.GET();

    Serial.print("CAM HTTP CODE: ");
    Serial.println(code2);

    http2.end();

    lastSend = millis();
  }

  // ================== DEBUG ==================
  Serial.println("\n================================");

  Serial.print("Flame    : "); Serial.println(flame);
  Serial.print("Motion   : "); Serial.println(motion);
  Serial.print("Sound    : "); Serial.println(sound);
  Serial.print("Light    : "); Serial.println(light);
  Serial.print("Gas      : "); Serial.println(gas);

  Serial.print("Risk IA  : "); Serial.println(riskLevel);
  Serial.print("Action IA: "); Serial.println(actionIA);

  Serial.print("RobotCmd : "); Serial.println(robotCommand);

  Serial.print("Interval : "); Serial.println(interval);

  Serial.println("================================");

  delay(1000);
}