import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/file_server.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<bool> storagePermission() async {
  var status = await Permission.storage.request();
  return status.isGranted;
}
class ReceiveScreen extends StatefulWidget {
  final FileServer fileServer;
  const ReceiveScreen({super.key, required this.fileServer});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  static const platform = MethodChannel('com.secureshare/native');
  
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  
  bool _showScanner = false;
  bool _isLoading = false;
  bool _isDownloading = false;
  bool _downloadDone = false;
  bool _wifiConnected = false;

  String? _filename;
  int? _fileSize;
  int? _downloads;
  int? _maxDownloads;
  DateTime? _expiryTime;
  bool _requiresPassword = false;

  String _targetHost = '';// Hotspot varsayılan IP
  int _targetPort = 8080;

  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _checkWifiConnection();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _checkWifiConnection() async {
    // WiFi bağlı mı kontrol et
    setState(() {
      _wifiConnected = false; // İlk başta false
    });
  }

  Future<void> _connectToHotspot() async {
    try {
      // Native koda hotspot'a bağlan komutu gönder
      await platform.invokeMethod('connectToHotspot');
      
      // Kullanıcıya bilgi ver
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('📶 WiFi'),
            content: const Text(
              'WiFi sazlamalarynda "SecureShare_Direct" wifiya baglanyn.\n\n'
              'Parol: share2026\n\n'
              'Baglanandan son "Baglandym" duwmesine basyn.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _wifiConnected = true;
                  });
                },
                child: const Text('Baglandym ✓'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showErr('WiFi sazlamalary açylamady: $e');
    }
  }

  String _getServerUrl() {
  if (_targetHost.isEmpty) {
    return 'http://192.168.43.1:$_targetPort';
  }
  return 'http://$_targetHost:$_targetPort';
}

  Future<void> _checkFile(String code) async {
    if (code.trim().isEmpty) return;
    
    if (!_wifiConnected) {
      _showErr('Öňinçä WiFi\'ya baglanyň!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = '${_getServerUrl()}/api/file/${code.trim().toUpperCase()}';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
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
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Faýl Tapylmady');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _downloadFile() async {
    final code = _codeCtrl.text.trim().toUpperCase();

    // İzin kontrolü
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        _showErr('Требуется разрешение на хранение!');
        return;
      }
    }

    setState(() => _isDownloading = true);

    try {
final url = '${_getServerUrl()}/api/download/$code';
final res = await http.post(
  Uri.parse(url),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'password': _pwCtrl.text.isEmpty ? null : _pwCtrl.text,
  }),
);

if (res.statusCode == 200) {

  Directory dir = await getApplicationDocumentsDirectory();

  final folder = Directory('${dir.path}/SecureShare');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final filePath = '${folder.path}/$_filename';
  await File(filePath).writeAsBytes(res.bodyBytes);

        setState(() {
          _isDownloading = false;
          _downloadDone = true;
        });

        _showSuccess(filePath);
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Ýükleme näsazlygy');
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      _showErr(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String path) {
    if (!mounted) return;
    final st = context.read<AppState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: st.isDarkMode ? const Color(0xFF1E1E35) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06D6A0), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              st.t('downloaded'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              path,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(
              st.t('back'),
              style: const TextStyle(color: Color(0xFF06D6A0)),
            ),
          ),
        ],
      ),
    );
  }

  void _processQRData(String qrData) {
    try {
      // URL formatı: http://IP:PORT/d/CODE
      final uri = Uri.parse(qrData);
      _targetHost = uri.host;
      _targetPort = uri.port != 0 ? uri.port : 8080;
      final code = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : qrData;
      _codeCtrl.text = code;
      
      // Dosyayı kontrol et
      _checkFile(code);
    } catch (e) {
      // Sadece kod ise
      _codeCtrl.text = qrData.trim().toUpperCase();
      _checkFile(_codeCtrl.text);
    }
  }

  String _fmtSize(int b) {
    if (b <= 0) return '0 B';
    const s = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double v = b.toDouble();
    while (v >= 1024 && i < s.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(2)} ${s[i]}';
  }

  String _timeLeft() {
    if (_expiryTime == null) return '';
    final d = _expiryTime!.difference(DateTime.now());
    if (d.isNegative) return 'Süresi doldu';
    if (d.inDays > 0) return '${d.inDays}g ${d.inHours % 24}s';
    if (d.inHours > 0) return '${d.inHours}s ${d.inMinutes % 60}dk';
    return '${d.inMinutes}dk';
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final dark = st.isDarkMode;
    final bg = dark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F0FF);
    final card = dark ? const Color(0xFF1E1E35) : Colors.white;
    final txt = dark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = dark ? Colors.white54 : Colors.black45;
    final fill = dark ? const Color(0xFF151528) : const Color(0xFFF5F5FF);

    if (_showScanner) {
      return _buildScanner(st, bg, txt);
    }

    if (_filename != null) {
      return _buildFilePreview(st, bg, card, txt, sub, fill);
    }

    return _buildCodeInput(st, bg, card, txt, sub, fill);
  }

  Widget _buildCodeInput(AppState st, Color bg, Color card, Color txt, Color sub, Color fill) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: txt),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          st.t('receiveTitle'),
          style: TextStyle(color: txt, fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // İkon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06D6A0), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06D6A0).withOpacity(0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.download_rounded, color: Colors.white, size: 48),
            ),

            const SizedBox(height: 32),

            // WiFi Bağlantı Durumu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _wifiConnected
                    ? const Color(0xFF06D6A0).withOpacity(0.08)
                    : const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _wifiConnected
                      ? const Color(0xFF06D6A0).withOpacity(0.4)
                      : const Color(0xFFF59E0B).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _wifiConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: _wifiConnected ? const Color(0xFF06D6A0) : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _wifiConnected
                          ? 'WiFi Bagly ✓'
                          : 'WiFi\'ya baglanyň',
                      style: TextStyle(
                        color: _wifiConnected ? const Color(0xFF06D6A0) : const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!_wifiConnected)
                    TextButton(
                      onPressed: _connectToHotspot,
                      child: const Text('Baglan'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bilgi kutusu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Nadip Işledilýär?',
                        style: TextStyle(
                          color: txt,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. WiFi\'ya baglan (SecureShare_Direct)\n'
                    '2. QR kody okad ýada kody ýaz\n'
                    '3. Faýl awtomat ýüklener',
                    style: TextStyle(color: sub, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Kod girişi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    st.t('enterCode'),
                    style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeCtrl,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      color: txt,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                    ),
                    decoration: InputDecoration(
                      hintText: 'XXXXXX',
                      hintStyle: TextStyle(color: sub, fontSize: 26, letterSpacing: 8),
                      filled: true,
                      fillColor: fill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF06D6A0), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dosya Bul butonu
            _gradBtn(
              label: _isLoading ? '...' : st.t('findFile'),
              icon: Icons.search_rounded,
              colors: const [Color(0xFF06D6A0), Color(0xFF059669)],
              glow: const Color(0xFF06D6A0),
              onTap: _isLoading ? null : () => _checkFile(_codeCtrl.text),
              loading: _isLoading,
            ),

            const SizedBox(height: 16),

            // VEYA
            Row(
              children: [
                Expanded(child: Divider(color: sub.withOpacity(0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ýada', style: TextStyle(color: sub, fontSize: 12)),
                ),
                Expanded(child: Divider(color: sub.withOpacity(0.3))),
              ],
            ),

            const SizedBox(height: 16),

            // QR Tara
            GestureDetector(
              onTap: () async {
                final status = await Permission.camera.request();
                if (status.isGranted) {
                  setState(() {
                    _showScanner = true;
                    _scannerController = MobileScannerController(
                      facing: CameraFacing.back,
                      torchEnabled: false,
                    );
                  });
                } else {
                  _showErr('Kamera rugsady gerek!');
                }
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      st.t('scanQR'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner(AppState st, Color bg, Color txt) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          st.t('scanQR'),
          style: TextStyle(color: txt, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: txt),
          onPressed: () {
            _scannerController?.dispose();
            setState(() {
              _showScanner = false;
              _scannerController = null;
            });
          },
        ),
      ),
      body: _scannerController == null
          ? const Center(child: CircularProgressIndicator())
          : MobileScanner(
              controller: _scannerController!,
              onDetect: (BarcodeCapture capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final barcode = barcodes.first;
                if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return;

                // QR'ı bir kere işle
                _scannerController?.stop();
                setState(() => _showScanner = false);
                _processQRData(barcode.rawValue!);
              },
            ),
    );
  }

  Widget _buildFilePreview(AppState st, Color bg, Color card, Color txt, Color sub, Color fill) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: txt),
          onPressed: () {
            setState(() {
              _filename = null;
              _requiresPassword = false;
              _downloadDone = false;
              _pwCtrl.clear();
            });
          },
        ),
        title: Text(
          st.t('fileInfo'),
          style: TextStyle(color: txt, fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Dosya ikonu
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06D6A0), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06D6A0).withOpacity(0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _filename ?? '',
              style: TextStyle(color: txt, fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            if (_fileSize != null)
              Text(
                _fmtSize(_fileSize!),
                style: TextStyle(color: sub, fontSize: 15),
              ),

            const SizedBox(height: 24),

            // Bilgi kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12),
                ],
              ),
              child: Column(
                children: [
                  if (_downloads != null)
                    _infoTile(
                      Icons.download_rounded,
                      st.t('downloads'),
                      '$_downloads${_maxDownloads != null ? " / $_maxDownloads" : ""}',
                      const Color(0xFF6C63FF),
                      txt,
                      sub,
                    ),
                  if (_expiryTime != null) ...[
                    const SizedBox(height: 14),
                    _infoTile(
                      Icons.timer_rounded,
                      st.t('timeLeft'),
                      _timeLeft(),
                      const Color(0xFFF59E0B),
                      txt,
                      sub,
                    ),
                  ],
                  if (_requiresPassword) ...[
                    const SizedBox(height: 14),
                    _infoTile(
                      Icons.lock_rounded,
                      st.t('fileProtected'),
                      '🔒',
                      const Color(0xFFEF4444),
                      txt,
                      sub,
                    ),
                  ],
                ],
              ),
            ),

            // Parola girişi
            if (_requiresPassword) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _pwCtrl,
                  obscureText: true,
                  style: TextStyle(color: txt, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    labelText: st.t('enterPassword'),
                    labelStyle: TextStyle(color: sub),
                    filled: true,
                    fillColor: fill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
              ),
            ],

            // İndirme animasyonu
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(
                backgroundColor: Color(0x2206D6A0),
                color: Color(0xFF06D6A0),
              ),
              const SizedBox(height: 10),
              Text(
                st.t('downloading'),
                style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 24),

            // İndir butonu
            _gradBtn(
              label: _downloadDone
                  ? st.t('downloaded')
                  : (_isDownloading ? st.t('downloading') : st.t('download')),
              icon: _downloadDone ? Icons.check_circle_rounded : Icons.download_rounded,
              colors: _downloadDone
                  ? [const Color(0xFF06D6A0), const Color(0xFF059669)]
                  : [const Color(0xFF6C63FF), const Color(0xFF4F46E5)],
              glow: _downloadDone ? const Color(0xFF06D6A0) : const Color(0xFF6C63FF),
              onTap: (_isDownloading || _downloadDone) ? null : _downloadFile,
              loading: _isDownloading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
      IconData icon, String label, String value, Color color, Color txt, Color sub) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: sub, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Text(
              value,
              style: TextStyle(color: txt, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gradBtn({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required Color glow,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
