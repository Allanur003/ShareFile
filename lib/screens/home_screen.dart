import 'package:flutter/material.dart';
import '../services/file_server.dart';
import '../services/wifi_manager.dart';
import 'send_screen.dart';
import 'receive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FileServer _fileServer = FileServer();
  final WiFiManager _wifiManager = WiFiManager();
  
  bool _serverStarted = false;
  String? _serverUrl;
  String _statusText = 'Bekleniyor...';

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    final url = await _fileServer.startServer(isHotspotMode: false);
    setState(() {
      _serverUrl = url;
      _serverStarted = url != null;
      _statusText = _serverStarted ? 'Hazır' : 'Başlatılamadı';
    });
  }

  @override
  void dispose() {
    _fileServer.stopServer();
    _wifiManager.stopHotspot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0f172a),
              Color(0xFF1e293b),
              Color(0xFF334155),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366f1).withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SecureShare',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _serverStarted ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _serverStarted ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _statusText,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    _buildMainButton(
                      context: context,
                      icon: Icons.send,
                      label: 'GÖNDER',
                      subtitle: 'Dosya paylaş (Hotspot açılır)',
                      color: const Color(0xFF6366f1),
                      onTap: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        final hotspotName = await _wifiManager.startHotspot();
                        
                        if (hotspotName != null) {
                          await _fileServer.stopServer();
                          await _fileServer.startServer(isHotspotMode: true);
                          
                          setState(() {
                            _statusText = 'Hotspot: $hotspotName';
                          });

                          if (mounted) Navigator.pop(context);

                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SendScreen(
                                  fileServer: _fileServer,
                                  wifiManager: _wifiManager,
                                ),
                              ),
                            ).then((_) {
                              _wifiManager.stopHotspot();
                              _fileServer.stopServer();
                              _initServer();
                            });
                          }
                        } else {
                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hotspot açılamadı! İzinleri kontrol edin.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    _buildMainButton(
                      context: context,
                      icon: Icons.download,
                      label: 'AL',
                      subtitle: 'Dosya indir (WiFi tarar)',
                      color: const Color(0xFF10b981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReceiveScreen(
                              fileServer: _fileServer,
                              wifiManager: _wifiManager,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _serverUrl ?? 'Server başlatılıyor...',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}