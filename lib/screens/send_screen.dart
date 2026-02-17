import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/file_server.dart';
import 'package:intl/intl.dart';

class SendScreen extends StatefulWidget {
  final FileServer fileServer;
  const SendScreen({super.key, required this.fileServer});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  // Adımlar: 0=hotspot aç, 1=dosya seç & ayarla, 2=kod göster
  int _step = 0;
  bool _hotspotConfirmed = false;

  File? _selectedFile;
  String? _shareCode;
  String? _shareUrl;
  DateTime? _expiryTime;

  final _pwCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _maxCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  // Android Hotspot Ayarlarını Aç
  void _openHotspotSettings() {
    const platform = MethodChannel('com.secureshare/hotspot');
    platform.invokeMethod('openHotspot').catchError((_) {
      // MethodChannel çalışmazsa intent ile aç
    });

    // Her durumda sistem ayarlarını aç (bu her telefonda çalışır)
    const MethodChannel('flutter/platform')
        .invokeMethod<void>('SystemNavigator.openHotspotSettings')
        .catchError((_) {});

    // En güvenilir yöntem: App Settings
    _openSystemHotspot();
  }

  Future<void> _openSystemHotspot() async {
    // Android Intent ile Hotspot ayarlarını aç
    const channel = MethodChannel('com.secureshare/settings');
    try {
      await channel.invokeMethod('openTethering');
    } catch (_) {
      // Fallback: kullanıcıya manuel yönlendirme göster
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) {
            final st = context.read<AppState>();
            return AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('📶 Hotspot',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              content: const Text(
                'Sazlamalar → Tor → Hotspot ýoluny yzarlap hotspot\'y açyň.\n\n'
                'Açandan soň "Hotspot Açdym ✓" düwmesine basyň.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Ok'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _confirmHotspot() async {
    setState(() => _hotspotConfirmed = true);

    // Hotspot açıldıktan sonra IP yenile (hotspot IP'si gelsin)
    await Future.delayed(const Duration(seconds: 2));
    await widget.fileServer.refreshIP();

    if (mounted) {
      setState(() => _step = 1);
    }
  }

  Future<void> _pickAndShare() async {
    setState(() => _isLoading = true);

    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) {
      setState(() => _isLoading = false);
      return;
    }

    final file = File(result.files.single.path!);
    int? maxDownloads =
        _maxCtrl.text.isNotEmpty ? int.tryParse(_maxCtrl.text) : null;
    int? expiryMinutes =
        _expCtrl.text.isNotEmpty ? int.tryParse(_expCtrl.text) : null;
    if (expiryMinutes != null) {
      _expiryTime =
          DateTime.now().add(Duration(minutes: expiryMinutes));
    }

    // IP'yi yenile (hotspot IP'si olsun)
    await widget.fileServer.refreshIP();

    final code = widget.fileServer.shareFile(
      file,
      password: _pwCtrl.text.isEmpty ? null : _pwCtrl.text,
      maxDownloads: maxDownloads,
      expiryMinutes: expiryMinutes,
    );

    setState(() {
      _selectedFile = file;
      _shareCode = code;
      _shareUrl =
          '${widget.fileServer.serverUrl}/d/$code';
      _isLoading = false;
      _step = 2;
    });
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

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final dark = st.isDarkMode;
    final bg = dark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F0FF);
    final card = dark ? const Color(0xFF1E1E35) : Colors.white;
    final txt = dark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = dark ? Colors.white54 : Colors.black45;
    final fill = dark ? const Color(0xFF151528) : const Color(0xFFF5F5FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: txt),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(st.t('send'),
            style: TextStyle(
                color: txt, fontWeight: FontWeight.w900)),
        // Adım göstergesi
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _step
                        ? const Color(0xFF6C63FF)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _step == 0
          ? _buildStep0(st, bg, card, txt, sub)
          : _step == 1
              ? _buildStep1(st, bg, card, txt, sub, fill)
              : _buildStep2(st, bg, card, txt, sub),
    );
  }

  // ── ADIM 0: Hotspot Aç ────────────────────────────────────
  Widget _buildStep0(AppState st, Color bg, Color card, Color txt, Color sub) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 30),

          // İkon
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: Colors.white, size: 52),
          ),

          const SizedBox(height: 32),

          Text(
            st.t('step1'),
            style: TextStyle(
              color: txt,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          Text(
            st.t('step1desc'),
            style: TextStyle(color: sub, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Hotspot Aç Butonu
          _gradBtn(
            label: st.t('openHotspotSettings'),
            icon: Icons.settings_rounded,
            colors: const [Color(0xFF6C63FF), Color(0xFF4F46E5)],
            glow: const Color(0xFF6C63FF),
            onTap: _openHotspotSettings,
          ),

          const SizedBox(height: 16),

          // "Açtım" butonu
          GestureDetector(
            onTap: _confirmHotspot,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF06D6A0).withOpacity(0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF06D6A0).withOpacity(0.08),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF06D6A0), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    st.t('hotspotOpened'),
                    style: const TextStyle(
                      color: Color(0xFF06D6A0),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Bilgi kutusu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_rounded,
                    color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hotspot ady näme bolsa bolsun, alyjy WiFi sanawynda seniň hotspot adyny görer we baglanar.',
                    style: TextStyle(
                        color: sub, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ADIM 1: Dosya Seç ────────────────────────────────────
  Widget _buildStep1(AppState st, Color bg, Color card, Color txt, Color sub,
      Color fill) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // Hotspot açık bilgisi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF06D6A0).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF06D6A0).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded,
                    color: Color(0xFF06D6A0), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${st.t("hotspotOpened")}  ·  IP: ${widget.fileServer.serverIP ?? "..."}',
                    style: const TextStyle(
                      color: Color(0xFF06D6A0),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(st.t('step2'),
              style: TextStyle(
                  color: txt,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),

          const SizedBox(height: 20),

          // Ayarlar kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 12)
              ],
            ),
            child: Column(
              children: [
                _input(
                  label: st.t('password'),
                  ctrl: _pwCtrl,
                  icon: Icons.lock_outline_rounded,
                  isPw: true,
                  hint: st.t('unlimited'),
                  txt: txt,
                  sub: sub,
                  fill: fill,
                ),
                const SizedBox(height: 14),
                _input(
                  label: st.t('maxDownloads'),
                  ctrl: _maxCtrl,
                  icon: Icons.download_rounded,
                  isNum: true,
                  hint: st.t('unlimited'),
                  txt: txt,
                  sub: sub,
                  fill: fill,
                ),
                const SizedBox(height: 14),
                _input(
                  label: st.t('expiry'),
                  ctrl: _expCtrl,
                  icon: Icons.timer_outlined,
                  isNum: true,
                  hint: st.t('unlimited'),
                  txt: txt,
                  sub: sub,
                  fill: fill,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _gradBtn(
            label: _isLoading ? '...' : st.t('selectFile'),
            icon: Icons.folder_open_rounded,
            colors: const [Color(0xFF6C63FF), Color(0xFF4F46E5)],
            glow: const Color(0xFF6C63FF),
            onTap: _isLoading ? null : _pickAndShare,
            loading: _isLoading,
          ),
        ],
      ),
    );
  }

  // ── ADIM 2: Kod Göster ───────────────────────────────────
  Widget _buildStep2(
      AppState st, Color bg, Color card, Color txt, Color sub) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Dosya bilgisi
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 12)
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.insert_drive_file_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFile!.path.split('/').last,
                        style: TextStyle(
                            color: txt,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _fmtSize(_selectedFile!.lengthSync()),
                        style: TextStyle(color: sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Hotspot + IP bilgisi
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF06D6A0).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF06D6A0).withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded,
                    color: Color(0xFF06D6A0), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.t('hotspotOpened'),
                          style: const TextStyle(
                              color: Color(0xFF06D6A0),
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      Text(
                        '${st.t("senderIP")}: ${widget.fileServer.serverIP ?? "..."}:${widget.fileServer.port}',
                        style: TextStyle(
                            color: sub,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Büyük KOD kutusu
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  st.t('shareCode'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _shareCode ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // QR Kod
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1), blurRadius: 20)
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _shareUrl ?? '',
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF4F46E5),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  st.t('waitingDesc'),
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Ayar bilgileri
          if (_pwCtrl.text.isNotEmpty ||
              _maxCtrl.text.isNotEmpty ||
              _expCtrl.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (_pwCtrl.text.isNotEmpty)
                    _infoRow('🔒 Parolly ', const Color(0xFF06D6A0)),
                  if (_maxCtrl.text.isNotEmpty)
                    _infoRow('📥 Max ${_maxCtrl.text} ýükleme',
                        const Color(0xFF6C63FF)),
                  if (_expiryTime != null)
                    _infoRow(
                        '⏱ ${DateFormat("dd/MM HH:mm").format(_expiryTime!)}',
                        const Color(0xFFF59E0B)),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // URL kopyala
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _shareUrl ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link kopýalandy!'),
                  backgroundColor: Color(0xFF06D6A0),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _shareUrl ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.copy_rounded,
                      color: Color(0xFF6C63FF), size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Yeni dosya butonu
          _gradBtn(
            label: st.t('newShare'),
            icon: Icons.add_rounded,
            colors: const [Color(0xFF06D6A0), Color(0xFF059669)],
            glow: const Color(0xFF06D6A0),
            onTap: () => setState(() {
              _step = 1;
              _selectedFile = null;
              _shareCode = null;
              _shareUrl = null;
              _expiryTime = null;
              _pwCtrl.clear();
              _maxCtrl.clear();
              _expCtrl.clear();
            }),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
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
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController ctrl,
    required IconData icon,
    bool isPw = false,
    bool isNum = false,
    String hint = '',
    required Color txt,
    required Color sub,
    required Color fill,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: sub, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: isPw,
          keyboardType: isNum ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: txt, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, color: const Color(0xFF6C63FF), size: 20),
            hintText: hint,
            hintStyle: TextStyle(color: sub, fontSize: 13),
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: const Color(0xFF6C63FF).withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFF6C63FF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
