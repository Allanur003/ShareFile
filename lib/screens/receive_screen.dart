import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/file_server.dart';
import '../services/wifi_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReceiveScreen extends StatefulWidget {
  final FileServer fileServer;
  final WiFiManager wifiManager;

  const ReceiveScreen({
    super.key,
    required this.fileServer,
    required this.wifiManager,
  });

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _showScanner = false;
  bool _isLoading = false;
  bool _requiresPassword = false;
  
  String? _filename;
  int? _fileSize;
  int? _downloads;
  int? _maxDownloads;
  DateTime? _expiryTime;

  List<String> _availableNetworks = [];
  bool _isScanning = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _scanForNetworks();
  }

  Future<void> _scanForNetworks() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final networks = await widget.wifiManager.scanNetworks();
      setState(() {
        _availableNetworks = networks;
        _isScanning = false;
      });

      if (networks.length == 1) {
        _connectToHotspot(networks.first);
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarama hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectToHotspot(String ssid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final connected = await widget.wifiManager.connectToNetwork(ssid);

    if (mounted) Navigator.pop(context);

    if (connected) {
      setState(() {
        _isConnected = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlandı: $ssid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bağlantı başarısız!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkFile(String code) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final serverUrl = 'http://192.168.43.1:8080';
      final response = await http.get(
        Uri.parse('$serverUrl/api/file/$code'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          _filename = data['filename'];
          _fileSize = data['size'];
          _downloads = data['downloads'];
          _maxDownloads = data['maxDownloads'];
          _requiresPassword = data['requiresPassword'] ?? false;
          
          if (data['expiryTime'] != null) {
            _expiryTime = DateTime.parse(data['expiryTime']);
          }
          
          _isLoading = false;
        });
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'File not found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(String code) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Depolama izni gerekli!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final serverUrl = 'http://192.168.43.1:8080';
      final response = await http.post(
        Uri.parse('$serverUrl/api/download/$code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'password': _passwordController.text.isEmpty 
              ? null 
              : _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        final downloadsDir = Directory('${directory!.path}/Downloads');
        
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final filePath = '${downloadsDir.path}/$_filename';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1e293b),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                  SizedBox(width: 12),
                  Text('Başarılı!', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dosya indirildi!',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Konum: $filePath',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Download failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.isNegative) {
      return 'Süresi dolmuş';
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays} gün ${difference.inHours % 24} saat kaldı';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat ${difference.inMinutes % 60} dakika kaldı';
    } else {
      return '${difference.inMinutes} dakika kaldı';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner) {
      return _buildScanner();
    }

    if (_filename != null) {
      return _buildFilePreview();
    }

    return _buildCodeInput();
  }

  Widget _buildCodeInput() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Al'),
        backgroundColor: const Color(0xFF10b981),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanForNetworks,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0f172a),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_availableNetworks.isNotEmpty && !_isConnected) ...[
              const Text(
                'Bulunan SecureShare Ağları:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...(_availableNetworks.map((network) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  tileColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.wifi, color: Color(0xFF10b981)),
                  title: Text(
                    network,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _connectToHotspot(network),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10b981),
                    ),
                    child: const Text('Bağlan'),
                  ),
                ),
              ))),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 24),
            ],

            if (_isScanning)
              const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF10b981)),
                  SizedBox(height: 16),
                  Text(
                    'WiFi ağları taranıyor...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),

            if (!_isScanning && _availableNetworks.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SecureShare ağı bulunamadı. Gönderen kişinin "GÖNDER" butonuna bastığından emin olun.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

            if (_isConnected)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bağlantı başarılı! Şimdi kodu girin.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 40),

            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10b981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.download, size: 60, color: Colors.white),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Paylaşım Kodu Girin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 24),
            
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF10b981), width: 2),
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _checkFile(value.toUpperCase());
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_codeController.text.isNotEmpty) {
                          _checkFile(_codeController.text.toUpperCase());
                        }
                      },
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search, size: 28),
                label: Text(
                  _isLoading ? 'Kontrol ediliyor...' : 'Dosyayı Bul',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10b981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'veya',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            
            const SizedBox(height: 16),
            
            OutlinedButton.icon(
              onPressed: () async {
                final status = await Permission.camera.request();
                if (status.isGranted) {
                  setState(() {
                    _showScanner = true;
                  });
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kamera izni gerekli!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: const Text(
                'QR Kod Tara',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10b981),
                side: const BorderSide(color: Color(0xFF10b981), width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Tara'),
        backgroundColor: const Color(0xFF10b981),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showScanner = false;
            });
          },
        ),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              final url = barcode.rawValue!;
              final code = url.split('/').last;
              
              setState(() {
                _showScanner = false;
                _codeController.text = code;
              });
              
              _checkFile(code);
              break;
            }
          }
        },
      ),
    );
  }

  Widget _buildFilePreview() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Bilgileri'),
        backgroundColor: const Color(0xFF10b981),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _filename = null;
              _fileSize = null;
              _requiresPassword = false;
              _passwordController.clear();
            });
          },
        ),
      ),
      backgroundColor: const Color(0xFF0f172a),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10b981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.insert_drive_file, size: 60, color: Colors.white),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              _filename ?? '',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            if (_fileSize != null)
              Text(
                _formatFileSize(_fileSize!),
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white60,
                ),
              ),
            
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  if (_downloads != null)
                    _buildInfoRow(
                      Icons.download,
                      'İndirme: $_downloads${_maxDownloads != null ? " / $_maxDownloads" : ""}',
                      Colors.blue,
                    ),
                  if (_expiryTime != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.timer,
                      _formatDateTime(_expiryTime!),
                      _expiryTime!.isBefore(DateTime.now())
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ],
                  if (_requiresPassword) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.lock,
                      'Parola korumalı',
                      Colors.red,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (_requiresPassword)
              Column(
                children: [
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Parola',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFF10b981)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Color(0xFF10b981), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        _downloadFile(_codeController.text.toUpperCase());
                      },
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download, size: 28),
                label: Text(
                  _isLoading ? 'İndiriliyor...' : 'Dosyayı İndir',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10b981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}