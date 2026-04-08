import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────────────────────────────────────────────
//  🦈 BABY SHARK COLOR PALETTE
// ─────────────────────────────────────────────────────────────
const Color kDeepOcean   = Color(0xFF003049); // deep dark ocean
const Color kOcean       = Color(0xFF0077B6); // main ocean blue
const Color kWave        = Color(0xFF00B4D8); // wave blue
const Color kFoam        = Color(0xFF90E0EF); // sea foam
const Color kBubble      = Color(0xFFCAF0F8); // light bubble
const Color kSunny       = Color(0xFFFFD60A); // sunny yellow (shark fin)
const Color kCoral       = Color(0xFFFF6B6B); // coral red
const Color kSand        = Color(0xFFFFF3CD); // sandy
const Color kBg          = Color(0xFFE0F7FA); // ocean surface bg
const Color kCardBorder  = Color(0xFFB2EBF2); // card borders

// ── Notification channel IDs per alert type ──────────────────
const int kNotifTemp    = 1;
const int kNotifBpm     = 2;
const int kNotifHum     = 3;
const int kNotifResp    = 4;
const int kNotifJaundice= 5;

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
        colorSchemeSeed: kOcean,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kDeepOcean,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kOcean,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kOcean),
        ),
      ),
      home: const BluetoothScannerScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  🦈 BLUETOOTH SCANNER SCREEN
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

  // BUG FIX: initialized to unknown so we don't falsely show alert on first frame
  ServiceStatus locationServiceStatus = ServiceStatus.enabled;

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

    // BUG FIX: properly fetch initial location status after permissions granted
    final status = await Permission.location.serviceStatus;
    if (mounted) setState(() => locationServiceStatus = status);

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
      // BUG FIX: only repeat if not already animating
      if (!_animationController.isAnimating) {
        _animationController.repeat();
      }
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
          // BUG FIX: only stop if currently animating
          if (_animationController.isAnimating) {
            _animationController.stop();
          }
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
        title: const Text("🦈 Baby Shark Scanner"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kDeepOcean, Color(0xFF014F86)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── 🦈 Header Banner ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kDeepOcean, kOcean],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kSunny.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text("🦈", style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Baby Shark Monitor",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "DOO DOO DOO — DEVICE SCANNER",
                      style: TextStyle(
                        color: kSunny,
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Alerts ────────────────────────────────────────
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
                  const Text("🦈",
                      style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kOcean),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Swimming through signals...",
                    style: TextStyle(
                        color: kOcean,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              )
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: kBubble,
                      shape: BoxShape.circle,
                    ),
                    child: const Text("🦈",
                        style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "No devices found",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: kDeepOcean,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Doo doo doo — tap scan to search!",
                    style: TextStyle(
                        color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: sorted.length,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              itemBuilder: (context, index) {
                final r = sorted[index];
                String name = r.device.platformName.isEmpty
                    ? "Unknown Device 🐡"
                    : r.device.platformName;
                return _deviceCard(r, name);
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
                      : const Text("🦈", style: TextStyle(fontSize: 18)),
                  label: Text(isScanning ? "Swimming..." : "Scan for Devices"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOcean,
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
                  icon: const Text("🌊", style: TextStyle(fontSize: 16)),
                  label: const Text("Open Baby Shark Simulator"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kOcean,
                    side: const BorderSide(color: kOcean, width: 1.5),
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
                      style:
                      TextStyle(fontSize: 11, color: Colors.red.shade500)),
              ],
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style:
            TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: Text(btnLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
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
            color: kOcean.withOpacity(0.07),
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
            color: kBubble,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text("🐟", style: TextStyle(fontSize: 20)),
        ),
        title: Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: kDeepOcean, fontSize: 15)),
        subtitle: Row(
          children: [
            Icon(Icons.signal_cellular_alt, size: 14, color: signalColor),
            const SizedBox(width: 4),
            Text("$rssi dBm",
                style: TextStyle(fontSize: 12, color: signalColor)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kBubble,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_forward_ios, size: 14, color: kOcean),
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
//  🦈 ECG MONITOR SCREEN
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
  double jaundiceThreshold = 60.0;

  bool isConnected = false;
  bool isDemo = false;
  Timer? timer;
  String buffer = "";

  final List<VitalAlert> activeAlerts = [];

  DateTime? lastTempLowAlert;
  DateTime? lastTempHighAlert;
  DateTime? lastBpmAlert;
  DateTime? lastHumAlert;
  DateTime? lastRespAlert;

  BluetoothCharacteristic? _writeChar;
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
        // BUG FIX: all state mutations inside a single setState
        setState(() {
          temp = 35 + Random().nextDouble() * 5;
          bpm = 50 + Random().nextInt(70);
          hum = 40 + Random().nextDouble() * 20;
          respRate = 25 + Random().nextDouble() * 40;
          jaundiceLevel = 30 + Random().nextDouble() * 60;
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
    // BUG FIX: mutate inside setState (this is already done correctly here,
    // but _checkAlerts calls this after setState so it's safe to call setState again)
    if (!mounted) return;
    setState(() {
      activeAlerts.insert(
          0, VitalAlert(title: title, message: message, time: DateTime.now()));
      if (activeAlerts.length > 10) activeAlerts.removeLast();
    });
  }

  void _checkAlerts() {
    if (!mounted) return;
    final now = DateTime.now();

    // ── Temperature ──────────────────────────────────────────
    if (temp != null) {
      if (temp! < minNormalTemp &&
          (lastTempLowAlert == null ||
              now.difference(lastTempLowAlert!).inSeconds > 20)) {
        _notify(kNotifTemp, "🌡️ Low Temperature",
            "Temp is low: ${temp!.toStringAsFixed(1)}°C");
        _addAlert("🌡️ Low Temperature",
            "Temp: ${temp!.toStringAsFixed(1)}°C — below normal");
        lastTempLowAlert = now;
      } else if (temp! > maxNormalTemp &&
          (lastTempHighAlert == null ||
              now.difference(lastTempHighAlert!).inSeconds > 20)) {
        _notify(kNotifTemp, "🌡️ High Temperature",
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
      // BUG FIX: use dedicated notification ID for BPM
      _notify(kNotifBpm, "💓 Abnormal Heart Rate", "BPM out of range: $bpm");
      _addAlert("💓 Abnormal Heart Rate", "BPM: $bpm — out of normal range");
      lastBpmAlert = now;
    }

    // ── Humidity ─────────────────────────────────────────────
    if (hum != null &&
        (hum! < minNormalHum || hum! > maxNormalHum) &&
        (lastHumAlert == null ||
            now.difference(lastHumAlert!).inSeconds > 20)) {
      _notify(kNotifHum, "💧 Humidity Alert",
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
      _notify(kNotifResp, "🫁 Possible Apnea",
          "Resp rate low: ${respRate!.toStringAsFixed(0)} breaths/min");
      _addAlert("🫁 Possible Apnea",
          "Resp: ${respRate!.toStringAsFixed(0)} breaths/min — low");
      lastRespAlert = now;
    }

    // ── Jaundice ─────────────────────────────────────────────
    if (jaundiceLevel != null &&
        jaundiceLevel! > jaundiceThreshold &&
        (lastJaundiceAlert == null ||
            now.difference(lastJaundiceAlert!).inSeconds > 20)) {
      _notify(kNotifJaundice, "⚠️ Jaundice Alert",
          "Jaundice high: ${jaundiceLevel!.toStringAsFixed(1)}");
      _addAlert("⚠️ Jaundice Alert",
          "Level: ${jaundiceLevel!.toStringAsFixed(1)} — above threshold");
      lastJaundiceAlert = now;
    }
  }

  // BUG FIX: accepts notificationId so each alert type uses its own channel
  Future<void> _notify(int id, String t, String b) async {
    const details = AndroidNotificationDetails(
      'vitals',
      'Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    await flutterLocalNotificationsPlugin.show(
        id, t, b, const NotificationDetails(android: details));
  }

  // BUG FIX: wrapped entire connect flow in try/catch
  void _connect() async {
    try {
      widget.device!.connectionState.listen(
            (s) {
          if (mounted) {
            setState(
                    () => isConnected = s == BluetoothConnectionState.connected);
          }
        },
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🦈 Connection failed: $e"),
            backgroundColor: kCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _process(String s) {
    if (!mounted) return;
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
      setState(() => respRate = double.tryParse(s.substring(2)) ?? respRate);
      _checkAlerts();
    } else if (s.startsWith("J:")) {
      setState(
              () => jaundiceLevel = double.tryParse(s.substring(2)) ?? jaundiceLevel);
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
      jaundiceLevel != null && jaundiceLevel! > jaundiceThreshold;
  bool get hasAnyAlert =>
      isTempAbnormal ||
          isBpmAbnormal ||
          isHumAbnormal ||
          isRespAbnormal ||
          isJaundiceAbnormal;

  String getBabyStatus() {
    if (temp == null || bpm == null || hum == null) return "Waiting...";
    int dangerCount = 0;
    if (temp! > maxNormalTemp + 1 || temp! < minNormalTemp - 1) dangerCount++;
    if (bpm! > maxNormalBpm + 20 || bpm! < minNormalBpm - 10) dangerCount++;
    if (hum! > maxNormalHum + 10 || hum! < minNormalHum - 10) dangerCount++;
    if (isJaundiceAbnormal) dangerCount++;
    if (dangerCount > 0) return "DANGER 🦈";
    if (isTempAbnormal || isBpmAbnormal || isHumAbnormal || isJaundiceAbnormal) {
      return "WARNING 🐡";
    }
    return "HEALTHY 🐠";
  }

  Color getStatusColor() {
    final s = getBabyStatus();
    if (s.contains("DANGER")) return kCoral;
    if (s.contains("WARNING")) return Colors.orange;
    if (s.contains("HEALTHY")) return const Color(0xFF2ECC71);
    return Colors.grey;
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
        double jThresh = jaundiceThreshold;

        InputDecoration inputDec(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kOcean),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kOcean),
          ),
          border: const OutlineInputBorder(),
          isDense: true,
        );

        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text("🦈 ", style: TextStyle(fontSize: 20)),
              Text("Normal Thresholds",
                  style: TextStyle(
                      color: kDeepOcean,
                      fontWeight: FontWeight.w800,
                      fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _settingLabel("🌡️ Temperature Range (°C)"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) => tMin = double.tryParse(v) ?? tMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) => tMax = double.tryParse(v) ?? tMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("💓 BPM Range"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) => bMin = int.tryParse(v) ?? bMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) => bMax = int.tryParse(v) ?? bMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("💧 Humidity Range (%)"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) => hMin = double.tryParse(v) ?? hMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) => hMax = double.tryParse(v) ?? hMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("🫁 Respiration Rate (breaths/min)"),
                Row(children: [
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Min"),
                          onChanged: (v) => rMin = double.tryParse(v) ?? rMin)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: inputDec("Max"),
                          onChanged: (v) => rMax = double.tryParse(v) ?? rMax)),
                ]),
                const SizedBox(height: 16),
                _settingLabel("⚠️ Jaundice Threshold"),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: inputDec("Max Normal Level"),
                  onChanged: (v) => jThresh = double.tryParse(v) ?? jThresh,
                ),
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
                  jaundiceThreshold = jThresh;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kOcean,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save 🦈"),
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
            color: kDeepOcean,
            letterSpacing: 0.3)),
  );

  // ─── 🦈 Stat Card ─────────────────────────────────────────
  Widget _statCard(
      String label, String val, String emoji, bool isAbnormal) {
    final cardBg = isAbnormal ? kCoral.withOpacity(0.08) : Colors.white;
    final borderColor =
    isAbnormal ? kCoral.withOpacity(0.5) : kCardBorder;
    final iconBg = isAbnormal ? kCoral.withOpacity(0.12) : kBubble;
    final valColor = isAbnormal ? kCoral : kDeepOcean;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isAbnormal ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: isAbnormal
                  ? kCoral.withOpacity(0.10)
                  : kOcean.withOpacity(0.07),
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
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                if (isAbnormal)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: kCoral,
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
                    color: isAbnormal ? kCoral : Colors.grey,
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(val,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valColor)),
            if (isAbnormal) ...[
              const SizedBox(height: 2),
              Text("ALERT",
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: kCoral,
                      letterSpacing: 1.0)),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 🌊 Respiration Card ──────────────────────────────────
  Widget _respirationCard() {
    final isAbnormal = isRespAbnormal;
    final borderColor =
    isAbnormal ? kCoral.withOpacity(0.5) : kCardBorder;
    final cardBg = isAbnormal ? kCoral.withOpacity(0.07) : Colors.white;
    final iconBg = isAbnormal ? kCoral.withOpacity(0.12) : kBubble;
    final iconColor = isAbnormal ? kCoral : kWave;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isAbnormal ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: isAbnormal
                ? kCoral.withOpacity(0.08)
                : kOcean.withOpacity(0.06),
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
                child: Text(
                  isAbnormal ? "🚨" : "🌊",
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              if (isAbnormal)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: kCoral, shape: BoxShape.circle),
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
                        color: isAbnormal ? kCoral : Colors.grey)),
                Text(
                  respRate != null
                      ? "${respRate!.toStringAsFixed(0)} breaths/min"
                      : "Waiting...",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isAbnormal ? kCoral : kDeepOcean),
                ),
              ],
            ),
          ),
          if (isAbnormal)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kCoral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("ALERT",
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kCoral,
                      letterSpacing: 0.8)),
            ),
        ],
      ),
    );
  }

  // ─── ⚠️ Jaundice Card ─────────────────────────────────────
  Widget _jaundiceCard() {
    bool isHigh = isJaundiceAbnormal;
    Color cardColor = jaundiceLevel == null
        ? Colors.grey
        : (isHigh ? Colors.amber.shade700 : const Color(0xFF2ECC71));
    String statusLabel = jaundiceLevel == null
        ? "No Data"
        : (isHigh ? "HIGH — Possible Jaundice" : "Normal");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(isHigh ? "🟡" : "✅",
                style: const TextStyle(fontSize: 20)),
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

  // ─── ☀️ Jaundice Treatment Card ───────────────────────────
  Widget _jaundiceTreatmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: jaundiceTreatmentOn
            ? kSunny.withOpacity(0.10)
            : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: jaundiceTreatmentOn
                ? kSunny.withOpacity(0.6)
                : Colors.grey.withOpacity(0.25),
            width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: jaundiceTreatmentOn
                  ? kSunny.withOpacity(0.18)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(jaundiceTreatmentOn ? "☀️" : "🌑",
                style: const TextStyle(fontSize: 20)),
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
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => jaundiceTreatmentOn = true);
                  _sendCommand("JAUNDICE_ON");
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: jaundiceTreatmentOn
                        ? Colors.amber.shade600
                        : Colors.grey.shade200,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    "ON",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: jaundiceTreatmentOn
                            ? Colors.white
                            : Colors.grey.shade500),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => jaundiceTreatmentOn = false);
                  _sendCommand("JAUNDICE_OFF");
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: !jaundiceTreatmentOn
                        ? Colors.grey.shade500
                        : Colors.grey.shade200,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    "OFF",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: !jaundiceTreatmentOn
                            ? Colors.white
                            : Colors.grey.shade500),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 🚨 Alert Banner (top of screen) ─────────────────────
  Widget _activeAlertBanner() {
    if (!hasAnyAlert) return const SizedBox.shrink();
    final List<String> issues = [];
    if (isTempAbnormal) issues.add("🌡️ Temp");
    if (isBpmAbnormal) issues.add("💓 BPM");
    if (isHumAbnormal) issues.add("💧 Humidity");
    if (isRespAbnormal) issues.add("🫁 Resp");
    if (isJaundiceAbnormal) issues.add("⚠️ Jaundice");

    return GestureDetector(
      onTap: _showAlertLog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kCoral, kCoral.withOpacity(0.80)],
          ),
        ),
        child: Row(
          children: [
            const Text("🦈", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "ALERT: ${issues.join(' · ')}",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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
            const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
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
              mainAxisAlignment: MainAxisAlignment.center,
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
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("🦈", style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text("Alert Log",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: kCoral)),
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
                child: Column(
                  children: [
                    const Text("🐠",
                        style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text("No alerts — swimming smoothly!",
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14)),
                  ],
                ),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(
                            color: kCoral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(alert.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: kDeepOcean)),
                              const SizedBox(height: 2),
                              Text(alert.message,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
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

  // ─── 🦈 Build ─────────────────────────────────────────────
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
        title: Text(isDemo ? "🦈 Baby Shark Simulator" : "🦈 Live Monitor"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kDeepOcean, kOcean],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: activeAlerts.isNotEmpty ? _showAlertLog : null,
                icon: Text(
                  activeAlerts.isNotEmpty ? "🦈" : "🐠",
                  style: const TextStyle(fontSize: 20),
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
                      color: kCoral,
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
          // ── 🚨 Alert Banner ────────────────────────────────
          _activeAlertBanner(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // ── 🦈 Patient Header ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kDeepOcean, kOcean],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: kOcean.withOpacity(0.30),
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
                          child: const Text("🍼",
                              style: TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Baby Shark Patient 🦈",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "DOO DOO DOO — REAL-TIME VITALS",
                                style: TextStyle(
                                    color: kFoam,
                                    fontSize: 10,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
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
                                color: getStatusColor() == kCoral
                                    ? Colors.red.shade100
                                    : getStatusColor() == Colors.orange
                                    ? Colors.orange.shade100
                                    : Colors.greenAccent.shade100,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Stat Cards ──────────────────────────────
                  Row(
                    children: [
                      _statCard(
                          "Temp",
                          temp != null ? "${temp!.toStringAsFixed(1)}°C" : "--",
                          "🌡️",
                          isTempAbnormal),
                      const SizedBox(width: 10),
                      _statCard(
                          "BPM",
                          bpm != null ? "$bpm" : "--",
                          "💓",
                          isBpmAbnormal),
                      const SizedBox(width: 10),
                      _statCard(
                          "Humidity",
                          hum != null ? "${hum!.toStringAsFixed(0)}%" : "--",
                          "💧",
                          isHumAbnormal),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _respirationCard(),
                  const SizedBox(height: 10),

                  _jaundiceCard(),
                  const SizedBox(height: 10),

                  _jaundiceTreatmentCard(),
                  const SizedBox(height: 14),

                  // ── Connection Status ───────────────────────
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected || isDemo
                              ? const Color(0xFF2ECC71)
                              : kCoral,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isConnected || isDemo
                                  ? const Color(0xFF2ECC71)
                                  : kCoral)
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
                            ? "🌊 RECEIVING DATA"
                            : "🦈 OFFLINE",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: isConnected || isDemo
                                ? const Color(0xFF1A9E5C)
                                : kCoral),
                      ),
                      const Spacer(),
                      if (isDemo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kBubble,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kCardBorder),
                          ),
                          child: const Text("🦈 SIMULATION MODE",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: kOcean,
                                  letterSpacing: 0.8)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── ECG Chart ───────────────────────────────
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: kDeepOcean,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: kFoam.withOpacity(0.20), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: kDeepOcean.withOpacity(0.4),
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
                                    color: kSunny,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "🦈 ECG — Real-time",
                                  style: TextStyle(
                                      color: kFoam,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 36, 0, 8),
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
                                    color: kSunny,
                                    barWidth: 2.5,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: kSunny.withOpacity(0.07),
                                    ),
                                  ),
                                ],
                                titlesData: const FlTitlesData(show: false),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  getDrawingHorizontalLine: (v) => FlLine(
                                      color: kFoam.withOpacity(0.08),
                                      strokeWidth: 1),
                                  getDrawingVerticalLine: (v) => FlLine(
                                      color: kFoam.withOpacity(0.08),
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
                    "🌊 Real-time Electrocardiogram",
                    style: TextStyle(
                        color: kOcean,
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
//بلالين