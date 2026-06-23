import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/thingspeak_service.dart';
import '../theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ThingSpeakService _service = ThingSpeakService();
  ThingSpeakData? _currentData;
  Timer? _timer;
  bool _isLoading = true;
  final TextEditingController _ipController = TextEditingController();
  WebViewController? _webViewController;
  bool _showStream = false;

  @override
  void initState() {
    super.initState();
    _loadIp();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchData();
    });
  }

  Future<void> _loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ipController.text = prefs.getString('esp32_ip') ?? '10.195.70.20:80';
      });
    }
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('esp32_ip', ip);
  }

  // La configuration de l'IP se fait désormais directement via l'interface

  void _openEsp32Stream() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    
    String url = ip.startsWith('http') ? ip : 'http://$ip';
    if (!url.contains('/capture')) {
      url = url.endsWith('/') ? '${url}capture' : '$url/capture';
    }
    
    final String htmlContent = '''
      <html>
        <body style="margin:0;padding:0;background-color:black;display:flex;justify-content:center;align-items:center;height:100vh;overflow:hidden;">
          <img src="$url" style="width:100%;height:100%;object-fit:contain;" alt="Flux ESP32" />
        </body>
      </html>
    ''';
    
    final controller = WebViewController();
    if (!kIsWeb) {
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setBackgroundColor(Colors.black);
    }
    controller.loadHtmlString(htmlContent);

    setState(() {
      _showStream = true;
      _webViewController = controller;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final data = await _service.fetchLatestData();
    if (mounted) {
      setState(() {
        _currentData = data;
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  String get _riskLevelText {
    if (_currentData == null) return "EN ATTENTE";
    if (_currentData!.score < 3) return "FAIBLE";
    if (_currentData!.score == 3) return "MOYENNE";
    return "ÉLEVÉ";
  }

  Color get _riskLevelColor {
    if (_currentData == null) return AppTheme.textSecondary;
    if (_currentData!.score < 3) return AppTheme.riskLow;
    if (_currentData!.score == 3) return AppTheme.riskMedium;
    return AppTheme.riskHigh;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Hub'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRiskCard(),
                    const SizedBox(height: 16),
                    _buildCameraCard(),
                    const SizedBox(height: 16),
                    _buildSensorsGrid(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRiskCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NIVEAU DE RISQUE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dernière maj : ${_currentData != null ? "${_currentData!.timestamp.hour}:${_currentData!.timestamp.minute.toString().padLeft(2, '0')}" : "--:--"}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _riskLevelColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _riskLevelColor.withOpacity(0.5)),
              ),
              child: Text(
                _riskLevelText,
                style: TextStyle(
                  color: _riskLevelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: const Row(
              children: [
                Icon(LucideIcons.video, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: 8),
                Text(
                  'FLUX VIDÉO',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse IP ESP32',
                      hintText: 'ex: 10.195.70.20:81',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onChanged: _saveIp,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _openEsp32Stream,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Ouvrir'),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: _showStream && _webViewController != null
                  ? WebViewWidget(controller: _webViewController!)
                  : InkWell(
                      onTap: _openEsp32Stream,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.camera, color: Colors.white54, size: 48),
                            const SizedBox(height: 8),
                            const Text(
                              'Appuyez pour afficher la caméra ici',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildSensorCard(
          'Flamme',
          LucideIcons.flame,
          _currentData?.flame == 1 ? 'DETECTÉE' : 'OK',
          _currentData?.flame == 1 ? AppTheme.riskHigh : AppTheme.riskLow,
        ),
        _buildSensorCard(
          'Mouvement',
          LucideIcons.move,
          _currentData?.motion == 1 ? 'DETECTÉ' : 'AUCUN',
          _currentData?.motion == 1 ? AppTheme.riskMedium : AppTheme.textSecondary,
        ),
        _buildSensorCard(
          'Son',
          LucideIcons.mic,
          _currentData?.sound == 1 ? 'DETECTÉ' : 'SILENCE',
          _currentData?.sound == 1 ? AppTheme.riskMedium : AppTheme.textSecondary,
        ),
        _buildSensorCard(
          'Gaz (ppm)',
          LucideIcons.wind,
          _currentData?.gas.toString() ?? '0',
          (_currentData?.gas ?? 0) > 2000 ? AppTheme.riskHigh : AppTheme.riskLow,
        ),
        _buildSensorCard(
          'Luminosité',
          LucideIcons.sun,
          _currentData?.ldr.toString() ?? '0',
          AppTheme.primaryColor,
        ),
        _buildSensorCard(
          'Mode',
          LucideIcons.moon,
          _currentData?.night == 1 ? 'NUIT' : 'JOUR',
          AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildSensorCard(String title, IconData icon, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
