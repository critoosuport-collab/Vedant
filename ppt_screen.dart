import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'dart:io';

class PPTScreen extends StatefulWidget {
  final String filePath;
  const PPTScreen({super.key, required this.filePath});

  @override
  State<PPTScreen> createState() => _PPTScreenState();
}

class _PPTScreenState extends State<PPTScreen> {
  List<_SlideData> _slides = [];
  bool _loading = true;
  String? _error;
  int _current = 0;
  final PageController _pageCtrl = PageController();

  String get _fileName => widget.filePath.split('/').last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final slides = <_SlideData>[];

      // Find slide files: ppt/slides/slide1.xml, slide2.xml, ...
      final slideFiles = archive.files
          .where((f) =>
              f.name.startsWith('ppt/slides/slide') &&
              f.name.endsWith('.xml') &&
              !f.name.contains('/_rels/'))
          .toList();

      // Sort by slide number
      slideFiles.sort((a, b) {
        final na = _slideNumber(a.name);
        final nb = _slideNumber(b.name);
        return na.compareTo(nb);
      });

      for (final file in slideFiles) {
        final xmlStr = String.fromCharCodes(file.content as List<int>);
        try {
          final doc = xml.XmlDocument.parse(xmlStr);
          slides.add(_parseSlide(doc, slides.length + 1));
        } catch (_) {
          slides.add(_SlideData(
            number: slides.length + 1,
            title: 'Slide ${slides.length + 1}',
            body: '',
            shapes: [],
          ));
        }
      }

      if (slides.isEmpty) {
        slides.add(_SlideData(
          number: 1,
          title: _fileName,
          body: 'No slides found',
          shapes: [],
        ));
      }

      setState(() {
        _slides = slides;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _slideNumber(String path) {
    final match = RegExp(r'slide(\d+)\.xml').firstMatch(path);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  _SlideData _parseSlide(xml.XmlDocument doc, int number) {
    // Extract all text from <a:t> elements
    final texts = doc.findAllElements('a:t').map((e) => e.innerText).toList();

    String title = '';
    String body = '';
    final shapes = <String>[];

    // Try to find title placeholder
    final spElements = doc.findAllElements('p:sp');
    for (final sp in spElements) {
      final phType = sp
          .findAllElements('p:ph')
          .firstOrNull
          ?.getAttribute('type');
      final text = sp.findAllElements('a:t').map((e) => e.innerText).join(' ');
      if (text.trim().isEmpty) continue;

      if (phType == 'title' || phType == 'ctrTitle') {
        title = text.trim();
      } else {
        shapes.add(text.trim());
      }
    }

    if (title.isEmpty && texts.isNotEmpty) {
      title = texts.first;
    }

    body = shapes.isNotEmpty ? shapes.join('\n\n') : '';

    return _SlideData(
      number: number,
      title: title.isEmpty ? 'Slide $number' : title,
      body: body,
      shapes: shapes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fileName,
              style: GoogleFonts.caveat(
                fontSize: 18, fontWeight: FontWeight.w700, color: cs.onBackground,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (!_loading && _slides.isNotEmpty)
              Text('${_slides.length} slides',
                style: GoogleFonts.inter(
                  fontSize: 10, color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        bottom: !_loading && _slides.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: (_current + 1) / _slides.length,
                  backgroundColor: cs.outline,
                  color: cs.primary,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: cs.primary))
          : _error != null
              ? _buildError(cs)
              : Row(
                  children: [
                    // Thumbnail rail
                    _buildRail(cs),
                    // Slide view
                    Expanded(child: _buildSlideView(cs)),
                  ],
                ),
      bottomNavigationBar: !_loading && _slides.isNotEmpty
          ? _buildNavBar(cs)
          : null,
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.slideshow_outlined, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text('Cannot open presentation',
              style: GoogleFonts.caveat(
                fontSize: 22, fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!,
              style: GoogleFonts.inter(
                fontSize: 12, color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(ColorScheme cs) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        border: Border(right: BorderSide(color: cs.outline)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _slides.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            _pageCtrl.animateToPage(i,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            height: 44,
            decoration: BoxDecoration(
              color: i == _current ? cs.primary.withOpacity(0.12) : cs.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: i == _current ? cs.primary : cs.outline,
                width: i == _current ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text('${i + 1}',
                style: GoogleFonts.caveat(
                  fontSize: 14,
                  fontWeight: i == _current ? FontWeight.w700 : FontWeight.w400,
                  color: i == _current ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlideView(ColorScheme cs) {
    return PageView.builder(
      controller: _pageCtrl,
      onPageChanged: (i) => setState(() => _current = i),
      itemCount: _slides.length,
      itemBuilder: (_, i) => _buildSlide(cs, _slides[i]),
    );
  }

  Widget _buildSlide(ColorScheme cs, _SlideData slide) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _GridPainter(
            color: cs.outline.withOpacity(0.4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('SLIDE ${slide.number}',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2, color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(slide.title,
                  style: GoogleFonts.caveat(
                    fontSize: 32, fontWeight: FontWeight.w700,
                    color: cs.onBackground, height: 1.1,
                  ),
                ),
                if (slide.body.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(slide.body,
                        style: GoogleFonts.inter(
                          fontSize: 14, color: cs.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(ColorScheme cs) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _current > 0
                ? () => _pageCtrl.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_current + 1} / ${_slides.length}',
            style: GoogleFonts.caveat(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: cs.onBackground,
            ),
          ),
          IconButton(
            onPressed: _current < _slides.length - 1
                ? () => _pageCtrl.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final int number;
  final String title, body;
  final List<String> shapes;
  const _SlideData({
    required this.number,
    required this.title,
    required this.body,
    required this.shapes,
  });
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.6;
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
