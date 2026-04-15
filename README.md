# 🍼 Smart IoT Neonatal Incubator

A comprehensive, ESP32-powered smart incubator system designed to monitor and regulate the environment for infants. This system features real-time temperature/humidity control, optional phototherapy for jaundice, continuous ECG/BPM monitoring, and a companion Bluetooth Low Energy (BLE) mobile app for remote monitoring and instant alerts.

---

## ✨ Key Features

### 🖥️ Hardware System (ESP32)
* **Smart Climate Control:** Automatically regulates temperature using a heating lamp and a cooling fan based on DHT11 sensor readings. Features staggered relay activation to protect power supplies from voltage drops.
* **Phototherapy:** Uses an LDR sensor to detect jaundice-range conditions and turn on high-intensity Blue LEDs with a latch push button for treatment.
* **Real-Time ECG Monitoring:** Reads cardiac electrical activity and detects if ECG pads become detached.
* **Local LCD Interface:** Displays real-time temperature, humidity, and critical warnings (like detached ECG pads) directly on the device.
* **BLE Communication:** Broadcasts high-frequency data (ECG) and environmental states efficiently to a connected mobile device.

### 📱 Mobile Companion App
* **Live Vitals Dashboard:** Visualizes real-time ECG waveforms and calculates Beats Per Minute (BPM).
* **Environment Monitoring:** Tracks live Temperature and Humidity data.
* **Comprehensive Alert System:** * 🔴 **BPM Alerts:** Triggers if heart rate falls outside of safe parameters.
  * 🌡️ **Temperature/Humidity Alerts:** Warns if the incubator becomes too hot, too cold, or improperly humidified.
  * 💡 **Jaundice Alerts:** Notifies the caretaker when phototherapy (Blue LEDs) is actively running.

---

## 🛠️ Hardware Components & Pinout

| Component | ESP32 Pin | Logic/Notes |
| :--- | :--- | :--- |
| **Cooling Fan Relay** | `13` | Active HIGH |
| **Heating Lamp Relay** | `32` | Active HIGH (150ms Staggered Start) |
| **DHT11 Sensor** | `4` | Temp & Humidity |
| **LDR Sensor** | `26` | Analog Input |
| **Blue LED 1 (Jaundice)** | `18` | Digital Output |
| **Blue LED 2 (Jaundice)** | `19` | Digital Output |
| **ECG Output (AD8232)**| `34` | Analog Input |
| **ECG LO+ (Leads Off)** | `14` | Digital Input |
| **ECG LO- (Leads Off)** | `15` | Digital Input |
| **LCD Display (I2C)** | `SDA/SCL` | Address: `0x27` (16x2) |

---

## 🧠 System Logic

### Temperature Regulation
The system uses specialized power-safe logic to prevent ESP32 brownouts by never turning on both heavy relay coils at the exact same millisecond:
* **Cooling Mode (> 35.0°C):** Heater turns OFF, Fan turns ON.
* **Heating Mode (<= 32.8°C):** Heater turns ON. After a 500ms delay to allow voltage to stabilize, the Fan turns ON to circulate the heat.
* **Resting Mode (32.9°C - 34.9°C):** Both Fan and Heater turn OFF.

### Jaundice Detection
The system reads analog light values. If the reading falls within the precise target threshold (`1050` to `1250`), it assumes the presence of jaundice conditions, automatically activating the phototherapy LEDs and sending a status flag to the mobile app.

---

## 🚀 Setup & Installation

1. **Hardware Assembly:** Wire the components according to the Pinout table above. Ensure your ESP32 and Relay module are powered by a sufficient power supply (at least 5V 2A is recommended to handle relay coil current spikes).
2. **Software Dependencies:** Install the following libraries in your Arduino IDE:
   * `DHT sensor library` by Adafruit
   * `LiquidCrystal I2C` by Frank de Brabander
   * Standard ESP32 BLE libraries (included with ESP32 board manager)
3. **Upload Code:** Select your ESP32 board in the Arduino IDE and upload the `.ino` file.
4. **Connect App:** Open the companion mobile app, grant Bluetooth permissions, and connect to the device named **`Incubator_BLE`**.

---

## ⚠️ Important Safety Notes
* **Power Supply:** Do not power this system solely from a computer USB port if both relays are active. Use a dedicated wall adapter to prevent hardware crash-loops.
* **Medical Disclaimer:** This is an engineering prototype/academic project. It is not certified for clinical use on real infants without proper medical device certification and safety redundancy testing.
