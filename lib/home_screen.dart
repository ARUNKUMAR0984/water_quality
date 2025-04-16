import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  runApp(const MyApp());
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> showWaterQualityAlert(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'water_quality_channel',
    'Water Quality Alerts',
    importance: Importance.high,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaMonitor Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0277BD),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Montserrat',
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0277BD),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Montserrat',
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? latestData;
  List<Map<String, dynamic>> historicalData = [];
  List<Map<String, dynamic>> alertHistory = [];
  bool isLoading = true;
  late TabController _tabController;
  Timer? _refreshTimer;
  
  // Threshold settings with default values
  double tempHighThreshold = 30.0;
  double tempLowThreshold = 15.0;
  double turbidityThreshold = 800.0;
  double humidityLowThreshold = 30.0;
  
  // Water quality index
  int waterQualityIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadSettings();
    fetchData();
    
    // Set up periodic refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      fetchData();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tempHighThreshold = prefs.getDouble('tempHighThreshold') ?? 30.0;
      tempLowThreshold = prefs.getDouble('tempLowThreshold') ?? 15.0;
      turbidityThreshold = prefs.getDouble('turbidityThreshold') ?? 800.0;
      humidityLowThreshold = prefs.getDouble('humidityLowThreshold') ?? 30.0;
    });
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tempHighThreshold', tempHighThreshold);
    await prefs.setDouble('tempLowThreshold', tempLowThreshold);
    await prefs.setDouble('turbidityThreshold', turbidityThreshold);
    await prefs.setDouble('humidityLowThreshold', humidityLowThreshold);
  }

  Future<void> fetchData() async {
    await Future.wait([
      fetchLatestSensorData(),
      fetchHistoricalData(),
    ]);
    
    if (latestData != null) {
      checkAlertConditions(latestData!);
      calculateWaterQualityIndex(latestData!);
    }
    
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchLatestSensorData() async {
    final url = Uri.parse(
      'https://vzcprivvgdmjbzdsrnjr.supabase.co/rest/v1/sensor_data_1?select=*&order=timestamp.desc&limit=1',
    );

    final response = await http.get(url, headers: {
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6Y3ByaXZ2Z2RtamJ6ZHNybmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA2Nzc1NDgsImV4cCI6MjA1NjI1MzU0OH0.c-Erf5_P-KOHPsWUAX2ywMExgQrFoSjCS1Qk6c_vZZc',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6Y3ByaXZ2Z2RtamJ6ZHNybmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA2Nzc1NDgsImV4cCI6MjA1NjI1MzU0OH0.c-Erf5_P-KOHPsWUAX2ywMExgQrFoSjCS1Qk6c_vZZc',
    });

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        setState(() {
          latestData = data[0];
        });
      }
    } else {
      debugPrint("Failed to load latest data: ${response.body}");
    }
  }

  Future<void> fetchHistoricalData() async {
    final url = Uri.parse(
      'https://vzcprivvgdmjbzdsrnjr.supabase.co/rest/v1/sensor_data_1?select=*&order=timestamp.desc&limit=24',
    );

    final response = await http.get(url, headers: {
      'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6Y3ByaXZ2Z2RtamJ6ZHNybmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA2Nzc1NDgsImV4cCI6MjA1NjI1MzU0OH0.c-Erf5_P-KOHPsWUAX2ywMExgQrFoSjCS1Qk6c_vZZc',
      'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6Y3ByaXZ2Z2RtamJ6ZHNybmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA2Nzc1NDgsImV4cCI6MjA1NjI1MzU0OH0.c-Erf5_P-KOHPsWUAX2ywMExgQrFoSjCS1Qk6c_vZZc',
    });

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      setState(() {
        historicalData = data.map((item) => item as Map<String, dynamic>).toList();
      });
    } else {
      debugPrint("Failed to load historical data: ${response.body}");
    }
  }

  void checkAlertConditions(Map<String, dynamic> data) {
    double waterTemp = getAdjustedTemperature(data);
    double turbidity = (data['turbidity'] as num).toDouble();
    double humidity = (data['humidity'] as num).toDouble();
    DateTime timestamp = DateTime.parse(data['timestamp']);
    
    String alert = '';
    
    if (waterTemp > tempHighThreshold && turbidity > turbidityThreshold) {
      alert = "Critical: High water temperature and turbidity detected";
      showWaterQualityAlert("Water Quality Alert", alert);
    } else if (waterTemp > tempHighThreshold) {
      alert = "Warning: High water temperature detected";
      showWaterQualityAlert("Water Quality Alert", alert);
    } else if (turbidity > turbidityThreshold) {
      alert = "Warning: High water turbidity detected";
      showWaterQualityAlert("Water Quality Alert", alert);
    } else if (waterTemp < tempLowThreshold) {
      alert = "Warning: Low water temperature detected";
      showWaterQualityAlert("Water Quality Alert", alert);
    } else if (humidity < humidityLowThreshold) {
      alert = "Warning: Low humidity detected";
      showWaterQualityAlert("Environmental Alert", alert);
    }
    
    if (alert.isNotEmpty) {
      setState(() {
        alertHistory.add({
          'message': alert,
          'timestamp': timestamp.toString(),
          'severity': alert.startsWith('Critical') ? 'critical' : 'warning',
        });
      });
    }
  }
  
  void calculateWaterQualityIndex(Map<String, dynamic> data) {
    double waterTemp = getAdjustedTemperature(data);
    double turbidity = (data['turbidity'] as num).toDouble();
    
    // Normalize values to 0-100 scale
    double tempScore = 100 - ((waterTemp - 20).abs() / 20) * 100;
    if (tempScore < 0) tempScore = 0;
    
    double turbidityScore = 100 - (turbidity / 1000) * 100;
    if (turbidityScore < 0) turbidityScore = 0;
    
    // Calculate weighted average (giving more weight to turbidity)
    int wqi = ((tempScore * 0.4) + (turbidityScore * 0.6)).round();
    
    // Ensure WQI is in 0-100 range
    wqi = wqi.clamp(0, 100);
    
    setState(() {
      waterQualityIndex = wqi;
    });
  }

  String getSuggestion(Map<String, dynamic> data) {
    double waterTemp = getAdjustedTemperature(data);
    double turbidity = (data['turbidity'] as num).toDouble();
    double roomTemp = (data['room_temp'] as num).toDouble();
    double humidity = (data['humidity'] as num).toDouble();

    if (waterTemp > tempHighThreshold && turbidity > turbidityThreshold) {
      return "⚠️ CRITICAL: High water temp & turbidity. Unsafe for any use. Filter immediately.";
    } else if (turbidity > turbidityThreshold) {
      return "⚠️ WARNING: Water is very turbid. Use filtration before consumption or use.";
    } else if (waterTemp > tempHighThreshold) {
      return "⚠️ WARNING: Water temperature is high. Monitor for algae growth.";
    } else if (waterTemp < tempLowThreshold) {
      return "⚠️ CAUTION: Cold water – may harm aquatic life and affect treatment processes.";
    } else if (humidity < humidityLowThreshold) {
      return "⚠️ NOTE: Dry environment detected. Consider humidification.";
    } else {
      return "✅ GOOD: Water parameters are within safe ranges for general use.";
    }
  }

  String getWaterQualityDescription(int index) {
    if (index >= 80) return "Excellent";
    if (index >= 60) return "Good";
    if (index >= 40) return "Fair";
    if (index >= 20) return "Poor";
    return "Very Poor";
  }

  Color getWaterQualityColor(int index) {
    if (index >= 80) return Colors.green.shade700;
    if (index >= 60) return Colors.green.shade400;
    if (index >= 40) return Colors.amber.shade600;
    if (index >= 20) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color getStatusColor(Map<String, dynamic> data) {
    double waterTemp = getAdjustedTemperature(data);
    double turbidity = (data['turbidity'] as num).toDouble();

    if (waterTemp > tempHighThreshold && turbidity > turbidityThreshold) {
      return Colors.red.shade700;
    } else if (turbidity > turbidityThreshold || waterTemp > tempHighThreshold) {
      return Colors.orange.shade700;
    } else if (waterTemp < tempLowThreshold) {
      return Colors.blue.shade700;
    } else {
      return Colors.green.shade700;
    }
  }
  
  double getAdjustedTemperature(Map<String, dynamic> data) {
    double temperature = (data['temperature'] as num).toDouble();
    return temperature + 150;
  }

  Color getTurbidityColor(double value) {
    // Colors from clear to murky
    if (value < 300) return Colors.blue.shade300;
    if (value < 600) return Colors.blue.shade600;
    if (value < turbidityThreshold) return Colors.amber.shade600;
    return Colors.brown.shade600;
  }

  Color getTemperatureColor(double value) {
    if (value < tempLowThreshold) return Colors.blue.shade600;
    if (value < 25) return Colors.green.shade600;
    if (value < tempHighThreshold) return Colors.amber.shade600;
    return Colors.red.shade600;
  }
  
  Color getHumidityColor(double value) {
    if (value < humidityLowThreshold) return Colors.amber.shade600;
    if (value < 60) return Colors.green.shade400;
    return Colors.blue.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AquaMonitor Pro'),
        elevation: 2,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Dashboard',),
            Tab(text: 'Analysis'),
            Tab(text: 'Alerts'),
          ],
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text('Fetching water quality data...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildHistoricalDataTab(),
                _buildAlertsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => _buildWaterGuideSheet(),
          );
        },
        child: const Icon(Icons.info_outline),
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (latestData == null) {
      return const Center(child: Text('No data available'));
    }

    double waterTemp = getAdjustedTemperature(latestData!);
    double turbidity = (latestData!['turbidity'] as num).toDouble();
    double roomTemp = (latestData!['room_temp'] as num).toDouble();
    double humidity = (latestData!['humidity'] as num).toDouble();
    Color statusColor = getStatusColor(latestData!);
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade800 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return RefreshIndicator(
      onRefresh: fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Water Quality Index
              Card(
                elevation: 4,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Water Quality Index',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: getWaterQualityColor(waterQualityIndex),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$waterQualityIndex/100',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: waterQualityIndex / 100,
                          backgroundColor: Colors.grey.shade300,
                          color: getWaterQualityColor(waterQualityIndex),
                          minHeight: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          getWaterQualityDescription(waterQualityIndex),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: getWaterQualityColor(waterQualityIndex),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Status Card
              Card(
                elevation: 4,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop,
                            color: statusColor,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current Water Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          getSuggestion(latestData!),
                          style: TextStyle(
                            fontSize: 15,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Last Updated:',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy HH:mm').format(
                              DateTime.parse(latestData!['timestamp']),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textColor.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Main parameters in a 2x2 grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildParameterCard(
                    'Water Temperature',
                    waterTemp,
                    '°C',
                    Icons.thermostat_rounded,
                    getTemperatureColor(waterTemp),
                    min: 0,
                    max: 50,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                  _buildParameterCard(
                    'Turbidity',
                    turbidity,
                    'NTU',
                    Icons.opacity_rounded,
                    getTurbidityColor(turbidity),
                    min: 0,
                    max: 1000,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                  _buildParameterCard(
                    'Room Temperature',
                    roomTemp,
                    '°C',
                    Icons.home_rounded,
                    roomTemp > 30 ? Colors.red.shade600 : 
                             (roomTemp < 18 ? Colors.blue.shade600 : Colors.green.shade600),
                    min: 0,
                    max: 40,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                  _buildParameterCard(
                    'Humidity',
                    humidity,
                    '%',
                    Icons.water_drop_outlined,
                    getHumidityColor(humidity),
                    min: 0,
                    max: 100,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Recommendations
              Card(
                elevation: 4,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recommendations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRecommendationTile(
                        waterTemp > tempHighThreshold,
                        'High Water Temperature',
                        'Consider cooling the water or improving circulation to reduce temperature.',
                        textColor,
                      ),
                      _buildRecommendationTile(
                        turbidity > turbidityThreshold,
                        'High Turbidity',
                        'Use a water filter or allow water to settle before use.',
                        textColor,
                      ),
                      _buildRecommendationTile(
                        waterTemp < tempLowThreshold,
                        'Low Water Temperature',
                        'Consider heating the water to ensure proper biological processes.',
                        textColor,
                      ),
                      _buildRecommendationTile(
                        humidity < humidityLowThreshold,
                        'Low Humidity',
                        'Consider using a humidifier to increase ambient humidity.',
                        textColor,
                      ),
                      _buildRecommendationTile(
                        waterQualityIndex < 40,
                        'Poor Water Quality',
                        'Consider complete water treatment before any use.',
                        textColor,
                      ),
                      
                      // Show this if no specific recommendations
                      waterTemp <= tempHighThreshold &&
                              turbidity <= turbidityThreshold &&
                              waterTemp >= tempLowThreshold &&
                              humidity >= humidityLowThreshold &&
                              waterQualityIndex >= 40
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'All parameters are within acceptable ranges. Continue regular monitoring.',
                                style: TextStyle(color: textColor),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterCard(
    String title,
    double value,
    String unit,
    IconData iconData,
    Color color, {
    required double min,
    required double max,
    required Color cardColor,
    required Color textColor,
  }) {
    return Card(
      elevation: 3,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                '${value.toStringAsFixed(1)}$unit',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (value - min) / (max - min),
                backgroundColor: Colors.grey.shade300,
                color: color,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  min.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
                Text(
                  max.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationTile(
    bool condition,
    String title,
    String recommendation,
    Color textColor,
  ) {
    if (!condition) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalDataTab() {
    if (historicalData.isEmpty) {
      return const Center(child: Text('No historical data available'));
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade800 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Reverse data for chronological order
    final chartData = List<Map<String, dynamic>>.from(historicalData)
      ..sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Water Temperature Chart
          Card(
            elevation: 4,
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Water Temperature History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last 24 readings',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 10,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: chartData.length > 6 ? (chartData.length / 6).ceil().toDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= chartData.length || value.toInt() < 0) {
                                  return const SizedBox();
                                }
                                
                                final DateTime date = DateTime.parse(chartData[value.toInt()]['timestamp']);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('HH:mm').format(date),
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 10,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: textColor.withOpacity(0.2)),
                        ),
                        minX: 0,
                        maxX: (chartData.length - 1).toDouble(),
                        minY: 0,
                        maxY: 50,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              chartData.length,
                              (index) => FlSpot(
                                index.toDouble(),
                                getAdjustedTemperature(chartData[index]),
                              ),
                            ),
                            isCurved: true,
                            color: Colors.red.shade400,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.red.shade400.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Water Temp (°C)',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.amber.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Threshold: ${tempHighThreshold.toStringAsFixed(1)}°C',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Turbidity Chart
          Card(
            elevation: 4,
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turbidity History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last 24 readings',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 100,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: chartData.length > 6 ? (chartData.length / 6).ceil().toDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= chartData.length || value.toInt() < 0) {
                                  return const SizedBox();
                                }
                                
                                final DateTime date = DateTime.parse(chartData[value.toInt()]['timestamp']);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('HH:mm').format(date),
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 200,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: textColor.withOpacity(0.2)),
                        ),
                        minX: 0,
                        maxX: (chartData.length - 1).toDouble(),
                        minY: 0,
                        maxY: 1000,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              chartData.length,
                              (index) => FlSpot(
                                index.toDouble(),
                                (chartData[index]['turbidity'] as num).toDouble(),
                              ),
                            ),
                            isCurved: true,
                            color: Colors.brown.shade400,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.brown.shade400.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.brown.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Turbidity (NTU)',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.amber.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Threshold: ${turbidityThreshold.toStringAsFixed(0)} NTU',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Room Temperature Chart
          Card(
            elevation: 4,
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room Temperature History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last 24 readings',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 5,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: chartData.length > 6 ? (chartData.length / 6).ceil().toDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= chartData.length || value.toInt() < 0) {
                                  return const SizedBox();
                                }
                                
                                final DateTime date = DateTime.parse(chartData[value.toInt()]['timestamp']);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('HH:mm').format(date),
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: textColor.withOpacity(0.2)),
                        ),
                        minX: 0,
                        maxX: (chartData.length - 1).toDouble(),
                        minY: 15,
                        maxY: 35,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              chartData.length,
                              (index) => FlSpot(
                                index.toDouble(),
                                (chartData[index]['room_temp'] as num).toDouble(),
                              ),
                            ),
                            isCurved: true,
                            color: Colors.green.shade600,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.shade600.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Room Temperature (°C)',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Humidity Chart
          Card(
            elevation: 4,
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Humidity History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last 24 readings',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 10,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: textColor.withOpacity(0.1),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: chartData.length > 6 ? (chartData.length / 6).ceil().toDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= chartData.length || value.toInt() < 0) {
                                  return const SizedBox();
                                }
                                
                                final DateTime date = DateTime.parse(chartData[value.toInt()]['timestamp']);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('HH:mm').format(date),
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 10,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString() + '%',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: textColor.withOpacity(0.2)),
                        ),
                        minX: 0,
                        maxX: (chartData.length - 1).toDouble(),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              chartData.length,
                              (index) => FlSpot(
                                index.toDouble(),
                                (chartData[index]['humidity'] as num).toDouble(),
                              ),
                            ),
                            isCurved: true,
                            color: Colors.blue.shade400,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.shade400.withOpacity(0.2),
                            ),
                          ),
                          // Add reference line for humidity threshold
                          LineChartBarData(
                            spots: [
                              FlSpot(0, humidityLowThreshold),
                              FlSpot((chartData.length - 1).toDouble(), humidityLowThreshold),
                            ],
                            isCurved: false,
                            color: Colors.amber.shade600,
                            barWidth: 1,
                            isStrokeCapRound: false,
                            dotData: FlDotData(show: false),
                            dashArray: [5, 5], // Create a dashed line
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Humidity (%)',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 1,
                            decoration: BoxDecoration(
                              color: Colors.amber.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Low Threshold: ${humidityLowThreshold.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade800 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    if (alertHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No alerts detected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Water quality parameters are within acceptable ranges',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: alertHistory.length,
      itemBuilder: (context, index) {
        final alert = alertHistory[alertHistory.length - 1 - index];
        final isCritical = alert['severity'] == 'critical';
        final alertColor = isCritical ? Colors.red.shade700 : Colors.orange.shade700;
        final timestamp = DateTime.parse(alert['timestamp']);
        
        return Card(
          elevation: 2,
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: alertColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: alertColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCritical ? 'CRITICAL' : 'WARNING',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('MMM dd, HH:mm').format(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  alert['message'],
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaterGuideSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Water Quality Guide',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildGuideSection(
            'Water Temperature',
            'The temperature of water affects its quality and suitability for various uses.',
            [
              'Below ${tempLowThreshold.toStringAsFixed(1)}°C: Cold water can inhibit biological treatment processes',
              '${tempLowThreshold.toStringAsFixed(1)}-25°C: Ideal range for most water uses',
              '25-${tempHighThreshold.toStringAsFixed(1)}°C: Acceptable but monitor for algae growth',
              'Above ${tempHighThreshold.toStringAsFixed(1)}°C: Too warm, can promote bacterial growth and reduce oxygen levels',
            ],
            Icons.thermostat_rounded,
            textColor,
          ),
          _buildGuideSection(
            'Turbidity',
            'Turbidity measures how clear or cloudy water is, affected by suspended particles.',
            [
              '0-300 NTU: Low turbidity, water is clear and suitable for most uses',
              '300-600 NTU: Moderate turbidity, filtration recommended before consumption',
              '600-${turbidityThreshold.toStringAsFixed(0)} NTU: High turbidity, requires treatment before use',
              'Above ${turbidityThreshold.toStringAsFixed(0)} NTU: Very high turbidity, extensive treatment required',
            ],
            Icons.opacity_rounded,
            textColor,
          ),
          _buildGuideSection(
            'Water Quality Index',
            'A composite measure that combines multiple parameters to give an overall quality rating.',
            [
              '80-100: Excellent - Safe for all uses including drinking with minimal treatment',
              '60-79: Good - Suitable for most uses, may require standard treatment for drinking',
              '40-59: Fair - Usable for non-potable purposes, needs treatment for consumption',
              '20-39: Poor - Limited uses, requires extensive treatment',
              '0-19: Very Poor - Unsuitable for most uses without significant treatment',
            ],
            Icons.insights_rounded,
            textColor,
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGuideSection(
    String title,
    String description,
    List<String> points,
    IconData icon,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double localTempHighThreshold = tempHighThreshold;
        double localTempLowThreshold = tempLowThreshold;
        double localTurbidityThreshold = turbidityThreshold;
        double localHumidityLowThreshold = humidityLowThreshold;
        
        return AlertDialog(
          title: const Text('Threshold Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThresholdSlider(
                  'High Temperature Threshold (°C)',
                  localTempHighThreshold,
                  20.0,
                  40.0,
                  (value) {
                    localTempHighThreshold = value;
                  },
                ),
                _buildThresholdSlider(
                  'Low Temperature Threshold (°C)',
                  localTempLowThreshold,
                  5.0,
                  20.0,
                  (value) {
                    localTempLowThreshold = value;
                  },
                ),
                _buildThresholdSlider(
                  'Turbidity Threshold (NTU)',
                  localTurbidityThreshold,
                  400.0,
                  1000.0,
                  (value) {
                    localTurbidityThreshold = value;
                  },
                ),
                _buildThresholdSlider(
                  'Low Humidity Threshold (%)',
                  localHumidityLowThreshold,
                  10.0,
                  50.0,
                  (value) {
                    localHumidityLowThreshold = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  tempHighThreshold = localTempHighThreshold;
                  tempLowThreshold = localTempLowThreshold;
                  turbidityThreshold = localTurbidityThreshold;
                  humidityLowThreshold = localHumidityLowThreshold;
                });
                saveSettings();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThresholdSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) * 10).toInt(),
                label: value.toStringAsFixed(1),
                onChanged: (newValue) {
                  onChanged(newValue);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}