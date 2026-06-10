import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as lat_long;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final prefs = await SharedPreferences.getInstance();
  final darkMode = prefs.getBool('darkMode') ?? false;
  final textSize = prefs.getDouble('textSize') ?? 14;

  runApp(ICaneApp(initialDarkMode: darkMode, initialTextSize: textSize));
}

// Top-level StatefulWidget to manage global dark mode and text size
class ICaneApp extends StatefulWidget {
  final bool initialDarkMode;
  final double initialTextSize;

  const ICaneApp({super.key, required this.initialDarkMode, required this.initialTextSize});

  @override
  State<ICaneApp> createState() => _ICaneAppState();
}

class _ICaneAppState extends State<ICaneApp> {
  bool darkMode = false;
  double textSize = 14;

  @override
  void initState() {
    super.initState();
    darkMode = widget.initialDarkMode;
    textSize = widget.initialTextSize;
  }

  void updateSettings(bool isDark, double size) async {
    setState(() {
      darkMode = isDark;
      textSize = size;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', darkMode);
    await prefs.setDouble('textSize', textSize);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'I-cane App',
      theme: ThemeData(
        brightness: darkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: darkMode ? Colors.black : Colors.white,
        iconTheme: IconThemeData(color: darkMode ? Colors.white : Colors.black54),
        textTheme: TextTheme(
          bodyMedium: TextStyle(fontSize: textSize, color: darkMode ? Colors.white : Colors.black),
          titleMedium: TextStyle(fontSize: textSize + 2, color: darkMode ? Colors.white : Colors.black),
        ),
      ),
      home: AuthWrapper(
        darkMode: darkMode,
        textSize: textSize,
        onSettingsApplied: updateSettings,
      ),
    );
  }
}

// AUTH WRAPPER to handle linking and local login
class AuthWrapper extends StatefulWidget {
  final bool darkMode;
  final double textSize;
  final Function(bool, double) onSettingsApplied;

  const AuthWrapper({super.key, required this.darkMode, required this.textSize, required this.onSettingsApplied});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  String _deviceId = "";

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedDeviceId = prefs.getString('deviceId');
    final String? storedUsername = prefs.getString('username');
    final String? storedPassword = prefs.getString('password');

    if (storedDeviceId != null && storedUsername != null && storedPassword != null) {
      setState(() {
        _isLoggedIn = true;
        _deviceId = storedDeviceId;
      });
    } else if (storedDeviceId != null) {
      setState(() {
        _deviceId = storedDeviceId;
      });
    }
  }

  void _onAuthenticated(String deviceId) {
    setState(() {
      _isLoggedIn = true;
      _deviceId = deviceId;
    });
  }

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    setState(() {
      _isLoggedIn = false;
    });
  }

  void _onUnlink() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('deviceId');
    await prefs.remove('username');
    await prefs.remove('password');
    setState(() {
      _isLoggedIn = false;
      _deviceId = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return MainPager(
        darkMode: widget.darkMode,
        textSize: widget.textSize,
        onSettingsApplied: widget.onSettingsApplied,
        deviceId: _deviceId,
        onLogout: _onLogout,
        onUnlink: _onUnlink,
      );
    }
    return LoginSequenceScreen(
      onComplete: _onAuthenticated,
      initialDeviceId: _deviceId.isNotEmpty ? _deviceId : null,
    );
  }
}

// LOGIN SEQUENCE: Link Device -> Create local account
class LoginSequenceScreen extends StatefulWidget {
  final Function(String) onComplete;
  final String? initialDeviceId;
  const LoginSequenceScreen({super.key, required this.onComplete, this.initialDeviceId});

  @override
  State<LoginSequenceScreen> createState() => _LoginSequenceScreenState();
}

class _LoginSequenceScreenState extends State<LoginSequenceScreen> {
  late TextEditingController _deviceIdController;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLinking = true; // Phase 1: Link to Rasp
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _deviceIdController = TextEditingController(text: widget.initialDeviceId ?? "");
    if (widget.initialDeviceId != null && widget.initialDeviceId!.isNotEmpty) {
      _isLinking = false;
    }
  }

  Future<void> _linkToCane() async {
    setState(() => _isLoading = true);
    final id = _deviceIdController.text.trim();
    if (id.isEmpty) {
      _showMsg("Please enter Device ID");
      setState(() => _isLoading = false);
      return;
    }

    // Verify if Device ID exists in Firebase
    final ref = FirebaseDatabase.instance.ref("iCaneDevice/$id");
    final snapshot = await ref.get();

    if (snapshot.exists) {
      setState(() {
        _isLinking = false;
        _isLoading = false;
      });
    } else {
      _showMsg("I-Cane device not found. Check ID.");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finishSetup() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text.trim();
    final id = _deviceIdController.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      _showMsg("Username and Password are required");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceId', id);
    await prefs.setString('username', user);
    await prefs.setString('password', pass);

    widget.onComplete(id);
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text("I-Cane Setup", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 32),
              if (_isLinking) ...[
                const Text("Phase 1: Link your device"),
                const SizedBox(height: 8),
                const Text("Enter the ID provided by your I-Cane hardware.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                TextField(controller: _deviceIdController, decoration: const InputDecoration(labelText: "Device ID (from Rasp)")),
                const SizedBox(height: 24),
                if (_isLoading) const CircularProgressIndicator() 
                else ElevatedButton(onPressed: _linkToCane, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Link I-Cane")),
              ] else ...[
                const Text("Phase 2: Local Login"),
                const SizedBox(height: 8),
                const Text("These credentials are for this app session.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                TextField(controller: _usernameController, decoration: const InputDecoration(labelText: "Username")),
                TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _finishSetup, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Login / Complete Setup")),
                if (widget.initialDeviceId != null)
                  TextButton(onPressed: () => setState(() => _isLinking = true), child: const Text("Switch Device ID / Unlink")),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// MAIN PAGER
class MainPager extends StatefulWidget {
  final bool darkMode;
  final double textSize;
  final Function(bool, double) onSettingsApplied;
  final String deviceId;
  final VoidCallback onLogout;
  final VoidCallback onUnlink;
  
  const MainPager({
    super.key, 
    required this.darkMode, 
    required this.textSize, 
    required this.onSettingsApplied, 
    required this.deviceId, 
    required this.onLogout,
    required this.onUnlink,
  });

  @override
  State<MainPager> createState() => _MainPagerState();
}

class _MainPagerState extends State<MainPager> {
  int index = 0;
  double? userLat, userLng, deviceLat, deviceLng;
  List<Map<String, dynamic>> planeData = [];
  double planeScale = 20.0; // 20cm per grid unit
  int gridSize = 40;

  void updateLocationData(double? uLat, double? uLng, double? dLat, double? dLng) {
    setState(() {
      userLat = uLat;
      userLng = uLng;
      deviceLat = dLat;
      deviceLng = dLng;
    });
  }

  void updatePlaneData(List<Map<String, dynamic>> data, double scale, int size) {
    setState(() {
      planeData = data;
      planeScale = scale;
      gridSize = size;
    });
  }
  
  @override
  Widget build(BuildContext context) {
   final pages = [
     DashboardScreen(
       darkMode: widget.darkMode, 
       textSize: widget.textSize,
       onLocationChanged: updateLocationData, 
       onPlaneDataChanged: updatePlaneData,
       onViewMap: () => setState(() => index = 1),
       planeData: planeData,
       planeScale: planeScale,
       gridSize: gridSize,
       deviceId: widget.deviceId,
     ), 
     LocationScreen(
       darkMode: widget.darkMode, 
       textSize: widget.textSize,
       userLat: userLat,
       userLng: userLng,
       deviceLat: deviceLat,
       deviceLng: deviceLng,
     ),
     MoreScreen(
        darkMode: widget.darkMode,
        textSize: widget.textSize,
        onSettingsApplied: widget.onSettingsApplied,
        onLogout: widget.onLogout,
        onUnlink: widget.onUnlink,
        deviceId: widget.deviceId,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        backgroundColor: Colors.green,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Location"),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: "More"),
        ],
      ),
    );
  }
}

// DASHBOARD SCREEN
class DashboardScreen extends StatefulWidget {
  final bool darkMode;
  final double textSize;
  final Function(double?, double?, double?, double?) onLocationChanged;
  final Function(List<Map<String, dynamic>>, double, int) onPlaneDataChanged;
  final VoidCallback onViewMap;
  final List<Map<String, dynamic>> planeData;
  final double planeScale;
  final int gridSize;
  final String deviceId;

  const DashboardScreen({
    super.key, 
    required this.darkMode, 
    required this.textSize,
    required this.onLocationChanged,
    required this.onPlaneDataChanged,
    required this.onViewMap,
    required this.planeData,
    required this.planeScale,
    required this.gridSize,
    required this.deviceId,
  });

  static const cardColor = Color(0xFF63E0E3);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  late StreamSubscription<DatabaseEvent> sub;
  StreamSubscription<Position>? locationSub;
  late final DatabaseReference ref;
  Timer? _statusTimer;

  // Real-time Update Notifier for the 2D Map Screen
  final ValueNotifier<Map<String, dynamic>> liveMapUpdates = ValueNotifier({});

  double batteryPercent = 0;
  bool isConnected = false;
  bool _firebaseConnected = false;
  bool systemActive = false;
  String healthStatus = "OK";
  bool degradedMode = false;
  String lastUpdate = "-";
  String lastKnownAddress = "-";
  double? userLat;
  double? userLng;
  double? deviceLat;
  double? deviceLng;
  String distanceToUser = "-";

  Map<String, dynamic> sensors = {};
  Map<String, dynamic> debugSnapshot = {};
  List<Map<String, String>> alertLog = [];
  List<Map<String, String>> recentActivity = [];

  // Emergency State
  bool _isEmergency = false;
  Timer? _beepTimer;
  bool _flashRed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ref = FirebaseDatabase.instance.ref("iCaneDevice/${widget.deviceId}");
    listenToDevice();
    getUserLocation();
    
    // Timer to check if connection is stale
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnectionSync();
    });
  }

  void _checkConnectionSync() {
    if (lastUpdate == "-") return;
    try {
      DateTime last = DateTime.parse(lastUpdate);
      bool isRecent = DateTime.now().difference(last).inSeconds < 45; 
      bool finalStatus = _firebaseConnected && isRecent;
      
      if (isConnected != finalStatus) {
        setState(() {
          isConnected = finalStatus;
        });
      }
    } catch (e) {
      // If parsing fails, fallback to firebase flag
      if (isConnected != _firebaseConnected) {
        setState(() => isConnected = _firebaseConnected);
      }
    }
  }

  void _startEmergencyAlarm() {
    _beepTimer?.cancel();
    _beepTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);
      if (mounted) {
        setState(() {
          _flashRed = !_flashRed;
        });
      }
    });
    
    // Show Snackbar notification immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(" EMERGENCY: SOS BUTTON PRESSED!"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _stopEmergencyAlarm() {
    _beepTimer?.cancel();
    _beepTimer = null;
    if (mounted) {
      setState(() {
        _isEmergency = false;
        _flashRed = false;
      });
    }
  }

  Future<void> getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return;
    }

    // Cancel existing subscription if any
    await locationSub?.cancel();

    locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        userLat = position.latitude;
        userLng = position.longitude;

        if (deviceLat != null && deviceLng != null) {
          final dist = calculateDistance(
            userLat!, userLng!, deviceLat!, deviceLng!
          );
          distanceToUser = "${dist.toStringAsFixed(2)} km";
        }
      });
      widget.onLocationChanged(userLat, userLng, deviceLat, deviceLng);
    });
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            (sin(dLon / 2) * sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void listenToDevice() {
    sub = ref.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data == null || data is! Map) {
        print("No data found at Firebase path: iCaneDevice/${widget.deviceId}");
        return;
      }

      Map<String, dynamic> map;
      try {
        map = Map<String, dynamic>.from(data);
      } catch (e) {
        map = {};
      }

      double battery = 0;
      bool connected = false;
      String updateTime = "-";
      String address = "-";
      Map<String, dynamic> sensorDataIncoming = {};
      Map<String, dynamic> debugDataIncoming = {};
      List<Map<String, dynamic>> plane = [];
      List<Map<String, String>> alerts = [];
      List<Map<String, String>> activity = [];
      double scale = 20.0;
      int size = 20;

      if (map.containsKey("battery")) {
        battery = (map["battery"] is num) ? (map["battery"] as num).toDouble() : 0;
      }

      if (map.containsKey("connected")) {
        connected = map["connected"] is bool ? map["connected"] as bool : false;
      }

      // EMERGENCY DETECTION
      if (map.containsKey("emergency")) {
        bool emergency = map["emergency"] == true;
        if (emergency && !_isEmergency) {
          _isEmergency = true;
          _startEmergencyAlarm();
        } else if (!emergency && _isEmergency) {
          _stopEmergencyAlarm();
        }
      }

      // ADDITIONAL ROOT FIELDS CAPTURE
      if (map.containsKey("system_active")) {
        debugSnapshot["SYSTEM_ACTIVE"] = map["system_active"].toString();
      }
      if (map.containsKey("health")) {
        debugSnapshot["HEALTH_STATUS"] = map["health"].toString();
      }
      if (map.containsKey("degraded")) {
        debugSnapshot["DEGRADED_MODE"] = map["degraded"].toString();
      }

      if (map.containsKey("plane_metadata") && map["plane_metadata"] is Map) {
        final meta = Map<String, dynamic>.from(map["plane_metadata"]);
        scale = (meta["scale"] ?? 20.0).toDouble();
        size = (meta["grid_size"] ?? 20).toInt();
      }

      if (map.containsKey("lastUpdate")) {
        updateTime = map["lastUpdate"]?.toString() ?? "-";
      }

      if (map.containsKey("location") && map["location"] is Map) {
        final loc = Map<String, dynamic>.from(map["location"]);

        if (loc["lat"] is num && loc["lng"] is num) {
          deviceLat = (loc["lat"] as num).toDouble();
          deviceLng = (loc["lng"] as num).toDouble();
          address = "Lat: $deviceLat, Lng: $deviceLng";
        }
      }

      if (map.containsKey("sensors") && map["sensors"] is Map) {
        sensorDataIncoming = Map<String, dynamic>.from(map["sensors"]);
      }

      if (map.containsKey("debug_snapshot") && map["debug_snapshot"] is Map) {
        debugDataIncoming = Map<String, dynamic>.from(map["debug_snapshot"]);
      }

      if (map.containsKey("plane") && map["plane"] is List) {
        try {
          plane = (map["plane"] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
        } catch (e) {
          print("Error parsing plane data: $e");
        }
      }

      if (map.containsKey("alerts") && map["alerts"] is List) {
        try {
          alerts = (map["alerts"] as List).map((item) => Map<String, String>.from(item as Map)).toList();
        } catch (e) {
          print("Error parsing alerts: $e");
        }
      }

      if (map.containsKey("activities") && map["activities"] is List) {
        try {
          activity = (map["activities"] as List).map((item) => Map<String, String>.from(item as Map)).toList();
        } catch (e) {
          print("Error parsing activities: $e");
        }
      }

      String computedDistance = "-";
      if (userLat != null &&
          userLng != null &&
          deviceLat != null &&
          deviceLng != null) {
        final dist = calculateDistance(
          userLat!, userLng!, deviceLat!, deviceLng!
        );
        computedDistance = "${dist.toStringAsFixed(2)} km";
      }

      if (!mounted) return;
      
      // Update reactive notifier
      liveMapUpdates.value = {
        "plane": plane,
        "scale": scale,
        "gridSize": size,
        "sensors": sensorDataIncoming,
        "debug": debugDataIncoming,
      };

      setState(() {
        batteryPercent = battery;
        _firebaseConnected = connected;
        lastUpdate = updateTime;
        lastKnownAddress = address;

        // MERGE Sensors and Debug so keys don't vanish if missing in the latest payload
        sensorDataIncoming.forEach((k, v) => sensors[k] = v);
        debugDataIncoming.forEach((k, v) => debugSnapshot[k] = v);

        distanceToUser = computedDistance;
        alertLog = alerts;
        recentActivity = activity;
      });
      _checkConnectionSync(); // Immediate check after data update
      widget.onLocationChanged(userLat, userLng, deviceLat, deviceLng);
      widget.onPlaneDataChanged(plane, scale, size);
    });
  }

  Widget divider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 6,
      decoration: BoxDecoration(
        color: widget.darkMode ? Colors.grey[800] : Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    TextStyle textStyle = TextStyle(fontSize: widget.textSize, color: widget.darkMode ? Colors.white : Colors.black);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
             // EMERGENCY ALERT BANNER
            if (_isEmergency)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _flashRed ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "EMERGENCY DETECTED\nSOS BUTTON PRESSED",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _stopEmergencyAlarm,
                    ),
                  ],
                ),
              ),

            // STATUS SUMMARY
            Card(
              color: DashboardScreen.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Status Summary", style: textStyle.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text("Connection Status", style: textStyle),
                        const Spacer(),
                        Icon(Icons.circle, color: isConnected ? Colors.green : Colors.red, size: 14),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Last Update Time", style: textStyle),
                        const SizedBox(height: 4),
                        Text(lastUpdate, style: textStyle.copyWith(fontSize: widget.textSize - 2)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            divider(),

            // QUICK LOCATION
            Card(
              color: DashboardScreen.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Quick Location", style: textStyle.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Text("📍 Last Known Address", style: textStyle),
                    Text(lastKnownAddress, style: textStyle),
                    const SizedBox(height: 14),
                    Text("📍 Distance to the User", style: textStyle),
                    Text(distanceToUser, style: textStyle),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: widget.onViewMap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text("View Live Location"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            divider(),

            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SensorPlaneScreen(
                      liveNotifier: liveMapUpdates,
                      darkMode: widget.darkMode,
                    ),
                  ),
                );
              },
              child: Card(
                color: DashboardScreen.cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Sensor Readings", style: textStyle.copyWith(fontWeight: FontWeight.bold)),
                          const Icon(Icons.open_in_new, size: 18),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ...sensors.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(e.key.toUpperCase(), style: textStyle),
                            const Spacer(),
                            Text(e.value.toString(), style: textStyle),
                          ],
                        ),
                      ))
                    ],
                  ),
                ),
              ),
            ),
            divider(),

            ExpandableSectionDynamic(
              darkMode: widget.darkMode,
              textSize: widget.textSize,
              title: "Alert Log",
              scrollable: true,
              entries: alertLog,
            ),

            divider(),

            ExpandableSectionDynamic(
              darkMode: widget.darkMode,
              textSize: widget.textSize,
              title: "Recent Activity",
              scrollable: true,
              entries: recentActivity,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    sub.cancel();
    locationSub?.cancel();
    liveMapUpdates.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }
}


// Dynamic expandable section for alerts/activity
class ExpandableSectionDynamic extends StatefulWidget {
  final String title;
  final bool scrollable;
  final bool darkMode;
  final double textSize;
  final List<Map<String, String>> entries;

  const ExpandableSectionDynamic({
    super.key,
    required this.title,
    this.scrollable = false,
    required this.darkMode,
    required this.textSize,
    required this.entries,
  });

  @override
  State<ExpandableSectionDynamic> createState() => _ExpandableSectionDynamicState();
}

class _ExpandableSectionDynamicState extends State<ExpandableSectionDynamic> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    TextStyle entryStyle = TextStyle(fontSize: widget.textSize, color: widget.darkMode ? Colors.white : Colors.black);

    return Card(
      color: const Color(0xFF63E0E3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: widget.textSize, color: widget.darkMode ? Colors.white : Colors.black)),
            trailing: IconButton(
              icon: Icon(open ? Icons.expand_less : Icons.add),
              onPressed: () => setState(() => open = !open),
            ),
          ),
          if (open)
            SizedBox(
              height: widget.scrollable ? 160 : null,
              child: ListView.builder(
                shrinkWrap: true,
                physics: widget.scrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                itemCount: widget.entries.length,
                itemBuilder: (_, i) {
                  var entry = widget.entries[i];
                  return ListTile(
                    leading: Icon(Icons.info, color: entryStyle.color),
                    title: Text(entry["title"] ?? "Entry", style: entryStyle),
                    subtitle: Text(entry["detail"] ?? "Details here", style: entryStyle),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// MORE SCREEN
class MoreScreen extends StatelessWidget {
  final bool darkMode;
  final double textSize;
  final Function(bool, double) onSettingsApplied;
  final VoidCallback onLogout;
  final VoidCallback onUnlink;
  final String deviceId;

  const MoreScreen({
    super.key, 
    required this.darkMode, 
    required this.textSize, 
    required this.onSettingsApplied, 
    required this.onLogout, 
    required this.onUnlink,
    required this.deviceId,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle rowStyle = TextStyle(fontSize: textSize, color: darkMode ? Colors.white : Colors.black);

    return Scaffold(
      backgroundColor: darkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: darkMode ? Colors.grey[800] : Colors.grey[400], 
                        shape: BoxShape.circle,
                        image: const DecorationImage(
                          image: AssetImage("assets/Logo.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text("I-Cane", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: rowStyle.color)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              buildGroup(context, [
                ["App Version", Icons.devices],
              ], rowStyle),
              buildGroup(context, [
                ["Display Settings", Icons.display_settings]
              ], rowStyle),
              buildGroup(context, [
                ["System Status", Icons.info_outline]
              ], rowStyle),
              buildGroup(context, [
                ["About I-Cane", Icons.info],
                ["Privacy & Data Use", Icons.privacy_tip],
                ["Help & Support", Icons.help_outline]
              ], rowStyle),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGroup(BuildContext context, List<List<dynamic>> items, TextStyle rowStyle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: darkMode ? Colors.black : Colors.grey[100], 
        borderRadius: BorderRadius.circular(8)
      ),
      child: Column(
        children: items.map((item) => Column(
          children: [
            moreRow(context, item[0], item[1] as IconData, rowStyle),
            if (item != items.last) Divider(height: 1, color: darkMode ? Colors.black : Colors.grey),
          ],
        )).toList(),
      ),
    );
  }

  Widget moreRow(BuildContext context, String text, IconData iconData, TextStyle rowStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: InkWell(
        onTap: () {
          if (text == "Display Settings") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => DisplaySettingsScreen(
              darkMode: darkMode,
              textSize: textSize,
              onApply: onSettingsApplied,
            )));
          } else if (text == "System Status") {
             Navigator.push(context, MaterialPageRoute(builder: (_) => SystemStatusScreen(onLogout: onLogout, onUnlink: onUnlink, deviceId: deviceId, darkMode: darkMode, textSize: textSize)));
          } else if (text == "App Version") {
            showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text("App Version"),
              content: const Text("Version: 1.5.0"),
              actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("OK"))],
            ));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => InfoScreen(title: text, content: getScreenContent(text), darkMode: darkMode)));
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF63E0E3),
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(iconData, size: 24, color: rowStyle.color),
                const SizedBox(width: 12),
                Text(text, style: rowStyle)
              ]),
              const Icon(Icons.arrow_forward_ios, size: 18)
            ],
          ),
        ),
      ),
    );
  }
}

// System Status Screen
class SystemStatusScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onUnlink;
  final String deviceId;
  final bool darkMode;
  final double textSize;

  const SystemStatusScreen({
    super.key, 
    required this.onLogout, 
    required this.onUnlink,
    required this.deviceId, 
    required this.darkMode, 
    required this.textSize,
  });

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  final _passwordController = TextEditingController();
  late StreamSubscription<DatabaseEvent> _debugSub;
  Map<String, dynamic> _debugData = {};

  @override
  void initState() {
    super.initState();
    // Listen to the device ROOT so all fields are available for the table
    _debugSub = FirebaseDatabase.instance
        .ref("iCaneDevice/${widget.deviceId}")
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        setState(() {
          _debugData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }

  @override
  void dispose() {
    _debugSub.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final newPass = _passwordController.text.trim();
    if (newPass.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('password', newPass);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Local Password Updated")));
    _passwordController.clear();
  }

  Widget _buildTable() {
    List<DataRow> rows = [];
    TextStyle tableTextStyle = TextStyle(color: widget.darkMode ? Colors.white : Colors.black);
    
    _debugData.forEach((key, value) {
      if (value is Map) {
        // Handle nested maps (like sensors or debug_snapshot)
        rows.add(DataRow(cells: [
          DataCell(Text(key.toUpperCase(), style: tableTextStyle.copyWith(fontWeight: FontWeight.bold))),
          const DataCell(Text("{...}")),
        ]));
        (value).forEach((nk, nv) {
           rows.add(DataRow(cells: [
            DataCell(Padding(padding: const EdgeInsets.only(left: 12), child: Text("↳ $nk", style: tableTextStyle))),
            DataCell(Text(nv.toString(), style: tableTextStyle)),
          ]));
        });
      } else if (value is List) {
        rows.add(DataRow(cells: [
          DataCell(Text(key.toUpperCase(), style: tableTextStyle.copyWith(fontWeight: FontWeight.bold))),
          const DataCell(Text("{...}")),
        ]));
      } else {
        rows.add(DataRow(cells: [
          DataCell(Text(key.toUpperCase(), style: tableTextStyle)),
          DataCell(Text(value.toString(), style: tableTextStyle)),
        ]));
      }
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text("Key", style: tableTextStyle.copyWith(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Value", style: tableTextStyle.copyWith(fontWeight: FontWeight.bold))),
        ],
        rows: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TextStyle headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: widget.darkMode ? Colors.white : Colors.black);

    return Scaffold(
      appBar: AppBar(title: const Text("System Diagnostics")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             Text("Security Settings", style: headerStyle),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController, 
              decoration: const InputDecoration(labelText: "New Local Password"), 
              obscureText: true,
              style: TextStyle(color: widget.darkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _updatePassword, child: const Text("Change Password")),
            
            const SizedBox(height: 32),
            
            Text("Developer Table (Live Sync)", style: headerStyle),
            const SizedBox(height: 16),
            if (_debugData.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF63E0E3).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildTable(),
              ),

            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    }, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text("LOGOUT", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onUnlink();
                    }, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("UNLINK DEVICE", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

//Info Screen for About/Privacy/Help
class InfoScreen extends StatelessWidget {
  final String title;
  final String content;
  final bool darkMode;
  const InfoScreen({super.key, required this.title, required this.content, required this.darkMode});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: Text(content, style: TextStyle(fontSize: 16, color: darkMode ? Colors.white : Colors.black))),
      ),
    );
  }
}

String getScreenContent(String title) {
  switch(title) {
    case "About I-Cane":
      return "This thesis project implements an assistive smart cane with GPS, alert system, and real-time caretaker tracking.";
    case "Privacy & Data Use":
      return "All data collected is stored locally on the device and shared only with registered caretakers. User consent is required.";
    case "Help & Support":
      return """HOW TO USE THE I-CANE
✅ Lightly tap the cane while walking
❌ Do not drag the cane on the ground
Proper cane movement helps the sensors detect obstacles accurately.

SMART FEATURES
The I-Cane can detect:
• Obstacles ahead
• Left and right hazards
• Stairs and drop-offs
• Heat sources
• Possible falls

The system provides:
• Vibration alerts
• Voice guidance
• Real-time hazard warnings

UNDERSTANDING THE ALERTS
• Light Vibration: Obstacle Nearby
• Strong Vibration: Immediate Danger
• Voice Warning: Navigation or Hazard Alert
• Red LED: High risk Situation

HARDWARE CONTROLS
• Power Button: Turns the device on/off.
• Emergency Button: Triggers the SOS/Emergency mode.
• Mode Switch: Long press to toggle WiFi mode for cloud connectivity.
• GPS Module: Located on the handle for optimal signal.

CLOUD MONITORING
The I-Cane can send GPS location, Emergency alerts, and system updates to caregivers through cloud connectivity.

SAFETY REMINDERS
• Keep the cane charged before travel.
• Clean the sensors regularly.
• Avoid water exposure.
• Use caution in unfamiliar environments.

APP USAGE GUIDE
1. Link Device (Phase 1): After downloading, launch the app. You will be prompted to enter your unique Device ID (found on your hardware label or will be heard as an audio after boot) to sync with the cloud.
2. Local Login (Phase 2): Set up a local username and password to secure your app session.
3. Dashboard: Once setup is complete, you will land on the Home screen showing live battery, connection status, and sensor readouts.
4. View Map: Tap the 'Location' tab or the 'View Live Location' button to track the user and i-Cane on a real-time map.
5. Environment Map: Tap on the 'Sensor Readings' card to open the 2D Environment Map. This shows probabilistic obstacle locations around the user. """;
    default:
      return "";
  }
}

class DisplaySettingsScreen extends StatefulWidget {
  final bool darkMode;
  final double textSize;
  final Function(bool, double) onApply;

  const DisplaySettingsScreen({super.key, required this.darkMode, required this.textSize, required this.onApply});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  late bool dark;
  late double size;

  @override
  void initState() {
    super.initState();
    dark = widget.darkMode;
    size = widget.textSize;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Display Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Dark Mode", style: TextStyle(fontSize: 18)),
                Switch(value: dark, activeColor: Colors.green, onChanged: (v) => setState(() => dark = v)),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Text Size", style: TextStyle(fontSize: 18)),
                Slider(
                  min: 14,
                  max: 28,
                  value: size,
                  onChanged: (v) => setState(() => size = v),
                  activeColor: Colors.green,
                  inactiveColor: Colors.grey,
                ),
                Text("Preview Text", style: TextStyle(fontSize: size, color: dark ? Colors.white : Colors.black)),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: dark ? Colors.black : Colors.white, foregroundColor: dark ? Colors.white : Colors.black),
              onPressed: () {
                widget.onApply(dark, size);
                Navigator.pop(context);
              },
              child: const Text("Apply Settings"),
            ),
          ],
        ),
      ),
      backgroundColor: dark ? Colors.black : Colors.white,
    );
  }
}

// Location Screen
class LocationScreen extends StatefulWidget {
  final bool darkMode;
  final double textSize;
  final double? userLat, userLng, deviceLat, deviceLng;

  const LocationScreen({
    super.key, 
    required this.darkMode, 
    required this.textSize,
    this.userLat, this.userLng, this.deviceLat, this.deviceLng,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    // Determine the initial center point (prioritize device, then user, then default 0,0)
    final lat_long.LatLng initialPos = lat_long.LatLng(
      widget.deviceLat ?? widget.userLat ?? 0.0,
      widget.deviceLng ?? widget.userLng ?? 0.0,
    );

    // Markers
    List<Marker> markers = [];
    
    // User Marker (Blue)
    if (widget.userLat != null && widget.userLng != null) {
      markers.add(Marker(
        point: lat_long.LatLng(widget.userLat!, widget.userLng!),
        width: 80,
        height: 80,
        child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
      ));
    }

    // I-Cane Marker (Red)
    if (widget.deviceLat != null && widget.deviceLng != null) {
      markers.add(Marker(
        point: lat_long.LatLng(widget.deviceLat!, widget.deviceLng!),
        width: 80,
        height: 80,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ));
    }

    // Show spinner if both locations are null
    bool isLoading = (widget.deviceLat == null && widget.userLat == null);

    return Scaffold(
      body: isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Waiting for location data..."),
              ],
            ),
          ) 
        : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialPos,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.center_focus_strong),
        onPressed: () {
          if (widget.deviceLat != null) {
            _mapController.move(
              lat_long.LatLng(widget.deviceLat!, widget.deviceLng!),
              15.0,
            );
          } else if (widget.userLat != null) {
             _mapController.move(
              lat_long.LatLng(widget.userLat!, widget.userLng!),
              15.0,
            );
          }
        },
      ),
    );
  }
}

// 2D Sensor Plane Screen
class SensorPlaneScreen extends StatefulWidget {
  final ValueNotifier<Map<String, dynamic>> liveNotifier;
  final bool darkMode;

  const SensorPlaneScreen({
    super.key, 
    required this.liveNotifier,
    required this.darkMode,
  });

  @override
  State<SensorPlaneScreen> createState() => _SensorPlaneScreenState();
}

class _SensorPlaneScreenState extends State<SensorPlaneScreen> {
  Map<String, dynamic>? selectedPoint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: widget.liveNotifier,
      builder: (context, liveData, child) {
        final List<Map<String, dynamic>> planeData = List<Map<String, dynamic>>.from(liveData["plane"] ?? []);
        final double scale = (liveData["scale"] ?? 20.0).toDouble();
        final int gridSize = (liveData["gridSize"] ?? 20).toInt();
        final Map<String, dynamic> sensors = liveData["sensors"] ?? {};

        double rangeMeters = (gridSize / 2) * scale / 100.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text("2D Environment Map"),
            backgroundColor: Colors.green,
          ),
          backgroundColor: widget.darkMode ? Colors.black : Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Local Probabilistic Map (Range: ${rangeMeters.toStringAsFixed(1)}m)",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapUp: (details) {
                          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                          final step = constraints.maxWidth / gridSize;
                          
                          Map<String, dynamic>? closest;
                          double minDist = 20.0; // Selection radius

                          for (var point in planeData) {
                            double x = (point['x'] ?? 0).toDouble();
                            double y = (point['y'] ?? 0).toDouble();
                            Offset pos = Offset(center.dx + (x * step), center.dy - (y * step));
                            double d = (pos - details.localPosition).distance;
                            if (d < minDist) {
                              minDist = d;
                              closest = point;
                            }
                          }
                          setState(() {
                            selectedPoint = closest;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.darkMode ? Colors.grey[900] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: PlanePainter(planeData, widget.darkMode, scale, gridSize, selectedPoint),
                          ),
                        ),
                      );
                    }
                  ),
                ),
                if (selectedPoint != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Point: ${selectedPoint!['type']} @ X:${selectedPoint!['x']}, Y:${selectedPoint!['y']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => selectedPoint = null)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // LEGEND SECTION
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.darkMode ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Map Legend & Sensor Guide:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _legendItem(Colors.red, "I-Cane (Center)"),
                            _legendItem(Colors.orange, "Thermal (Heat Source)"),
                            _legendItem(Colors.green, "LiDAR (Solid Object)"),
                            _legendItem(Colors.blue, "Ultrasonic (Proximity)"),
                            _legendItem(Colors.purple, "ToF (Precise Depth)"),
                            _legendItem(Colors.yellow, "IMU (Motion Alert)"),
                          ],
                        ),
                        const Divider(),
                        const Text("Live Sensor Readings:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: sensors.entries.map((e) => Text("${e.key}: ${e.value}", style: const TextStyle(fontSize: 12))).toList(),
                        ),
                        const Divider(),
                        const Text(
                          "Note: Map radius is center-to-edge. Tap points for details. Faded Points are uncertainty",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class PlanePainter extends CustomPainter {
  final List<Map<String, dynamic>> planeData;
  final bool darkMode;
  final double scale;
  final int gridSize;
  final Map<String, dynamic>? selectedPoint;

  PlanePainter(this.planeData, this.darkMode, this.scale, this.gridSize, this.selectedPoint);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintDevice = Paint()..color = Colors.red..style = PaintingStyle.fill;
    final paintGrid = Paint()..color = darkMode ? Colors.white24 : Colors.black12..style = PaintingStyle.stroke;

    double step = size.width / gridSize;
    double rangeMeters = (gridSize / 2) * scale / 100.0;

    // Grid lines
    for (double i = 0; i <= size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paintGrid);
    }
    for (double i = 0; i <= size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paintGrid);
    }

    canvas.drawCircle(center, 8, paintDevice);

    for (var point in planeData) {
      double x = (point['x'] ?? 0).toDouble();
      double y = (point['y'] ?? 0).toDouble();
      double confidence = (point['v'] ?? 1.0).toDouble();
      String type = (point['type'] ?? 'lidar').toString().toLowerCase();
      
      Color obstacleColor;
      switch (type) {
        case 'thermal': obstacleColor = Colors.orange; break;
        case 'ultrasonic': obstacleColor = Colors.blue; break;
        case 'tof': obstacleColor = Colors.purple; break;
        case 'imu': obstacleColor = Colors.yellow; break;
        case 'lidar':
        default: obstacleColor = Colors.green; break;
      }

      bool isSelected = selectedPoint == point;
      double opacity = (confidence / 45.0).clamp(0.2, 1.0);
      final paintObstacle = Paint()
        ..color = isSelected ? Colors.white : obstacleColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      Offset pos = Offset(center.dx + (x * step), center.dy - (y * step)); 
      
      if (pos.dx >= 0 && pos.dx <= size.width && pos.dy >= 0 && pos.dy <= size.height) {
        canvas.drawCircle(pos, isSelected ? step / 1.5 : step / 2.5, paintObstacle);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
