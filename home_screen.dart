import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import 'pdf_screen.dart';
import 'excel_screen.dart';
import 'image_screen.dart';
import 'ppt_screen.dart';
import 'certificate_screen.dart';
import 'convert_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;
  final String? pendingFilePath;
  final VoidCallback? onPendingHandled;

  const HomeScreen({
    super.key,
    this.onToggleTheme,
    this.isDark = false,
    this.pendingFilePath,
    this.onPendingHandled,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  List<Map<String, String>> _recent = [];

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
    _heroCtrl.forward();
    _loadRecent();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.pendingFilePath != null && widget.pendingFilePath != old.pendingFilePath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFilePath(widget.pendingFilePath!);
        widget.onPendingHandled?.call();
      });
    }
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('recent') ?? '[]';
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {
        _recent = list.map((e) => Map<String, String>.from(e)).toList();
      });
    } catch (_) {}
  }

  Future<void> _addRecent(String path) async {
    final name = path.split('/').last;
    final ext = name.split('.').last.toLowerCase();
    _recent.removeWhere((e) => e['path'] == path);
    _recent.insert(0, {
      'name': name,
      'path': path,
      'ext': ext,
      'time': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    if (_recent.length > 15) _recent = _recent.sublist(0, 15);
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('recent', jsonEncode(_recent));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'xlsx', 'xls', 'csv', 'pptx', 'ppt',
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
        'txt', 'md', 'json', 'xml',
      ],
    );
    if (result != null && result.files.single.path != null) {
      _openFilePath(result.files.single.path!);
    }
  }

  void _openFilePath(String path) {
    _addRecent(path);
    final widget = VedantRouter.routeToFile(path);
    Navigator.push(context, MaterialPageRoute(builder: (_) => widget));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomPaint(
        painter: _GridPainter(color: cs.outline.withOpacity(0.4)),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(cs, tt),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: SlideTransition(
                      position: _heroSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHero(cs, tt),
                          const SizedBox(height: 28),
                          _buildOpenButton(cs),
                          const SizedBox(height: 32),
                          _buildSectionLabel('File Types', cs),
                          const SizedBox(height: 10),
                          _buildFileGrid(cs),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Recent Files', cs),
                          const SizedBox(height: 10),
                          _buildRecentList(cs),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, TextTheme tt) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(bottom: BorderSide(color: cs.outline, width: 1)),
      ),
      child: Row(
        children: [
          Text('Vedant', style: GoogleFonts.caveat(
            fontSize: 24, fontWeight: FontWeight.w700, color: cs.onBackground,
          )),
          Text('.', style: GoogleFonts.caveat(
            fontSize: 24, fontWeight: FontWeight.w700, color: cs.primary,
          )),
          const Spacer(),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            color: cs.onSurfaceVariant,
            style: IconButton.styleFrom(
              backgroundColor: cs.surfaceVariant,
              minimumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UNIVERSAL FILE STUDIO',
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 1.5, color: cs.primary,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.caveat(
              fontSize: 58, fontWeight: FontWeight.w700,
              color: cs.onBackground, height: 1.0,
            ),
            children: [
              const TextSpan(text: 'Open &\n'),
              WidgetSpan(
                child: Container(
                  margin: const EdgeInsets.only(top: 2),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Text('edit',
                        style: GoogleFonts.caveat(
                          fontSize: 58, fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _OvalPainter(color: cs.onBackground),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextSpan(
                text: ' any file',
                style: GoogleFonts.caveat(
                  fontSize: 58, fontWeight: FontWeight.w700,
                  color: cs.onBackground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        CustomPaint(
          size: const Size(220, 16),
          painter: _WavePainter(color: cs.primary),
        ),
        const SizedBox(height: 12),
        Text(
          'PDF · Excel · PPT · Images · Certificates',
          style: GoogleFonts.caveat(
            fontSize: 17, color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOpenButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _pickFile,
        icon: const Icon(Icons.folder_open_outlined, size: 20),
        label: Text('Open a File',
          style: GoogleFonts.caveat(
            fontSize: 22, fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.onBackground,
          foregroundColor: cs.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme cs) {
    return Text(label.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 9, fontWeight: FontWeight.w700,
        letterSpacing: 1.4, color: cs.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFileGrid(ColorScheme cs) {
    final cards = [
      _CardData('PDF', 'View & Annotate', cs.primary, Icons.picture_as_pdf_outlined,
          () => _pickFile()),
      _CardData('Excel', 'XLSX · CSV', cs.onBackground, Icons.table_chart_outlined,
          () => _pickFile()),
      _CardData('Slides', 'PPTX Viewer', cs.onSurfaceVariant, Icons.slideshow_outlined,
          () => _pickFile()),
      _CardData('Image', 'Edit & Export', cs.onBackground, Icons.image_outlined,
          () => _pickFile()),
      _CardData('Cert', 'Design it', cs.primary, Icons.workspace_premium_outlined,
          () => _openCert()),
      _CardData('Convert', 'Any format', cs.onSurfaceVariant, Icons.sync_alt_outlined,
          () => _openConvert()),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: cards.map((c) => _FileCard(data: c, cs: cs)).toList(),
    );
  }

  void _openCert() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CertificateScreen()),
    );
  }

  void _openConvert() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConvertScreen()),
    );
  }

  Widget _buildRecentList(ColorScheme cs) {
    if (_recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Text(
          'No recent files yet — open a file to get started.',
          style: GoogleFonts.inter(
            fontSize: 12, color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recent.length.clamp(0, 8),
        separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
        itemBuilder: (_, i) {
          final r = _recent[i];
          return ListTile(
            dense: true,
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _extIcon(r['ext'] ?? ''),
                size: 14, color: cs.onSurfaceVariant,
              ),
            ),
            title: Text(
              r['name'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _relTime(int.tryParse(r['time'] ?? '0') ?? 0),
              style: GoogleFonts.inter(fontSize: 10, color: cs.onSurfaceVariant),
            ),
            onTap: () => _openFilePath(r['path'] ?? ''),
          );
        },
      ),
    );
  }

  IconData _extIcon(String ext) {
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['xlsx', 'xls', 'csv'].contains(ext)) return Icons.table_chart_outlined;
    if (['pptx', 'ppt'].contains(ext)) return Icons.slideshow_outlined;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _relTime(int ms) {
    if (ms == 0) return '';
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    if (diff < 60000) return 'just now';
    if (diff < 3600000) return '${diff ~/ 60000}m ago';
    if (diff < 86400000) return '${diff ~/ 3600000}h ago';
    return '${diff ~/ 86400000}d ago';
  }
}

// ── DATA & WIDGETS ─────────────────────────────────────────────────────────────
class _CardData {
  final String name, sub;
  final Color dotColor;
  final IconData icon;
  final VoidCallback onTap;
  const _CardData(this.name, this.sub, this.dotColor, this.icon, this.onTap);
}

class _FileCard extends StatefulWidget {
  final _CardData data;
  final ColorScheme cs;
  const _FileCard({required this.data, required this.cs});

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.data.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: widget.data.dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const Spacer(),
              Text(widget.data.name,
                style: GoogleFonts.caveat(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: cs.onBackground,
                ),
              ),
              Text(widget.data.sub,
                style: GoogleFonts.inter(
                  fontSize: 9, color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PAINTERS ──────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.7;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

class _WavePainter extends CustomPainter {
  final Color color;
  const _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const amp = 4.0;
    const period = 32.0;
    final path = Path();
    path.moveTo(0, size.height / 2);
    for (double x = 0; x < size.width; x += 1) {
      final y = size.height / 2 + amp * _sin(x / period * 2 * 3.14159);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  double _sin(double x) {
    // Taylor series approximation of sin(x)
    x = x % (2 * 3.14159265);
    double result = x;
    double term = x;
    for (int i = 1; i <= 6; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}

class _OvalPainter extends CustomPainter {
  final Color color;
  const _OvalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromLTRB(-6, -4, size.width + 6, size.height + 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.color != color;
}
