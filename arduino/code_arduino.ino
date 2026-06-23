// ================== MOTEURS ==================
#define IN1 3
#define IN2 4
#define ENA 9
#define IN3 5
#define IN4 6
#define ENB 10

// ============ CAPTEURS ULTRASON ============
#define trigD 7
#define echoD 8
#define trigC 2
#define echoC 13
#define trigG 11
#define echoG 12

// ================== VARIABLES ==================
int distG = 0, distC = 0, distD = 0;
const int seuil = 35;

// ================== MODE ROBOT ==================
String cmd = "FORWARD";   // ESP32
bool obstacleMode = false;

// ================== SETUP ==================
void setup() {
  Serial.begin(9600);   // ESP32 Serial2

  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT); pinMode(ENA, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT); pinMode(ENB, OUTPUT);

  pinMode(trigG, OUTPUT); pinMode(echoG, INPUT);
  pinMode(trigC, OUTPUT); pinMode(echoC, INPUT);
  pinMode(trigD, OUTPUT); pinMode(echoD, INPUT);
}

// ================== ULTRASON ==================
int getDistance(int trig, int echo) {
  long total = 0;

  for (int i = 0; i < 3; i++) {
    digitalWrite(trig, LOW);
    delayMicroseconds(2);
    digitalWrite(trig, HIGH);
    delayMicroseconds(10);
    digitalWrite(trig, LOW);

    long duration = pulseIn(echo, HIGH, 15000);
    if (duration == 0) duration = 25000;

    total += duration;
    delay(5);
  }

  return (total / 3) * 0.034 / 2;
}

// ================== MOUVEMENTS ==================
void avancer() {
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);  digitalWrite(IN4, HIGH);
  analogWrite(ENA, 120); analogWrite(ENB, 120);
}

void reculer() {
  digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
  analogWrite(ENA, 120); analogWrite(ENB, 120);
}

void tournerGauche() {
  digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH);
  analogWrite(ENA, 120); analogWrite(ENB, 120);
}

void tournerDroite() {
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
  analogWrite(ENA, 120); analogWrite(ENB, 120);
}

void arreter() {
  digitalWrite(IN1, LOW); digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW); digitalWrite(IN4, LOW);
  analogWrite(ENA, 0); analogWrite(ENB, 0);
}

// ================== ESP32 COMMAND ==================
void readESP() {
  if (Serial.available()) {
    cmd = Serial.readStringUntil('\n');
    cmd.trim();
  }
}

// ================== LOOP ==================
void loop() {

  // ===== READ COMMAND FROM ESP32 =====
  readESP();

  // ===== ULTRASON =====
  distG = getDistance(trigG, echoG);
  distC = getDistance(trigC, echoC);
  distD = getDistance(trigD, echoD);

  // ===== OBSTACLE DETECTION =====
  bool obstacle = (distG < seuil || distC < seuil || distD < seuil);

  if (obstacle) {

    obstacleMode = true;

    arreter(); delay(200);
    reculer(); delay(500);

    if (distC < seuil) {
      if (distD > distG) {
        tournerDroite();
      } else {
        tournerGauche();
      }
      delay(300);
    }

  } 
  else {

    obstacleMode = false;

    // ===== GAS FOLLOWING FROM ESP32 =====
    if (cmd == "FORWARD") {
      avancer();
    }
    else if (cmd == "TURN") {
      tournerGauche();
    }
    else {
      arreter();
    }
  }

  delay(50);
}