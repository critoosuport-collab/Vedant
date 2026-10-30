import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final _nameCtrl = TextEditingController(text: 'Vedant More');
  final _achieveCtrl = TextEditingController(text: 'Excellence in Innovation');
  final _orgCtrl = TextEditingController(text: 'Vedant Studio');
  final _dateCtrl = TextEditingController(
    text: DateTime.now().toString().substring(0, 10),
  );

  int _style = 0; // 0 = Classic, 1 = Modern, 2 = Minimal
  bool _exporting = false;

  final GlobalKey _certKey = GlobalKey();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _achieveCtrl.dispose();
    _orgCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary = _certKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/certificate_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outPath).writeAsBytes(bytes);

      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate exported as PNG')),
        );
        await Share.shareXFiles([XFile(outPath)],
          text: 'Certificate — ${_nameCtrl.text}');
      }
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.background,
        title: Text('Certificate Designer',
          style: GoogleFonts.caveat(
            fontSize: 20, fontWeight: FontWeight.w700, color: cs.onBackground,
          ),
        ),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Export PNG',
              icon: Icon(Icons.download_outlined, size: 20, color: cs.primary),
              onPressed: _export,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Style selector
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _StyleChip(
                    label: ['Classic', 'Modern', 'Minimal'][i],
                    selected: _style == i,
                    cs: cs,
                    onTap: () => setState(() => _style = i),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Preview
            RepaintBoundary(
              key: _certKey,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildCertificate(key: ValueKey(_style)),
              ),
            ),
            const SizedBox(height: 24),

            // Inputs
            _buildInput(cs, 'Recipient Name', _nameCtrl, Icons.person_outline),
            _buildInput(cs, 'Achievement / Title', _achieveCtrl,
                Icons.workspace_premium_outlined),
            _buildInput(cs, 'Issuing Organization', _orgCtrl,
                Icons.business_outlined),
            _buildInput(cs, 'Date', _dateCtrl, Icons.calendar_today_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    ColorScheme cs,
    String label,
    TextEditingController ctrl,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 13, color: cs.onBackground),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: cs.onSurfaceVariant),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificate({Key? key}) {
    switch (_style) {
      case 1:
        return _ModernCert(key: key,
          name: _nameCtrl.text,
          achieve: _achieveCtrl.text,
          org: _orgCtrl.text,
          date: _dateCtrl.text,
        );
      case 2:
        return _MinimalCert(key: key,
          name: _nameCtrl.text,
          achieve: _achieveCtrl.text,
          org: _orgCtrl.text,
          date: _dateCtrl.text,
        );
      default:
        return _ClassicCert(key: key,
          name: _nameCtrl.text,
          achieve: _achieveCtrl.text,
          org: _orgCtrl.text,
          date: _dateCtrl.text,
        );
    }
  }
}

// ── STYLE CHIP ─────────────────────────────────────────────────────────────────
class _StyleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.onBackground : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? cs.onBackground : cs.outline),
        ),
        child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? cs.background : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── CLASSIC CERT ──────────────────────────────────────────────────────────────
class _ClassicCert extends StatelessWidget {
  final String name, achieve, org, date;
  const _ClassicCert({
    super.key,
    required this.name,
    required this.achieve,
    required this.org,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCC2222), width: 3),
      ),
      child: Column(
        children: [
          // Double border effect
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCC2222), width: 1),
            ),
            child: Column(
              children: [
                Text('CERTIFICATE', style: GoogleFonts.caveat(
                  fontSize: 13, letterSpacing: 6, fontWeight: FontWeight.w700,
                  color: const Color(0xFFCC2222),
                )),
                const SizedBox(height: 2),
                Text('OF ACHIEVEMENT', style: GoogleFonts.inter(
                  fontSize: 9, letterSpacing: 3, color: const Color(0xFF999999),
                )),
                const SizedBox(height: 20),
                Text('This certificate is proudly presented to',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                Text(name, style: GoogleFonts.caveat(
                  fontSize: 40, fontWeight: FontWeight.w700,
                  color: const Color(0xFF111111),
                )),
                const SizedBox(height: 4),
                Container(height: 1.5, width: 200, color: const Color(0xFFCC2222)),
                const SizedBox(height: 14),
                Text('In recognition of outstanding', style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF666666),
                )),
                const SizedBox(height: 4),
                Text(achieve, style: GoogleFonts.caveat(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: const Color(0xFF111111),
                )),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Container(height: 1, width: 100, color: const Color(0xFF999999)),
                        const SizedBox(height: 4),
                        Text(date, style: GoogleFonts.inter(
                          fontSize: 9, color: const Color(0xFF999999),
                        )),
                        Text('Date', style: GoogleFonts.inter(
                          fontSize: 8, color: const Color(0xFFBBBBBB),
                        )),
                      ],
                    ),
                    Column(
                      children: [
                        Container(height: 1, width: 100, color: const Color(0xFF999999)),
                        const SizedBox(height: 4),
                        Text(org, style: GoogleFonts.inter(
                          fontSize: 9, color: const Color(0xFF999999),
                        )),
                        Text('Organization', style: GoogleFonts.inter(
                          fontSize: 8, color: const Color(0xFFBBBBBB),
                        )),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MODERN CERT ───────────────────────────────────────────────────────────────
class _ModernCert extends StatelessWidget {
  final String name, achieve, org, date;
  const _ModernCert({
    super.key,
    required this.name,
    required this.achieve,
    required this.org,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Red accent strip left
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFCC2222),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
          ),
          // Red circle top-right
          Positioned(
            right: -30, top: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCC2222).withOpacity(0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CERTIFICATE OF ACHIEVEMENT',
                  style: GoogleFonts.inter(
                    fontSize: 8, letterSpacing: 2.5, fontWeight: FontWeight.w700,
                    color: const Color(0xFFCC2222),
                  ),
                ),
                const SizedBox(height: 8),
                Text(name, style: GoogleFonts.caveat(
                  fontSize: 36, fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
                const SizedBox(height: 2),
                Text(achieve, style: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFFAAAAAA), fontWeight: FontWeight.w300,
                )),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC2222).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFCC2222).withOpacity(0.4),
                        ),
                      ),
                      child: Text(org, style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFFCC2222),
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                    const Spacer(),
                    Text(date, style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF666666),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MINIMAL CERT ──────────────────────────────────────────────────────────────
class _MinimalCert extends StatelessWidget {
  final String name, achieve, org, date;
  const _MinimalCert({
    super.key,
    required this.name,
    required this.achieve,
    required this.org,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 2, color: const Color(0xFFCC2222)),
              const SizedBox(width: 8),
              Text('Certificate', style: GoogleFonts.inter(
                fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600,
                color: const Color(0xFFCC2222),
              )),
            ],
          ),
          const SizedBox(height: 24),
          Text(name, style: GoogleFonts.caveat(
            fontSize: 44, fontWeight: FontWeight.w700,
            color: const Color(0xFF111111), height: 1,
          )),
          const SizedBox(height: 12),
          Text(achieve, style: GoogleFonts.inter(
            fontSize: 14, color: const Color(0xFF555555), fontWeight: FontWeight.w300,
          )),
          const SizedBox(height: 32),
          Row(
            children: [
              _Info(label: 'Issued by', value: org),
              const SizedBox(width: 32),
              _Info(label: 'Date', value: date),
            ],
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label, value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(
          fontSize: 8, letterSpacing: 1.2, color: const Color(0xFFBBBBBB),
        )),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: const Color(0xFF333333),
        )),
      ],
    );
  }
}
