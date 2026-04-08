import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────────────────────────────────────────────
//  COLOR PALETTE
// ─────────────────────────────────────────────────────────────
const Color kNavy      = Color(0xFF0A1628);
const Color kBlue      = Color(0xFF1565C0);
const Color kBlueLight = Color(0xFF1E88E5);
const Color kBluePale  = Color(0xFFE3F0FF);
const Color kAccent    = Color(0xFF42A5F5);
const Color kBg        = Color(0xFFF0F5FF);
const Color kCardBorder= Color(0xFFDCE8FF);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(const ECGApp());
}

class ECGApp extends StatelessWidget {
  const ECGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBlue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kBlue),
        ),
      ),
      home: const BluetoothScannerScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BLUETOOTH SCANNER SCREEN
// ─────────────────────────────────────────────────────────────
class BluetoothScannerScreen extends StatefulWidget {
  const BluetoothScannerScreen({super.key});

  @override
  State<BluetoothScannerScreen> createState() => _BluetoothScannerScreenState();
}

class _BluetoothScannerScreenState extends State<BluetoothScannerScreen>
    with SingleTickerProviderStateMixin {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  StreamSubscription? adapterStateSubscription;
  StreamSubscription? _scanResultsSubscription;
  ServiceStatus locationServiceStatus = ServiceStatus.disabled;
  late AnimationController _animationController;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
          if (mounted) setState(() => adapterState = state);
        });
    _runStartupSequence();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      var status = await Permission.location.serviceStatus;
      if (mounted && status != locationServiceStatus) {
        setState(() => locationServiceStatus = status);
      }
    });
  }

  Future<void> _runStartupSequence() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.notification,
    ].request();
    locationServiceStatus = await Permission.location.serviceStatus;
    if (adapterState == BluetoothAdapterState.on &&
        locationServiceStatus == ServiceStatus.enabled) {
      startScan();
    }
  }

  void startScan() async {
    if (isScanning) return;
    setState(() {
      scanResults.clear();
      isScanning = true;
      _animationController.repeat();
    });
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) setState(() => scanResults = results);
    });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
          _animationController.stop();
        });
      }
    }
  }

  @override
  void dispose() {
    adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _animationController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var sorted = List<ScanResult>.from(scanResults)
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text("Vitals Scanner"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kNavy, Color(0xFF0D2040)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Header Banner ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kNavy, kBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.monitor_heart, color: kAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Neonatal Monitor",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "BLUETOOTH DEVICE SCANNER",
                      style: TextStyle(
                        color: kAccent,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Alerts ───────────────────────────────────────
          if (adapterState != BluetoothAdapterState.on)
            _alertBanner(
              Icons.bluetooth_disabled,
              "Bluetooth is Off",
              null,
              "Fix",
                  () => FlutterBluePlus.turnOn(),
            ),
          if (locationServiceStatus != ServiceStatus.enabled)
            _alertBanner(
              Icons.location_off,
              "Location (GPS) is Off",
              "Required for Bluetooth scanning",
              "GPS Required",
              null,
            ),

          // ── Device List ───────────────────────────────────
          Expanded(
            child: sorted.isEmpty
                ? Center(
              child: isScanning
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(kBlue),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Scanning for devices...",
                    style: TextStyle(
                        color: kBlue, fontWeight: FontWeight.w600),
                  ),
                ],
              )
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: kBluePale,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bluetooth_searching,
                        color: kBlue, size: 40),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "No devices found",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Tap scan to search nearby devices",
                    style:
                    TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: sorted.length,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              itemBuilder: (context, index) {
                final r = sorted[index];
                // Try to get name from platformName or advertisementData
                String deviceName = r.device.platformName.isNotEmpty 
                    ? r.device.platformName
                    : r.advertisementData.advName.isNotEmpty
                        ? r.advertisementData.advName
                        : _extractDeviceNameFromAdvertisement(r);
                
                // Fallback to MAC address if no name found
                if (deviceName.isEmpty) {
                  deviceName = r.device.remoteId.str;
                }
                return _deviceCard(r, deviceName);
              },
            ),
          ),

          // ── Buttons ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: isScanning ? null : startScan,
                  icon: isScanning
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.refresh),
                  label: Text(isScanning ? "Scanning..." : "Scan for Devices"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const ECGMonitorScreen(device: null),
                    ),
                  ),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text("Open Patient Simulator"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlue,
                    side: const BorderSide(color: kBlue, width: 1.5),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertBanner(IconData icon, String title, String? subtitle,
      String btnLabel, VoidCallback? onPressed) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade600, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade800,
                        fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.red.shade500)),
              ],
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: Text(btnLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _extractDeviceNameFromAdvertisement(ScanResult r) {
    // Try to extract name from manufacturer data or service data
    try {
      // Check manufacturer data
      if (r.advertisementData.manufacturerData.isNotEmpty) {
        // Some devices include name in manufacturer data
        var mfgData = r.advertisementData.manufacturerData;
        // Try first entry
        if (mfgData.isNotEmpty) {
          final firstEntry = mfgData.entries.first;
          // Some manufacturer data contains readable names
          if (firstEntry.value.isNotEmpty) {
            final name = String.fromCharCodes(firstEntry.value)
                .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
            if (name.isNotEmpty) {
              return name;
            }
          }
        }
      }
      
      // Check service data
      if (r.advertisementData.serviceData.isNotEmpty) {
        // Some devices have readable info in service data
        var serviceData = r.advertisementData.serviceData;
        if (serviceData.isNotEmpty) {
          final firstEntry = serviceData.entries.first;
          if (firstEntry.value.isNotEmpty) {
            final name = String.fromCharCodes(firstEntry.value)
                .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
            if (name.isNotEmpty) {
              return name;
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore parsing errors
    }
    
    return "";
  }

  Widget _deviceCard(ScanResult r, String name) {
    int rssi = r.rssi;
    Color signalColor = rssi > -60
        ? Colors.green
        : rssi > -80
        ? Colors.orange
        : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorder),
        boxShadow: [
          BoxShadow(
            color: kBlue.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kBluePale,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.bluetooth, color: kBlue, size: 22),
        ),
        title: Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: kNavy, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.device.remoteId.str, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, size: 14, color: signalColor),
                const SizedBox(width: 4),
                Text("$rssi dBm",
                    style: TextStyle(fontSize: 12, color: signalColor)),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kBluePale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_forward_ios, size: 14, color: kBlue),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ECGMonitorScreen(device: r.device),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ALERT MODEL
// ─────────────────────────────────────────────────────────────
class VitalAlert {
  final String title;
  final String message;
  final DateTime time;
  VitalAlert({required this.title, required this.message, required this.time});
}

// ─────────────────────────────────────────────────────────────
//  ECG MONITOR SCREEN
// ─────────────────────────────────────────────────────────────
class ECGMonitorScreen extends StatefulWidget {
  final BluetoothDevice? device;
  const ECGMonitorScreen({super.key, this.device});

  @override
  State<ECGMonitorScreen> createState() => _ECGMonitorScreenState();
}

class _ECGMonitorScreenState extends State<ECGMonitorScreen> {
  List<FlSpot> points = [];
  double xCounter = 0;

  double? temp;
  double? hum;
  double? respRate;
  int? bpm;

  double minNormalTemp = 36.0;
  double maxNormalTemp = 38.0;
  int minNormalBpm = 60;
  int maxNormalBpm = 100;
  double minNormalHum = 40.0;
  double maxNormalHum = 60.0;
  double minNormalResp = 30.0;
  double maxNormalResp = 60.0;

  double? jaundiceLevel;
  DateTime? lastJaundiceAlert;
  double minJaundiceThreshold = 1050.0;
  double maxJaundiceThreshold = 1250.0;

  bool isConnected = false;
  bool isDemo = false;
  Timer? timer;
  String buffer = "";

  // ── Active alerts list ─────────────────────────────────────
  final List<VitalAlert> activeAlerts = [];

  DateTime? lastTempLowAlert;
  DateTime? lastTempHighAlert;
  DateTime? lastBpmAlert;
  DateTime? lastHumAlert;
  DateTime? lastRespAlert;

  BluetoothCharacteristic? _writeChar;

  // ── Jaundice treatment (replaces heater) ──────────────────
  bool jaundiceTreatmentOn = false;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _connect();
    } else {
      isDemo = true;
      _startSim();
    }
  }

  void _startSim() {
    timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      double v = 500 + Random().nextDouble() * 20;
      if (t.tick % 15 == 0) v += 400;
      if (t.tick % 15 == 1) v -= 250;
      _addPoint(v);
      if (t.tick % 30 == 0) {
        setState(() {
          temp = 35 + Random().nextDouble() * 5;
          bpm = 50 + Random().nextInt(70);
          hum = 40 + Random().nextDouble() * 20;
          respRate = 25 + Random().nextDouble() * 40;
          jaundiceLevel = 1050 + Random().nextDouble() * 200;
        });
        _checkAlerts();
      }
    });
  }

  void _addPoint(double v) {
    if (mounted) {
      setState(() {
        points.add(FlSpot(xCounter++, v));
        if (points.length > 80) points.removeAt(0);
      });
    }
  }

  Future<void> _sendCommand(String cmd) async {
    if (_writeChar != null) {
      try {
        await _writeChar!.write(utf8.encode("$cmd\n"));
      } catch (_) {}
    }
  }

  void _addAlert(String title, String message) {
    setState(() {
      activeAlerts.insert(
          0, VitalAlert(title: title, message: message, time: DateTime.now()));
      // Keep only last 10 alerts
      if (activeAlerts.length > 10) activeAlerts.removeLast();
    });
  }

  void _checkAlerts() {
    final now = DateTime.now();

    // ── Temperature ──────────────────────────────────────────
    if (temp != null) {
      if (temp! < minNormalTemp &&
          (lastTempLowAlert == null ||
              now.difference(lastTempLowAlert!).inSeconds > 20)) {
        _notify("🔴 Low Temperature",
            "Temp is low: ${temp!.toStringAsFixed(1)}°C");
        _addAlert("🌡️ Low Temperature",
            "Temp: ${temp!.toStringAsFixed(1)}°C — below normal");
        lastTempLowAlert = now;
      } else if (temp! > maxNormalTemp &&
          (lastTempHighAlert == null ||
              now.difference(lastTempHighAlert!).inSeconds > 20)) {
        _notify("🌡️ High Temperature",
            "Temperature above normal: ${temp!.toStringAsFixed(1)}°C");
        _addAlert("🌡️ High Temperature",
            "Temp: ${temp!.toStringAsFixed(1)}°C — above normal");
        lastTempHighAlert = now;
      }
    }

    // ── BPM ──────────────────────────────────────────────────
    if (bpm != null &&
        (bpm! < minNormalBpm || bpm! > maxNormalBpm) &&
        (lastBpmAlert == null ||
            now.difference(lastBpmAlert!).inSeconds > 20)) {
      _notify("Abnormal Heart Rate", "BPM out of range: $bpm");
      _addAlert("❤️ Abnormal Heart Rate", "BPM: $bpm — out of normal range");
      lastBpmAlert = now;
    }

    // ── Humidity ─────────────────────────────────────────────
    if (hum != null &&
        (hum! < minNormalHum || hum! > maxNormalHum) &&
        (lastHumAlert == null ||
            now.difference(lastHumAlert!).inSeconds > 20)) {
      _notify("Humidity Alert",
          "Humidity out of range: ${hum!.toStringAsFixed(0)}%");
      _addAlert("💧 Humidity Alert",
          "Humidity: ${hum!.toStringAsFixed(0)}% — out of range");
      lastHumAlert = now;
    }

    // ── Respiration ──────────────────────────────────────────
    if (respRate != null &&
        respRate! < minNormalResp &&
        (lastRespAlert == null ||
            now.difference(lastRespAlert!).inSeconds > 20)) {
      _notify("Possible Apnea",
          "Resp rate low: ${respRate!.toStringAsFixed(0)} breaths/min");
      _addAlert("🫁 Possible Apnea",
          "Resp: ${respRate!.toStringAsFixed(0)} breaths/min — low");
      lastRespAlert = now;
    }

    // ── Jaundice ─────────────────────────────────────────────
    if (jaundiceLevel != null &&
        (jaundiceLevel! < minJaundiceThreshold || jaundiceLevel! > maxJaundiceThreshold) &&
        (lastJaundiceAlert == null ||
            now.difference(lastJaundiceAlert!).inSeconds > 20)) {
      String msg = jaundiceLevel! < minJaundiceThreshold ? "Low" : "High";
      _notify("⚠️ Jaundice Alert",
          "Jaundice $msg: ${jaundiceLevel!.toStringAsFixed(1)}");
      _addAlert("⚠️ Jaundice Alert",
          "Level: ${jaundiceLevel!.toStringAsFixed(1)} — outside normal range (1050-1250)");
      lastJaundiceAlert = now;
    }
  }

  Future<void> _notify(String t, String b) async {
    const details = AndroidNotificationDetails(
      'vitals',
      'Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    await flutterLocalNotificationsPlugin.show(
        0, t, b, const NotificationDetails(android: details));
  }

  void _connect() async {
    widget.device!.connectionState.listen(
          (s) => setState(
              () => isConnected = s == BluetoothConnectionState.connected),
    );
    await widget.device!.connect();
    final svcs = await widget.device!.discoverServices();
    for (var s in svcs) {
      for (var c in s.characteristics) {
        if ((c.properties.write || c.properties.writeWithoutResponse) &&
            _writeChar == null) {
          _writeChar = c;
        }
        if (c.properties.notify) {
          await c.setNotifyValue(true);
          c.onValueReceived.listen((v) {
            buffer += utf8.decode(v);
            while (buffer.contains("\n")) {
              final line =
              buffer.substring(0, buffer.indexOf("\n")).trim();
              buffer = buffer.substring(buffer.indexOf("\n") + 1);
              if (line.isNotEmpty) _process(line);
            }
          });
        }
      }
    }
  }

  void _process(String s) {
    if (s.startsWith("T:")) {
      setState(() => temp = double.tryParse(s.substring(2)) ?? temp);
      _checkAlerts();
    } else if (s.startsWith("B:")) {
      setState(() => bpm = int.tryParse(s.substring(2)) ?? bpm);
      _checkAlerts();
    } else if (s.startsWith("H:")) {
      setState(() => hum = double.tryParse(s.substring(2)) ?? hum);
      _checkAlerts();
    } else if (s.startsWith("R:")) {
      setState(
              () => respRate = double.tryParse(s.substring(2)) ?? respRate);
      _checkAlerts();
    } else if (s.startsWith("J:")) {
      setState(
              () => jaundiceLevel =
              double.tryParse(s.substring(2)) ?? jaundiceLevel);
      _checkAlerts();
    } else if (s == "CMD:JAUNDICE_AUTO_ON") {
      setState(() => jaundiceTreatmentOn = true);
    } else if (s == "CMD:JAUNDICE_AUTO_OFF") {
      setState(() => jaundiceTreatmentOn = false);
    } else {
      final v = double.tryParse(s);
      if (v != null) _addPoint(v);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.device?.disconnect();
    super.dispose();
  }

  // ── Vital status helpers ──────────────────────────────────

  bool get isTempAbnormal =>
      temp != null && (temp! < minNormalTemp || temp! > maxNormalTemp);

  bool get isBpmAbnormal =>
      bpm != null && (bpm! < minNormalBpm || bpm! > maxNormalBpm);

  bool get isHumAbnormal =>
      hum != null && (hum! < minNormalHum || hum! > maxNormalHum);

  bool get isRespAbnormal =>
      respRate != null && respRate! < minNormalResp;

  bool get isJaundiceAbnormal =>
      jaundiceLevel != null &&
          (jaundiceLevel! < minJaundiceThreshold || jaundiceLevel! > maxJaundiceThreshold);

  bool get hasAnyAlert =>
      isTempAbnormal || isBpmAbnormal || isHumAbnormal ||
          isRespAbnormal || isJaundiceAbnormal;

  String getBabyStatus() {
    if (temp == null || bpm == null || hum == null) return "Waiting...";
    int dangerCount = 0;
    if (temp! > maxNormalTemp + 1 || temp! < minNormalTemp - 1) dangerCount++;
    if (bpm! > maxNormalBpm + 20 || bpm! < minNormalBpm - 10) dangerCount++;
    if (hum! > maxNormalHum + 10 || hum! < minNormalHum - 10) dangerCount++;
    if (isJaundiceAbnormal) dangerCount++;
    if (dangerCount > 0) return "DANGER";
    if (isTempAbnormal || isBpmAbnormal || isHumAbnormal || isJaundiceAbnormal) {
      return "WARNING";
    }
    return "NORMAL";
  }

  Color getStatusColor() {
    switch (getBabyStatus()) {
      case "DANGER":
        return Colors.red;
      case "WARNING":
        return Colors.orange;
      case "NORMAL":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) {
        double tMin = minNormalTemp;
        double tMax = maxNormalTemp;
        int bMin = minNormalBpm;
        int bMax = maxNormalBpm;
        double hMin = minNormalHum;
        double hMax = maxNormalHum;
        double rMin = minNormalResp;
        double rMax = maxNormalResp;
        double jMin = minJaundiceThreshold;
        double jMax = maxJaundiceThreshold;


        InputDecoration inputDec(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kBlue),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kBlue),
          ),
          border: const OutlineInputBorder(),
          isDense: true,
        );

        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Set Normal Thresholds",
              style: TextStyle(
                  color: kNavy, fontWeight: FontWeight.w800, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _settingLabel("Temperature Range (°C)"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) =>
                          tMin = double.tryParse(v) ?? tMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) =>
                          tMax = double.tryParse(v) ?? tMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("BPM Range"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) =>
                          bMin = int.tryParse(v) ?? bMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) =>
                          bMax = int.tryParse(v) ?? bMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("Humidity Range (%)"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) =>
                          hMin = double.tryParse(v) ?? hMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) =>
                          hMax = double.tryParse(v) ?? hMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("Respiration Rate (breaths/min)"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) =>
                          rMin = double.tryParse(v) ?? rMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) =>
                          rMax = double.tryParse(v) ?? rMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("Jaundice Range"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) =>
                          jMin = double.tryParse(v) ?? jMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) =>
                          jMax = double.tryParse(v) ?? jMax)),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel",
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  minNormalTemp = tMin;
                  maxNormalTemp = tMax;
                  minNormalBpm = bMin;
                  maxNormalBpm = bMax;
                  minNormalHum = hMin;
                  maxNormalHum = hMax;
                  minNormalResp = rMin;
                  maxNormalResp = rMax;
                  minJaundiceThreshold = jMin;
                  maxJaundiceThreshold = jMax;

                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _settingLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kNavy,
            letterSpacing: 0.3)),
  );

  // ─── Stat Card — turns red when abnormal ─────────────────
  Widget _statCard(
      String label, String val, IconData icon, Color normalColor,
      bool isAbnormal) {
    final cardBg = isAbnormal ? Colors.red.shade50 : Colors.white;
    final borderColor =
    isAbnormal ? Colors.red.shade300 : kCardBorder;
    final iconBg = isAbnormal ? Colors.red.shade100 : kBluePale;
    final iconColor = isAbnormal ? Colors.red.shade700 : normalColor;
    final valColor = isAbnormal ? Colors.red.shade800 : kNavy;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: borderColor, width: isAbnormal ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: isAbnormal
                  ? Colors.red.withOpacity(0.12)
                  : kBlue.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (isAbnormal)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isAbnormal
                        ? Colors.red.shade400
                        : Colors.grey,
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(val,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valColor)),
            if (isAbnormal)
              const SizedBox(height: 2),
            if (isAbnormal)
              Text(
                "ALERT",
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade600,
                    letterSpacing: 1.0),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Respiration Card ─────────────────────────────────────
  Widget _respirationCard() {
    final isAbnormal = isRespAbnormal;
    final borderColor =
    isAbnormal ? Colors.red.shade300 : kCardBorder;
    final cardBg = isAbnormal ? Colors.red.shade50 : Colors.white;
    final iconBg = isAbnormal ? Colors.red.shade100 : kBluePale;
    final iconColor =
    isAbnormal ? Colors.red.shade700 : kBlueLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: borderColor, width: isAbnormal ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isAbnormal
                ? Colors.red.withOpacity(0.10)
                : kBlue.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.air, color: iconColor, size: 20),
              ),
              if (isAbnormal)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Respiration Rate",
                    style: TextStyle(
                        fontSize: 11,
                        color: isAbnormal
                            ? Colors.red.shade400
                            : Colors.grey)),
                Text(
                  respRate != null
                      ? "${respRate!.toStringAsFixed(0)} breaths/min"
                      : "Waiting...",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isAbnormal
                          ? Colors.red.shade800
                          : kNavy),
                ),
              ],
            ),
          ),
          if (isAbnormal)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("ALERT",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade700,
                      letterSpacing: 0.8)),
            ),
        ],
      ),
    );
  }

  // ─── Jaundice Card ────────────────────────────────────────
  Widget _jaundiceCard() {
    bool isHigh = isJaundiceAbnormal;
    bool inRange = jaundiceLevel != null &&
        jaundiceLevel! >= minJaundiceThreshold &&
        jaundiceLevel! <= maxJaundiceThreshold;

    Color cardColor = jaundiceLevel == null
        ? Colors.grey
        : (inRange ? Colors.red : Colors.green.shade600);

    String statusLabel = jaundiceLevel == null
        ? "No Data"
        : (inRange ? "abnormal" : "Normal");


    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: cardColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.colorize, color: cardColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Jaundice Indicator",
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  jaundiceLevel != null
                      ? "${jaundiceLevel!.toStringAsFixed(1)} — $statusLabel"
                      : "Waiting...",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cardColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Jaundice Treatment Card (replaces Heater) ────────────
  Widget _jaundiceTreatmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: jaundiceTreatmentOn
            ? Colors.amber.withOpacity(0.10)
            : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: jaundiceTreatmentOn
                ? Colors.amber.withOpacity(0.5)
                : Colors.grey.withOpacity(0.25),
            width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: jaundiceTreatmentOn
                  ? Colors.amber.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.wb_sunny_rounded,
                color: jaundiceTreatmentOn
                    ? Colors.amber.shade700
                    : Colors.grey,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Jaundice Treatment",
                  style: TextStyle(
                      fontSize: 11,
                      color: jaundiceTreatmentOn
                          ? Colors.amber.shade700
                          : Colors.grey),
                ),
                Text(
                  jaundiceTreatmentOn
                      ? "💡 Phototherapy: ON"
                      : "Phototherapy: OFF",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: jaundiceTreatmentOn
                          ? Colors.amber.shade800
                          : Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Alert Banner (top of screen) ────────────────────────
  Widget _activeAlertBanner() {
    if (!hasAnyAlert) return const SizedBox.shrink();

    final List<String> issues = [];
    if (isTempAbnormal) issues.add("Temp");
    if (isBpmAbnormal) issues.add("BPM");
    if (isHumAbnormal) issues.add("Humidity");
    if (isRespAbnormal) issues.add("Respiration");
    if (isJaundiceAbnormal) issues.add("Jaundice");

    return GestureDetector(
      onTap: () => _showAlertLog(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "⚠️  ALERTS: ${issues.join(' · ')}",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5),
              ),
            ),
            const Text("Details",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    decoration: TextDecoration.underline)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Alert Log Dialog ─────────────────────────────────────
  void _showAlertLog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
              mainAxisAlignment: MainAxisAlignment.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.notifications_active,
                    color: Colors.red.shade600, size: 22),
                const SizedBox(width: 8),
                Text("Alert Log",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade800)),
                const Spacer(),
                if (activeAlerts.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => activeAlerts.clear());
                      Navigator.pop(context);
                    },
                    child: Text("Clear all",
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            activeAlerts.isEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text("No alerts",
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14)),
              ),
            )
                : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: activeAlerts.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (context, i) {
                  final alert = activeAlerts[i];
                  final timeStr =
                      "${alert.time.hour.toString().padLeft(2, '0')}:${alert.time.minute.toString().padLeft(2, '0')}:${alert.time.second.toString().padLeft(2, '0')}";
                  return Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(alert.title,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Colors.red.shade800)),
                              const SizedBox(height: 2),
                              Text(alert.message,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                      Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Text(timeStr,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    double minX = points.isEmpty ? 0 : points.first.x;
    double maxX = max(60.0, xCounter);
    if (points.length >= 60) {
      minX = points.first.x;
      maxX = points.last.x;
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(isDemo ? "Patient Simulator" : "Live Monitor"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kNavy, kBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Alert bell icon with badge
          Stack(
            children: [
              IconButton(
                onPressed: activeAlerts.isNotEmpty ? _showAlertLog : null,
                icon: Icon(
                  activeAlerts.isNotEmpty
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color: activeAlerts.isNotEmpty
                      ? Colors.red.shade300
                      : Colors.white,
                ),
                tooltip: "Alert Log",
              ),
              if (activeAlerts.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        activeAlerts.length > 9
                            ? "9+"
                            : "${activeAlerts.length}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_rounded),
            tooltip: "Settings",
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Active Alert Banner (sticky top) ───────────────
          _activeAlertBanner(),

          // ── Scrollable content ────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // ── Patient Header ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kNavy, kBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: kBlue.withOpacity(0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.child_care,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Neonatal Patient",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "REAL-TIME VITALS MONITORING",
                                style: TextStyle(
                                  color: kAccent,
                                  fontSize: 11,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: getStatusColor().withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: getStatusColor().withOpacity(0.7),
                                width: 1.5),
                          ),
                          child: Text(
                            getBabyStatus(),
                            style: TextStyle(
                                color: getStatusColor() == Colors.green
                                    ? Colors.greenAccent.shade100
                                    : getStatusColor() == Colors.orange
                                    ? Colors.orange.shade200
                                    : Colors.red.shade200,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Stat Cards ──────────────────────────────────
                  Row(
                    children: [
                      _statCard(
                          "Temp",
                          temp != null
                              ? "${temp!.toStringAsFixed(1)}°C"
                              : "--",
                          Icons.thermostat,
                          Colors.deepOrange,
                          isTempAbnormal),
                      const SizedBox(width: 10),
                      _statCard(
                          "BPM",
                          bpm != null ? "$bpm" : "--",
                          Icons.favorite_rounded,
                          Colors.redAccent,
                          isBpmAbnormal),
                      const SizedBox(width: 10),
                      _statCard(
                          "Humidity",
                          hum != null
                              ? "${hum!.toStringAsFixed(0)}%"
                              : "--",
                          Icons.water_drop,
                          kBlueLight,
                          isHumAbnormal),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Respiration Card ─────────────────────────────
                  _respirationCard(),
                  const SizedBox(height: 10),

                  // ── Jaundice Card ────────────────────────────────
                  _jaundiceCard(),
                  const SizedBox(height: 14),

                  // ── Connection Status Bar ────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected || isDemo
                              ? Colors.green
                              : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isConnected || isDemo
                                  ? Colors.green
                                  : Colors.red)
                                  .withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isConnected || isDemo
                            ? "RECEIVING DATA"
                            : "OFFLINE",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: isConnected || isDemo
                                ? Colors.green.shade700
                                : Colors.red.shade700),
                      ),
                      const Spacer(),
                      if (isDemo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kBluePale,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kCardBorder),
                          ),
                          child: const Text("SIMULATION MODE",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: kBlue,
                                  letterSpacing: 0.8)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── ECG Chart ────────────────────────────────────
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: kNavy,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: kAccent.withOpacity(0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: kNavy.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 12,
                            left: 16,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: kAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "ECG — Real-time",
                                  style: TextStyle(
                                      color: kAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(0, 36, 0, 8),
                            child: LineChart(
                              duration: Duration.zero,
                              LineChartData(
                                minY: 0,
                                maxY: 1024,
                                minX: minX,
                                maxX: maxX,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: points,
                                    isCurved: false,
                                    color: kAccent,
                                    barWidth: 2.5,
                                    dotData:
                                    const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: kAccent.withOpacity(0.06),
                                    ),
                                  ),
                                ],
                                titlesData:
                                const FlTitlesData(show: false),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  getDrawingHorizontalLine: (v) =>
                                      FlLine(
                                          color:
                                          kAccent.withOpacity(0.10),
                                          strokeWidth: 1),
                                  getDrawingVerticalLine: (v) => FlLine(
                                      color: kAccent.withOpacity(0.10),
                                      strokeWidth: 1),
                                ),
                                borderData: FlBorderData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Real-time Electrocardiogram",
                    style: TextStyle(
                        color: kAccent,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
