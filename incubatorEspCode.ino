#include "DHT.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h> 

// ==========================================
// INCUBATOR PINS & SETTINGS
// ==========================================
#define FAN_RELAY 13  
#define HEAT 32      

#define DHTPIN 4     
#define DHTTYPE DHT11   

// Temperature Control Zones
const float COOLING_TEMP = 35.0; // Above this: Fan ON (Cooling)
const float MIN_TEMP = 32.8;     // Below this: Lamp ON, Fan ON (Heating)

DHT dht(DHTPIN, DHTTYPE);

// ==========================================
// JAUNDICE (LDR) & PHOTOTHERAPY (LEDs)
// ==========================================
#define LDR 26
#define BLUE_LED1 18
#define BLUE_LED2 19

// The exact range where jaundice is detected
const int JAUNDICE_MIN = 1050; 
const int JAUNDICE_MAX = 1250; 

// ==========================================
// LCD SETUP
// ==========================================
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ==========================================
// ECG PINS & SETTINGS
// ==========================================
const int LO_MINUS_PIN = 15;   
const int LO_PLUS_PIN = 14;    
const int ECG_OUTPUT_PIN = 34; 

bool ecgDisconnected = false; // Flag for the LCD warning

// ==========================================
// BLE SETUP & UUIDs
// ==========================================
BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;

#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" 
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("App Connected via BLE!");
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("App Disconnected. Waiting for reconnect...");
    }
};

// ==========================================
// TIMING VARIABLES
// ==========================================
unsigned long previousMillisDHT = 0;
const long dhtInterval = 2000;  

unsigned long previousMillisECG = 0;
const long ecgInterval = 10;    

unsigned long previousMillisLDR = 0;
const long ldrInterval = 500;   

// Track current relay states to prevent unnecessary updates
bool isHeating = false;

void setup() {
  Serial.begin(115200); 
  
  // --- Initialize LCD ---
  lcd.init();                      
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Incubator System");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
  
  // --- Initialize Incubator ---
  pinMode(FAN_RELAY, OUTPUT);
  pinMode(HEAT, OUTPUT);
  
  dht.begin();
  
  // --- Start completely OFF (BOTH Active HIGH) ---
  digitalWrite(FAN_RELAY, LOW); 
  digitalWrite(HEAT, LOW);       

  // --- Initialize Jaundice Hardware ---
  pinMode(LDR, INPUT); 
  pinMode(BLUE_LED1, OUTPUT);
  pinMode(BLUE_LED2, OUTPUT);
  digitalWrite(BLUE_LED1, LOW); 
  digitalWrite(BLUE_LED2, LOW);

  // --- Initialize ECG ---
  pinMode(LO_MINUS_PIN, INPUT);
  pinMode(LO_PLUS_PIN, INPUT);
  
  // --- Initialize BLE ---
  BLEDevice::init("Incubator_BLE");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_TX,
                        BLECharacteristic::PROPERTY_NOTIFY
                      );
                      
  pTxCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  pServer->getAdvertising()->start();
  
  delay(2000); 
  lcd.clear(); 
  Serial.println("BLE & LCD Active!");
}

// Helper function for BLE transmission
void sendToApp(String message) {
  if (deviceConnected) {
    pTxCharacteristic->setValue(message.c_str());
    pTxCharacteristic->notify();
  }
}

void loop() {
  unsigned long currentMillis = millis();

  // Handle BLE Disconnection/Reconnection
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); 
      pServer->startAdvertising(); 
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }

  // ---------------------------------------------------------
  // 1. READ & SEND ECG SENSOR (~100Hz)
  // ---------------------------------------------------------
  if (currentMillis - previousMillisECG >= ecgInterval) {
    previousMillisECG = currentMillis;
    
    int rawECG = 0;
    if ((digitalRead(LO_MINUS_PIN) == 1) || (digitalRead(LO_PLUS_PIN) == 1)) {
      rawECG = 0; 
      ecgDisconnected = true;  
    } else {
      rawECG = analogRead(ECG_OUTPUT_PIN);
      ecgDisconnected = false; 
    }

    int mappedECG = map(rawECG, 0, 4095, 0, 1023);
    sendToApp(String(mappedECG) + "\n");
  }

  // ---------------------------------------------------------
  // 2. READ LDR, CONTROL BLUE LEDs & SEND DATA (Every 500ms)
  // ---------------------------------------------------------
  if (currentMillis - previousMillisLDR >= ldrInterval) {
    previousMillisLDR = currentMillis;
    
    int readLDR = analogRead(LDR);
    double jaundiceIndex = (double)readLDR; 

   

    sendToApp("J:" + String(jaundiceIndex) + "\n");
  }

  // ---------------------------------------------------------
  // 3. READ DHT, CONTROL TEMP & UPDATE LCD (Every 2 seconds)
  // ---------------------------------------------------------
  if (currentMillis - previousMillisDHT >= dhtInterval) {
    previousMillisDHT = currentMillis;

    float h = dht.readHumidity();
    float t = dht.readTemperature();

    if (!isnan(h) && !isnan(t)) {
      
      // --- Update LCD Display ---
      if (ecgDisconnected) {
        lcd.setCursor(0, 0);
        lcd.print("WARNING: ECG    "); 
        lcd.setCursor(0, 1);
        lcd.print("PADS DETACHED!  ");
      } else {
        lcd.setCursor(0, 0);
        lcd.print("Temp: ");
        lcd.print(t, 1); 
        lcd.print(" C   "); 

        lcd.setCursor(0, 1);
        lcd.print("Hum:  ");
        lcd.print(h, 1); 
        lcd.print(" %   ");
      }

      // --- NEW LOGIC: BOTH ACTIVE HIGH ---
      if (t > COOLING_TEMP) {
        // Too Hot (> 35.0) -> Cooling Mode
        digitalWrite(HEAT, LOW);       // Lamp OFF
        digitalWrite(FAN_RELAY, HIGH); // Fan ON
        isHeating = false;
      } 
      else if (t <= MIN_TEMP) {
        // Too Cold (<= 32.8) -> Heating Mode
        if (!isHeating) {
          digitalWrite(HEAT, HIGH);      // Turn Lamp ON first
          delay(500);                    // Wait HALF A SECOND for power to recover
          digitalWrite(FAN_RELAY, HIGH); // Turn Fan ON second
          isHeating = true;
        }
      } 
      else {
        // Perfect Range (32.9 to 34.9) -> Resting Mode
        digitalWrite(HEAT, LOW);       // Lamp OFF
        digitalWrite(FAN_RELAY, LOW);  // Fan OFF
        isHeating = false;
      }

      sendToApp("T:" + String(t) + "\n");
      sendToApp("H:" + String(h) + "\n");
    } else {
      lcd.setCursor(0, 0);
      lcd.print("DHT Sensor Error");
      lcd.setCursor(0, 1);
      lcd.print("Check Wiring!   ");
    }
  }
}