import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/file_server.dart';
import '../services/wifi_manager.dart';
import 'package:intl/intl.dart';

class SendScreen extends StatefulWidget {
  final FileServer fileServer;
  final WiFiManager wifiManager;

  const SendScreen({
    super.key,
    required this.fileServer,
    required this.wifiManager,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  File? _selectedFile;
  String? _shareCode;
  String? _shareUrl;
  
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _maxDownloadsController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  
  DateTime? _expiryTime;
  String? _hotspotName;
  int _connectedDevices = 0;

  @override
  void initState() {
    super.initState();
    _hotspotName = widget.wifiManager.hotspotName;
    _startMonitoring();
  }

  void _startMonitoring() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        final count = await widget.wifiManager.getConnectedDeviceCount();
        setState(() {
          _connectedDevices = count;
        });
        _startMonitoring();
      }
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final file = File(result.files.single.path!);
      
      int? maxDownloads;
      if (_maxDownloadsController.text.isNotEmpty) {
        maxDownloads = int.tryParse(_maxDownloadsController.text);
      }
      
      int? expiryMinutes;
      if (_expiryController.text.isNotEmpty) {
        expiryMinutes = int.tryParse(_expiryController.text);
        if (expiryMinutes != null) {
          _expiryTime = DateTime.now().add(Duration(minutes: expiryMinutes));
        }
      }

      final code = widget.fileServer.shareFile(
        file,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
        maxDownloads: maxDownloads,
        expiryMinutes: expiryMinutes,
      );

      setState(() {
        _selectedFile = file;
        _shareCode = code;
        _shareUrl = '${widget.fileServer.serverUrl}/d/$code';
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Gönder'),
        backgroundColor: const Color(0xFF6366f1),
      ),
      backgroundColor: const Color(0xFF0f172a),
      body: _selectedFile == null ? _buildPickerView() : _buildShareView(),
    );
  }

  Widget _buildPickerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.folder_open, size: 60, color: Colors.white),
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            'Dosya Ayarları',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 32),
          
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Parola (opsiyonel)',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF6366f1)),
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
                borderSide: const BorderSide(color: Color(0xFF6366f1), width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _maxDownloadsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Maksimum İndirme Sayısı',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Limitsiz',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: const Icon(Icons.download, color: Color(0xFF6366f1)),
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
                borderSide: const BorderSide(color: Color(0xFF6366f1), width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _expiryController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Link Süresi (dakika)',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: 'Limitsiz',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: const Icon(Icons.timer, color: Color(0xFF6366f1)),
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
                borderSide: const BorderSide(color: Color(0xFF6366f1), width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_upload, size: 28),
              label: const Text(
                'Dosya Seç ve Paylaş',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366f1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_hotspotName != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10b981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_tethering, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Hotspot Açık',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hotspotName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_connectedDevices cihaz bağlı',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.insert_drive_file, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFile!.path.split('/').last,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(_selectedFile!.lengthSync()),
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Paylaşım Kodu',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366f1), Color(0xFF8b5cf6)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366f1).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              _shareCode ?? '',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: _shareUrl ?? '',
              version: QrVersions.auto,
              size: 250,
            ),
          ),

          const SizedBox(height: 24),

          if (_passwordController.text.isNotEmpty ||
              _maxDownloadsController.text.isNotEmpty ||
              _expiryController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dosya Ayarları:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_passwordController.text.isNotEmpty)
                    _buildInfoRow(Icons.lock, 'Parola korumalı', Colors.green),
                  if (_maxDownloadsController.text.isNotEmpty)
                    _buildInfoRow(
                      Icons.download,
                      'Max ${_maxDownloadsController.text} indirme',
                      Colors.blue,
                    ),
                  if (_expiryTime != null)
                    _buildInfoRow(
                      Icons.timer,
                      'Süre: ${DateFormat('dd/MM/yyyy HH:mm').format(_expiryTime!)}',
                      Colors.orange,
                    ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _shareUrl ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _shareUrl ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link kopyalandı!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Color(0xFF6366f1)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _shareCode = null;
                  _shareUrl = null;
                  _passwordController.clear();
                  _maxDownloadsController.clear();
                  _expiryController.clear();
                  _expiryTime = null;
                });
              },
              icon: const Icon(Icons.refresh, size: 28),
              label: const Text(
                'Yeni Dosya Paylaş',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10b981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}