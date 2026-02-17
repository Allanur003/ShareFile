import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/file_server.dart';
import 'send_screen.dart';
import 'receive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FileServer _fileServer = FileServer();
  bool _serverStarted = false;
  String? _serverIP;
  bool _menuOpen = false;
  late AnimationController _anim;
  late Animation<double> _animVal;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _animVal = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _startServer();
  }

  Future<void> _startServer() async {
    final ip = await _fileServer.startServer();
    if (mounted) {
      setState(() {
        _serverIP = ip;
        _serverStarted = ip != null;
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _fileServer.stopServer();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    _menuOpen ? _anim.forward() : _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final dark = st.isDarkMode;
    final bg = dark ? const Color(0xFF0D0D1A) : const Color(0xFFF0F0FF);
    final card = dark ? const Color(0xFF1E1E35) : Colors.white;
    final txt = dark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = dark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Arka plan dekorasyon
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C63FF).withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06D6A0).withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Üst bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF06D6A0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SecureShare',
                              style: TextStyle(
                                  color: txt,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900)),
                          Text(st.t('tagline'),
                              style:
                                  TextStyle(color: sub, fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      // Ayarlar butonu
                      GestureDetector(
                        onTap: _toggleMenu,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _menuOpen
                                ? const Color(0xFF6C63FF)
                                : card,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            _menuOpen
                                ? Icons.close_rounded
                                : Icons.tune_rounded,
                            color: _menuOpen ? Colors.white : sub,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Açılır Ayarlar Menüsü ──────────────
                SizeTransition(
                  sizeFactor: _animVal,
                  child: _buildMenu(st, card, txt, sub),
                ),

                const SizedBox(height: 20),

                // ── Durum Çubuğu ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: _startServer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _serverStarted
                                  ? const Color(0xFF06D6A0)
                                  : const Color(0xFFEF4444),
                              boxShadow: [
                                BoxShadow(
                                  color: (_serverStarted
                                          ? const Color(0xFF06D6A0)
                                          : const Color(0xFFEF4444))
                                      .withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _serverStarted
                                ? st.t('online')
                                : st.t('connecting'),
                            style: TextStyle(
                              color: _serverStarted
                                  ? const Color(0xFF06D6A0)
                                  : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (_serverIP != null) ...[
                            const SizedBox(width: 8),
                            Text('·', style: TextStyle(color: sub)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_serverIP:${_fileServer.port}',
                                style: TextStyle(
                                    color: sub,
                                    fontSize: 12,
                                    fontFamily: 'monospace'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          Icon(Icons.refresh_rounded, color: sub, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── Ana Butonlar ───────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _mainBtn(
                        label: st.t('send'),
                        sub: st.t('sendSub'),
                        icon: Icons.upload_rounded,
                        colors: const [Color(0xFF6C63FF), Color(0xFF4F46E5)],
                        glow: const Color(0xFF6C63FF),
                        onTap: () {
                          if (!_serverStarted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(st.t('connecting')),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SendScreen(fileServer: _fileServer),
                            ),
                          ).then((_) {
                            // Geri dönünce IP yenile
                            _fileServer.refreshIP().then((_) {
                              if (mounted) {
                                setState(() {
                                  _serverIP = _fileServer.serverIP;
                                });
                              }
                            });
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _mainBtn(
                        label: st.t('receive'),
                        sub: st.t('receiveSub'),
                        icon: Icons.download_rounded,
                        colors: const [Color(0xFF06D6A0), Color(0xFF059669)],
                        glow: const Color(0xFF06D6A0),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReceiveScreen(fileServer: _fileServer),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    '🔒 SecureShare',
                    style: TextStyle(color: sub, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(AppState st, Color card, Color txt, Color sub) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          // Tema
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  st.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: const Color(0xFF6C63FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(st.isDarkMode ? st.t('dark') : st.t('light'),
                  style: TextStyle(
                      color: txt,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              _toggle(st.isDarkMode, () => st.toggleTheme()),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: sub.withOpacity(0.15), height: 1),
          const SizedBox(height: 16),
          // Dil
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language_rounded,
                    color: Color(0xFF6C63FF), size: 18),
              ),
              const SizedBox(width: 12),
              Text(st.t('language'),
                  style: TextStyle(
                      color: txt,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              _langBtn(st, 'tk', 'TM'),
              const SizedBox(width: 8),
              _langBtn(st, 'en', 'EN'),
              const SizedBox(width: 8),
              _langBtn(st, 'ru', 'RU'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 52,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color:
              value ? const Color(0xFF6C63FF) : Colors.grey.shade400,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _langBtn(AppState st, String lang, String label) {
    final active = st.language == lang;
    return GestureDetector(
      onTap: () => st.setLanguage(lang),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4F46E5)])
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? Colors.transparent
                : const Color(0xFF6C63FF).withOpacity(0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF6C63FF),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _mainBtn({
    required String label,
    required String sub,
    required IconData icon,
    required List<Color> colors,
    required Color glow,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: glow.withOpacity(0.38),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 0),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child:
                        Icon(icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 4),
                        Text(sub,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.5), size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
