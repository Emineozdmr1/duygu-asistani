import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() => runApp(const DuyguAsistaniApp());

class DuyguAsistaniApp extends StatelessWidget {
  const DuyguAsistaniApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Outfit'),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final PageController _pageController = PageController();
  Map<String, dynamic>? _results;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _showAlternatives = false;
  bool _hasVoted = false;

  final Map<String, dynamic> _themes = {
    'initial': {
      "grad": [const Color(0xFF1E293B), const Color(0xFF0F172A)],
      "accent": const Color(0xFF38BDF8),
      "emoji": "🧠",
      "title": "Duygu Asistanı",
    },
    'Happy': {
      "grad": [const Color(0xFFF6D365), const Color(0xFFFDA085)],
      "accent": const Color(0xFFD35400),
      "emoji": "😊",
      "title": "Mutlu",
    },
    'Excited': {
      "grad": [const Color(0xFF84FAB0), const Color(0xFF8FD3F4)],
      "accent": const Color(0xFF059669),
      "emoji": "🤩",
      "title": "Heyecanlı",
    },
    'Sadness': {
      "grad": [const Color(0xFFA1C4FD), const Color(0xFFC2E9FB)],
      "accent": const Color(0xFF1D6FD8),
      "emoji": "😔",
      "title": "Üzgün",
    },
    'Stressed': {
      "grad": [const Color(0xFFFCCB90), const Color(0xFFD57EEB)],
      "accent": const Color(0xFF7C3AED),
      "emoji": "😰",
      "title": "Stresli",
    },
    'Fear': {
      "grad": [const Color(0xFFE6E9F0), const Color(0xFFEEF1F5)],
      "accent": const Color(0xFF4B5563),
      "emoji": "😨",
      "title": "Korku",
    },
    'Complex': {
      "grad": [const Color(0xFFF5F7FA), const Color(0xFFC3CFE2)],
      "accent": const Color(0xFFBE3A85),
      "emoji": "🌀",
      "title": "Karmaşık",
    },
    'Anger': {
      "grad": [const Color(0xFFFF9A9E), const Color(0xFFFECFEF)],
      "accent": const Color(0xFFDC2626),
      "emoji": "😠",
      "title": "Öfkeli",
    },
    'Disgust': {
      "grad": [const Color(0xFFD4FC79), const Color(0xFF96E6A1)],
      "accent": const Color(0xFF27AE60),
      "emoji": "🤢",
      "title": "Rahatsız",
    },
    'Surprise': {
      "grad": [const Color(0xFFE0C3FC), const Color(0xFF8EC5FC)],
      "accent": const Color(0xFF6C5CE7),
      "emoji": "😲",
      "title": "Şaşkın",
    },
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _analizEt([String? text]) async {
    final searchInput = text ?? _controller.text;
    if (searchInput.trim().isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLoading = true;
      _results = null;
      _showAlternatives = false;
      _hasVoted = false;
    });

    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8000/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': searchInput}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        setState(() => _results = jsonDecode(response.body));
        _animController.reset();
        _animController.forward();
        _controller.clear();
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) {
          _pageController.animateToPage(1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        }
      } else {
        _showError("Sunucudan beklenmedik yanıt geldi.");
      }
    } on TimeoutException {
      _showError("Sunucu yanıt vermedi, tekrar dene.");
    } catch (_) {
      _showError("Sunucu uykuda mı ? 🥲");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _oyVer(String oyTipi) async {
    if (_hasVoted || _results == null) return;
    final String userText =
        _results?['analysis']?['user_text'] ?? _controller.text;
    final String currentMood =
        _results?['analysis']?['mood'] ?? "Bilinmiyor";
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'text': userText, 'mood': currentMood, 'vote': oyTipi}),
      );
      if (response.statusCode == 200) {
        setState(() => _hasVoted = true);
        _showSuccess("Geri bildirimin kaydedildi. Teşekkürler! ✅");
      }
    } catch (_) {
      _showError("Geri bildirim iletilemedi. 🥲");
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFEF4444),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
    ));
  }

  void _geriDon() {
    _pageController.animateToPage(0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut);
    setState(() => _results = null);
    _controller.clear();
  }

  bool _isDark(List<Color> colors) {
    final c = colors.first;
    final lum =
        (0.299 * c.red + 0.587 * c.green + 0.114 * c.blue) / 255;
    return lum < 0.60;
  }

  Future<void> _launchRawUrl(String? rawUrl) async {
    if (rawUrl == null) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [_buildGirisSayfasi(), _buildSonucSayfasi()],
    );
  }

  // ════════════════════════════════════════════════════════
  //  GİRİŞ SAYFASI
  // ════════════════════════════════════════════════════════

  Widget _buildGirisSayfasi() {
    final theme = _themes['initial']!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: List<Color>.from(theme['grad']),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 50),
            child: Column(
              children: [
                const SizedBox(height: 56),
                _buildLogo(theme),
                const SizedBox(height: 36),
                _buildInputPanel(),
                const SizedBox(height: 20),
                _buildMoodPills(),
                const SizedBox(height: 28),
                _buildAnalizButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Map<String, dynamic> theme) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withOpacity(0.14), width: 1.5),
          ),
          child: Center(
              child: Text(theme['emoji'],
                  style: const TextStyle(fontSize: 38))),
        ),
        const SizedBox(height: 16),
        const Text(
          "DUYGU ASİSTANI",
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 3.5),
        ),
        const SizedBox(height: 6),
        const Text(
          "Bugün nasıl hissediyorsun?",
          style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w400),
        ),
      ],
    );
  }

  Widget _buildInputPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withOpacity(0.11), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "HİSLERİNİ YAZ",
            style: TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 2),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, height: 1.55),
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: "Bugün kendimi biraz...",
              hintStyle: TextStyle(color: Colors.white24, fontSize: 15),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodPills() {
    final moods = [
      {"e": "😊", "t": "Mutlu", "q": "Bugün kendimi çok mutlu ve neşeli hissediyorum"},
      {"e": "😔", "t": "Üzgün", "q": "Bugün biraz üzgün ve moralsiz hissediyorum"},
      {"e": "😰", "t": "Stresli", "q": "Kendimi çok gergin ve stresli hissediyorum, bunaltıcı bir baskı altındayım"},
      {"e": "😨", "t": "Korku", "q": "Biraz endişeliyim ve tedirgin hissediyorum"},
      {"e": "😠", "t": "Öfkeli", "q": "Şu an gerçekten çok sinirliyim ve öfkeliyim"},
      {"e": "🤢", "t": "Tiksinme", "q": "İnsanların bu kadar bencil ve çıkarcı olmalarından tiksiniyorum"},
      {"e": "😲", "t": "Şaşkın", "q": "Hiç beklemediğim bir anda bu sürprizle karşılaşınca şoke oldum"},
      {"e": "🌀", "t": "Karmaşık", "q": "Şu an ne hissettiğimi tam olarak ben de bilmiyorum, kafam çok karışık"},
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      alignment: WrapAlignment.center,
      children: moods.map((m) {
        return InkWell(
          onTap: () {
            _controller.text = m['q']!;
            _analizEt(m['q']);
          },
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: Colors.white.withOpacity(0.11), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m['e']!, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(m['t']!,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalizButton(Map<String, dynamic> theme) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _analizEt(),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme['accent'],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text("ANALİZ ET",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1.2)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SONUÇ SAYFASI
  // ════════════════════════════════════════════════════════

  Widget _buildSonucSayfasi() {
    if (_results == null)
      return const Scaffold(backgroundColor: Color(0xFF0F172A));

    final mood = _results?['analysis']?['mood'];
    final themeKey = mood == "Excited" ? "Excited" : mood;
    final theme = (_themes.containsKey(themeKey)
        ? _themes[themeKey]
        : _themes['initial'])!;
    final recs = _results?['recommendations'];

    final musicData =
        recs?['music'] != null ? List<dynamic>.from(recs!['music']) : [];
    final bookData =
        recs?['book'] != null ? List<dynamic>.from(recs!['book']) : [];
    final foodData =
        recs?['food'] != null ? List<dynamic>.from(recs!['food']) : [];

    // Müzik duplikasyon filtresi
    List<dynamic> filteredMusic = [];
    if (musicData.isNotEmpty) {
      filteredMusic.add(musicData[0]);
      String mA = (musicData[0]['artist'] ?? "").toString().toLowerCase().trim();
      String mS = (musicData[0]['name'] ?? "").toString().toLowerCase().trim();
      for (int i = 1; i < musicData.length; i++) {
        String ca = (musicData[i]['artist'] ?? "").toString().toLowerCase().trim();
        String cs = (musicData[i]['name'] ?? "").toString().toLowerCase().trim();
        if (ca != mA && cs != mS) filteredMusic.add(musicData[i]);
      }
    }

    final List<Color> grad = List<Color>.from(theme['grad']);
    final Color accent = theme['accent'] as Color;
    final bool dark = _isDark(grad);
    final Color ink = dark ? Colors.white : const Color(0xFF1E293B);
    final Color inkFaint = dark ? Colors.white54 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: grad.last,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: grad,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────
                _buildHeader(theme, accent, ink, inkFaint),

                // ── Kullanıcı metni ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: _buildQuoteCard(ink, inkFaint),
                ),

                const SizedBox(height: 28),

                // ── Ana Öneriler ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _sectionHeader("Senin İçin Seçtiklerimiz", accent),
                ),
                const SizedBox(height: 14),

                FadeTransition(
                  opacity: _fadeAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Müzik — yatay büyük kart
                        if (filteredMusic.isNotEmpty)
                          _buildMusicCard(
                              Map<String, dynamic>.from(filteredMusic[0]),
                              accent),
                        if (filteredMusic.isNotEmpty)
                          const SizedBox(height: 14),

                        // Kitap — tam genişlik
                        if (bookData.isNotEmpty)
                          _buildFullCard(
                            "ZİHİN BESİNİ",
                            "📚",
                            Map<String, dynamic>.from(bookData[0]),
                            const Color(0xFF3B82F6),
                            Icons.menu_book,
                            "Kitabı İncele",
                          ),
                        if (bookData.isNotEmpty) const SizedBox(height: 14),

                        // Yemek — tam genişlik
                        if (foodData.isNotEmpty)
                          _buildFullCard(
                            "MUTLULUK TARİFİ",
                            "🍔",
                            Map<String, dynamic>.from(foodData[0]),
                            const Color(0xFF10B981),
                            Icons.restaurant,
                            "Tarife Git",
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Alternatif toggle ───────────────────────────
                if (filteredMusic.length > 1 ||
                    bookData.length > 1 ||
                    foodData.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildToggleBtn(ink, accent),
                  ),

                // ── Alternatifler — kaydırmalı carousel ────────
                if (_showAlternatives) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _sectionHeader("Alternatif Öneriler", accent),
                  ),
                  const SizedBox(height: 14),

                  // 🎵 Alternatif Müzikler
                  if (filteredMusic.length > 1) ...[
                    _carouselLabel("🎵  Müzik", ink),
                    const SizedBox(height: 8),
                    _buildCarousel(
                      filteredMusic.sublist(1, filteredMusic.length.clamp(2, 5)),
                      const Color(0xFF1DB954),
                      Icons.music_note,
                      isSpotify: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 📚 Alternatif Kitaplar
                  if (bookData.length > 1) ...[
                    _carouselLabel("📚  Kitap", ink),
                    const SizedBox(height: 8),
                    _buildCarousel(
                      bookData.sublist(1, bookData.length.clamp(2, 4)),
                      const Color(0xFF3B82F6),
                      Icons.menu_book,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 🍔 Alternatif Yemekler
                  if (foodData.length > 1) ...[
                    _carouselLabel("🍔  Yemek", ink),
                    const SizedBox(height: 8),
                    _buildCarousel(
                      foodData.sublist(1, foodData.length.clamp(2, 4)),
                      const Color(0xFF10B981),
                      Icons.restaurant,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],

                // ── Geri bildirim ───────────────────────────────
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildFeedbackCard(ink, inkFaint),
                ),
                const SizedBox(height: 44),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  SONUÇ SAYFASI BİLEŞENLERİ
  // ════════════════════════════════════════════════════════

  Widget _buildHeader(Map<String, dynamic> theme, Color accent,
      Color ink, Color inkFaint) {
    final confidence =
        _results?['analysis']?['confidence']?.toString() ?? "";
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Geri butonu
          GestureDetector(
            onTap: _geriDon,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.22), width: 1),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: ink, size: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Emoji
          Text(theme['emoji'],
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),

          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        theme['title'],
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: ink,
                            height: 1.1),
                      ),
                    ),
                    if (confidence.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          confidence,
                          style: TextStyle(
                              color: ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_results?['analysis']?['message'] != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _results!['analysis']['message'],
                    style: TextStyle(
                        fontSize: 12,
                        color: inkFaint,
                        fontWeight: FontWeight.w500,
                        height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(Color ink, Color inkFaint) {
    final txt = _results?['analysis']?['user_text'] ?? "";
    if (txt.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.white.withOpacity(0.20), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: inkFaint, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              txt,
              style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, Color accent) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
              color: accent, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 9),
        Text(
          text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4),
        ),
      ],
    );
  }

  // Carousel kategorisi etiketi
  Widget _carouselLabel(String text, Color ink) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3),
      ),
    );
  }

  // ── MÜZİK KARTI — yatay tam genişlik ──────────────────────
  Widget _buildMusicCard(Map<String, dynamic> data, Color accent) {
    final String title = (data['name'] ?? "Öneri").toString();
    final String artist = (data['artist'] ?? "Sanatçı").toString();
    String? img = (data['image'] ?? data['thumbnail'])?.toString();
    if (img != null && img.startsWith("http://"))
      img = img.replaceFirst("http://", "https://");
    final String? rawUrl =
        (data['url'] ?? data['link'] ?? data['infoLink'])?.toString();
    const Color sg = Color(0xFF1DB954);

    return Container(
      decoration: _cardDecor(),
      child: Row(
        children: [
          
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20)),
            child: img != null
                ? Image.network(img,
                    width: 115,
                    height: 115,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _imgPlaceholder(115, 115, sg, Icons.music_note))
                : _imgPlaceholder(115, 115, sg, Icons.music_note),
          ),
          // İçerik
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge("🎵  MÜZİK TERAPİSİ", sg),
                  const SizedBox(height: 8),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(artist,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  _actionButton("Spotify'da Dinle", sg, rawUrl,
                      leading: Container(
                        width: 15,
                        height: 15,
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                            color: sg, shape: BoxShape.circle),
                        child: const _SpotifyIcon(size: 10),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard(
    String label,
    String emoji,
    Map<String, dynamic> data,
    Color color,
    IconData icon,
    String btnText,
  ) {
    final String title =
        (data['name'] ?? data['title'] ?? "Öneri").toString();
    final String sub =
        (data['artist'] ?? data['author'] ?? data['category'] ?? "Özel")
            .toString();
    String? img =
        (data['image'] ?? data['thumbnail'] ?? data['strMealThumb'])
            ?.toString();
    if (img != null && img.startsWith("http://"))
      img = img.replaceFirst("http://", "https://");
    final String? rawUrl =
        (data['url'] ?? data['link'] ?? data['infoLink'])?.toString();

    return Container(
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: img != null
                ? Image.network(img,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _imgPlaceholder(double.infinity, 130, color, icon))
                : _imgPlaceholder(double.infinity, 130, color, icon),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
               
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _badge("$emoji  $label", color),
                      const SizedBox(height: 8),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(sub,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                ElevatedButton.icon(
                  onPressed: () => _launchRawUrl(rawUrl),
                  icon: Icon(icon, size: 13, color: Colors.white),
                  label: Text(btnText,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── CAROUSEL (Alternatif öneriler) ────────────────────────
  Widget _buildCarousel(
    List<dynamic> items,
    Color color,
    IconData icon, {
    bool isSpotify = false,
  }) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final data = Map<String, dynamic>.from(items[i]);
          final String title =
              (data['name'] ?? data['title'] ?? "Öneri").toString();
          final String sub =
              (data['artist'] ?? data['author'] ?? data['category'] ?? "")
                  .toString();
          String? img =
              (data['image'] ?? data['thumbnail'] ?? data['strMealThumb'])
                  ?.toString();
          if (img != null && img.startsWith("http://"))
            img = img.replaceFirst("http://", "https://");
          final String? rawUrl =
              (data['url'] ?? data['link'] ?? data['infoLink'])?.toString();

          return GestureDetector(
            onTap: () => _launchRawUrl(rawUrl),
            child: Container(
              width: 150,
              margin: EdgeInsets.only(right: i < items.length - 1 ? 12 : 0),
              decoration: _cardDecor(radius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Görsel
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: img != null
                        ? Image.network(img,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imgPlaceholder(150, 80, color, icon))
                        : _imgPlaceholder(150, 80, color, icon),
                  ),
                  // İçerik
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(sub,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          // Alt link butonu
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    color: color, size: 11),
                                const SizedBox(width: 4),
                                Text("Aç",
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ],
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
        },
      ),
    );
  }

  // ── ALTERNATİF TOGGLE ─────────────────────────────────────
  Widget _buildToggleBtn(Color ink, Color accent) {
    return GestureDetector(
      onTap: () =>
          setState(() => _showAlternatives = !_showAlternatives),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white
              .withOpacity(_showAlternatives ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.white.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showAlternatives
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.auto_awesome_rounded,
              color: ink,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _showAlternatives
                  ? "Alternatifleri Gizle"
                  : "Diğer Önerilere de Bak",
              style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  // ── GERİ BİLDİRİM ─────────────────────────────────────────
  Widget _buildFeedbackCard(Color ink, Color inkFaint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: Column(
        children: [
          Text(
            "Bu öneriler sana iyi geldi mi?",
            style: TextStyle(
                color: ink,
                fontSize: 14,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "Geri bildirimin modelin gelişmesine katkı sağlar.",
            style: TextStyle(color: inkFaint, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _feedbackBtn("👍  Evet", ink, "Olumlu")),
              const SizedBox(width: 12),
              Expanded(child: _feedbackBtn("👎  Hayır", ink, "Olumsuz")),
            ],
          ),
          if (_hasVoted) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: ink, size: 15),
                const SizedBox(width: 6),
                Text(
                  "Teşekkürler! Geri bildirimin kaydedildi.",
                  style: TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedbackBtn(String label, Color ink, String oyTipi) {
    return InkWell(
      onTap: _hasVoted ? null : () => _oyVer(oyTipi),
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: _hasVoted ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withOpacity(0.28), width: 1),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  //  ORTAK YARDIMCILAR
  // ════════════════════════════════════════════════════════

  // Standart beyaz kart dekorasyonu
  BoxDecoration _cardDecor({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 5))
      ],
    );
  }

  // Renkli kategori rozeti
  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.8)),
    );
  }

  // Görsel placeholder
  Widget _imgPlaceholder(
      double width, double height, Color color, IconData icon) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      color: color.withOpacity(0.07),
      child: Icon(icon, color: color.withOpacity(0.28), size: 28),
    );
  }

  Widget _actionButton(String label, Color color, String? rawUrl,
      {Widget? leading}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _launchRawUrl(rawUrl),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          minimumSize: const Size(0, 36),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 6)],
            Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  SPOTIFY CUSTOM PAINTER
// ════════════════════════════════════════════════════════

class _SpotifyIcon extends StatelessWidget {
  final double size;
  const _SpotifyIcon({this.size = 16});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _SpotifyPainter());
}

class _SpotifyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;
    final Paint p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    p.strokeWidth = size.width * 0.15;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - r * 0.05, cy + r * 0.08),
            width: r * 1.55,
            height: r * 1.55),
        3.75, 1.75, false, p);
    p.strokeWidth = size.width * 0.13;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - r * 0.05, cy + r * 0.08),
            width: r * 1.05,
            height: r * 1.05),
        3.85, 1.65, false, p);
    p.strokeWidth = size.width * 0.12;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx - r * 0.05, cy + r * 0.08),
            width: r * 0.58,
            height: r * 0.58),
        3.95, 1.55, false, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}