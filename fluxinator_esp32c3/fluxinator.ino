#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// --- HARDWARE PINOUT ---
const int PIN_ENCODER_CLK = 0;
const int PIN_ENCODER_DT  = 1;
const int PIN_ENCODER_SW  = 3;
const int PIN_FAN_PWM     = 4;
const int PIN_ARGB_DATA   = 5;

// --- FAN PWM SPECS (Intel 4-wire standard: 25 kHz) ---
const int PWM_FREQ        = 25000;
const int PWM_RESOLUTION  = 8;
const int PWM_CHANNEL     = 0;

// --- ARGB CONFIGURATION ---
const int NUM_LEDS = 12;
Adafruit_NeoPixel strip(NUM_LEDS, PIN_ARGB_DATA, NEO_GRB + NEO_KHZ800);

// --- STATE MANAGEMENT ---
int fanSpeedPercent = 50;
int lastFanSpeedPercent = 50;
bool fanEnabled = true;
int ledBrightness = 120;

enum ControlMode { MODE_FAN, MODE_LIGHT };
ControlMode currentMode = MODE_FAN;

int lastClkState;
unsigned long lastButtonPress = 0;
bool buttonHeld = false;

// --- NORDIC UART SERVICE (NUS) ---
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Hardware drivers
void setFanDuty(int percent) {
  int duty = 0;
  if (fanEnabled && percent > 0) {
    duty = map(percent, 0, 100, 0, 255);
  }
  #if ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0)
    ledcWrite(PIN_FAN_PWM, duty);
  #else
    ledcWrite(PWM_CHANNEL, duty);
  #endif
}

void updateLEDs() {
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, strip.Color(255, 240, 220));
  }
  strip.setBrightness(ledBrightness);
  strip.show();
}

void sendBleStatus(String message) {
  if (deviceConnected && pTxCharacteristic != NULL) {
    message += "\r\n";
    pTxCharacteristic->setValue((uint8_t*)message.c_str(), message.length());
    pTxCharacteristic->notify();
  }
}

// Protocol Command Parser
void parseBleCommand(String cmd) {
  cmd.trim();
  cmd.toUpperCase();

  if (cmd.startsWith("FAN ") || cmd.startsWith("F ")) {
    int val = cmd.substring(cmd.indexOf(' ') + 1).toInt();
    fanSpeedPercent = constrain(val, 0, 100);
    fanEnabled = (fanSpeedPercent > 0);
    setFanDuty(fanSpeedPercent);
    sendBleStatus("FAN:" + String(fanSpeedPercent));
    Serial.printf("[BLE RX] Speed: %d%%\n", fanSpeedPercent);
  } 
  else if (cmd.startsWith("LIGHT ") || cmd.startsWith("L ")) {
    int val = cmd.substring(cmd.indexOf(' ') + 1).toInt();
    ledBrightness = constrain(val, 0, 255);
    updateLEDs();
    sendBleStatus("LIGHT:" + String(ledBrightness));
    Serial.printf("[BLE RX] Light: %d/255\n", ledBrightness);
  } 
  else if (cmd == "OFF") {
    fanEnabled = false;
    setFanDuty(0);
    sendBleStatus("FAN:OFF");
    Serial.println("[BLE RX] Fan STOP");
  } 
  else if (cmd == "ON") {
    fanEnabled = true;
    if (fanSpeedPercent == 0) fanSpeedPercent = 50;
    setFanDuty(fanSpeedPercent);
    sendBleStatus("FAN:" + String(fanSpeedPercent));
    Serial.println("[BLE RX] Fan ENGAGE");
  } 
  else if (cmd == "STATUS" || cmd == "?") {
    String stat = "STATUS:FAN=" + String(fanEnabled ? fanSpeedPercent : 0) + 
                  ";LIGHT=" + String(ledBrightness);
    sendBleStatus(stat);
    Serial.println("[BLE RX] Status requested");
  }
}

class ServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
  };
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
  }
};

class CharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      parseBleCommand(rxValue);
    }
  }
};

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("=== FLUXINATOR FIRMWARE v0.1-alpha ===");

  pinMode(PIN_ENCODER_CLK, INPUT_PULLUP);
  pinMode(PIN_ENCODER_DT, INPUT_PULLUP);
  pinMode(PIN_ENCODER_SW, INPUT_PULLUP);
  lastClkState = digitalRead(PIN_ENCODER_CLK);

  #if ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0)
    ledcAttach(PIN_FAN_PWM, PWM_FREQ, PWM_RESOLUTION);
  #else
    ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION);
    ledcAttachPin(PIN_FAN_PWM, PWM_CHANNEL);
  #endif

  strip.begin();
  updateLEDs();
  setFanDuty(fanSpeedPercent);

  // BLE Init
  BLEDevice::init("Fluxinator-C3");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_TX,
                        BLECharacteristic::PROPERTY_NOTIFY
                      );
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Stöd för både WRITE och WRITE_NR
  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                                           CHARACTERISTIC_UUID_RX,
                                           BLECharacteristic::PROPERTY_WRITE | 
                                           BLECharacteristic::PROPERTY_WRITE_NR
                                         );
  pRxCharacteristic->setCallbacks(new CharacteristicCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("System ready. BLE advertising as 'Fluxinator-C3'");
}

void loop() {
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("BLE advertising resumed");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("BLE Client connected");
  }

  // 1. ROTARY ENCODER ROTATION
  int currentClkState = digitalRead(PIN_ENCODER_CLK);
  if (currentClkState != lastClkState && currentClkState == LOW) {
    bool clockwise = (digitalRead(PIN_ENCODER_DT) != currentClkState);

    if (currentMode == MODE_FAN) {
      fanSpeedPercent = constrain(fanSpeedPercent + (clockwise ? 5 : -5), 0, 100);
      fanEnabled = (fanSpeedPercent > 0);
      setFanDuty(fanSpeedPercent);
      Serial.printf("[ENCODER] Fan: %d%%\n", fanSpeedPercent);
      sendBleStatus("FAN:" + String(fanSpeedPercent));
    } 
    else if (currentMode == MODE_LIGHT) {
      ledBrightness = constrain(ledBrightness + (clockwise ? 15 : -15), 0, 255);
      updateLEDs();
      Serial.printf("[ENCODER] Light: %d/255\n", ledBrightness);
      sendBleStatus("LIGHT:" + String(ledBrightness));
    }
  }
  lastClkState = currentClkState;

  // 2. ROTARY ENCODER BUTTON
  int buttonState = digitalRead(PIN_ENCODER_SW);
  if (buttonState == LOW) {
    if (lastButtonPress == 0) {
      lastButtonPress = millis();
    } 
    else if (!buttonHeld && (millis() - lastButtonPress > 1000)) {
      buttonHeld = true;
      fanEnabled = !fanEnabled;
      if (fanEnabled) {
        fanSpeedPercent = (lastFanSpeedPercent > 0) ? lastFanSpeedPercent : 50;
      } else {
        lastFanSpeedPercent = fanSpeedPercent;
      }
      setFanDuty(fanSpeedPercent);
      Serial.printf("[BUTTON HOLD] Fan: %s\n", fanEnabled ? String(fanSpeedPercent) + "%" : "OFF");
      sendBleStatus(fanEnabled ? ("FAN:" + String(fanSpeedPercent)) : "FAN:OFF");
    }
  } 
  else {
    if (lastButtonPress > 0) {
      if (!buttonHeld && (millis() - lastButtonPress > 50)) {
        currentMode = (currentMode == MODE_FAN) ? MODE_LIGHT : MODE_FAN;
        Serial.printf("[BUTTON CLICK] Mode -> %s\n", currentMode == MODE_FAN ? "FAN" : "LIGHT");
      }
      lastButtonPress = 0;
      buttonHeld = false;
    }
  }
}