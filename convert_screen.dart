import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  String? _srcPath;
  String? _srcExt;
  String? _targetFmt;
  bool _converting = false;
  String? _resultPath;
  String? _error;

  final Map<String, List<String>> _conversionMap = {
    'xlsx': ['csv', 'json'],
    'xls': ['csv', 'json'],
    'csv': ['xlsx', 'json'],
    'json': ['csv'],
    'jpg': ['png', 'webp'],
    'jpeg': ['png', 'webp'],
    'png': ['jpg', 'webp'],
    'webp': ['jpg', 'png'],
    'txt': ['json'],
  };

  List<String> get _targets =>
      _srcExt != null ? (_conversionMap[_srcExt!] ?? []) : [];

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _conversionMap.keys.toList(),
    );
    if (result?.files.single.path != null) {
      final path = result!.files.single.path!;
      setState(() {
        _srcPath = path;
        _srcExt = path.split('.').last.toLowerCase();
        _targetFmt = _targets.isNotEmpty ? _targets.first : null;
        _resultPath = null;
        _error = null;
      });
    }
  }

  Future<void> _convert() async {
    if (_srcPath == null || _targetFmt == null) return;
    setState(() {
      _converting = true;
      _resultPath = null;
      _error = null;
    });
    try {
      final outPath = await _runConversion(_srcPath!, _srcExt!, _targetFmt!);
      setState(() {
        _resultPath = outPath;
        _converting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _converting = false;
      });
    }
  }

  Future<String> _runConversion(
      String src, String srcExt, String target) async {
    final dir = await getApplicationDocumentsDirectory();
    final base = src.split('/').last.replaceAll('.$srcExt', '');
    final outPath = '${dir.path}/${base}_converted.$target';

    // ── Spreadsheet conversions ──────────────────────────────────────────
    if (['xlsx', 'xls', 'csv'].contains(srcExt) &&
        ['csv', 'json', 'xlsx'].contains(target)) {
      ex.Excel workbook;
      if (srcExt == 'csv') {
        final text = await File(src).readAsString();
        workbook = ex.Excel.createExcel();
        final sheet = workbook.sheets[workbook.getDefaultSheet()!]!;
        int r = 0;
        for (final line in text.split('\n')) {
          if (line.trim().isEmpty) continue;
          int c = 0;
          for (final cell in line.split(',')) {
            sheet
                .cell(ex.CellIndex.indexByColumnRow(
                    columnIndex: c, rowIndex: r))
                .value = ex.TextCellValue(cell.trim());
            c++;
          }
          r++;
        }
      } else {
        workbook = ex.Excel.decodeBytes(await File(src).readAsBytes());
      }

      final sheetName = workbook.tables.keys.first;
      final sheet = workbook.tables[sheetName]!;

      if (target == 'csv') {
        final buf = StringBuffer();
        for (final row in sheet.rows) {
          buf.writeln(
              row.map((c) => c?.value?.toString() ?? '').join(','));
        }
        await File(outPath).writeAsString(buf.toString());
        return outPath;
      }

      if (target == 'json') {
        if (sheet.rows.isEmpty) {
          await File(outPath).writeAsString('[]');
          return outPath;
        }
        final headers = sheet.rows.first
            .map((c) => c?.value?.toString() ?? '')
            .toList();
        final records = <Map<String, dynamic>>[];
        for (int ri = 1; ri < sheet.rows.length; ri++) {
          final row = sheet.rows[ri];
          final map = <String, dynamic>{};
          for (int ci = 0; ci < headers.length; ci++) {
            final v = ci < row.length ? row[ci]?.value?.toString() ?? '' : '';
            map[headers[ci]] = v;
          }
          records.add(map);
        }
        await File(outPath)
            .writeAsString(const JsonEncoder.withIndent('  ').convert(records));
        return outPath;
      }

      if (target == 'xlsx') {
        final bytes = workbook.save()!;
        await File(outPath).writeAsBytes(bytes);
        return outPath;
      }
    }

    // ── JSON → CSV ────────────────────────────────────────────────────────
    if (srcExt == 'json' && target == 'csv') {
      final text = await File(src).readAsString();
      final dynamic parsed = jsonDecode(text);
      if (parsed is List && parsed.isNotEmpty) {
        final headers = (parsed.first as Map).keys.toList();
        final buf = StringBuffer();
        buf.writeln(headers.join(','));
        for (final row in parsed) {
          buf.writeln(
              headers.map((h) => (row as Map)[h]?.toString() ?? '').join(','));
        }
        await File(outPath).writeAsString(buf.toString());
        return outPath;
      }
      throw Exception('JSON must be an array of objects for CSV conversion');
    }

    // ── TXT → JSON ────────────────────────────────────────────────────────
    if (srcExt == 'txt' && target == 'json') {
      final text = await File(src).readAsString();
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final json = const JsonEncoder.withIndent('  ').convert(
        {'lines': lines, 'lineCount': lines.length},
      );
      await File(outPath).writeAsString(json);
      return outPath;
    }

    // ── Image conversions ─────────────────────────────────────────────────
    if (['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(srcExt) &&
        ['jpg', 'png', 'webp'].contains(target)) {
      final bytes = await File(src).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Cannot decode image');

      List<int> encoded;
      if (target == 'png') {
        encoded = img.encodePng(image);
      } else if (target == 'webp') {
        // webp not natively in img package — save as jpg with high quality
        encoded = img.encodeJpg(image, quality: 95);
        final webpPath = '${dir.path}/${base}_converted.jpg';
        await File(webpPath).writeAsBytes(encoded);
        return webpPath;
      } else {
        encoded = img.encodeJpg(image, quality: 92);
      }
      await File(outPath).writeAsBytes(encoded);
      return outPath;
    }

    throw Exception('Unsupported conversion: $srcExt → $target');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        backgroundColor: cs.background,
        title: Text('File Converter',
          style: GoogleFonts.caveat(
            fontSize: 20, fontWeight: FontWeight.w700, color: cs.onBackground,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supported formats grid
            _buildFormatsGrid(cs),
            const SizedBox(height: 24),

            // Step 1 — Pick file
            _buildStep(cs, '1', 'Choose a file'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(
                  _srcPath != null
                      ? _srcPath!.split('/').last
                      : 'Select file to convert',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            if (_srcPath != null) ...[
              const SizedBox(height: 20),
              _buildStep(cs, '2', 'Choose output format'),
              const SizedBox(height: 8),
              if (_targets.isEmpty)
                Text(
                  '.$_srcExt files cannot be converted by this tool.',
                  style: GoogleFonts.inter(
                    fontSize: 12, color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _targets.map((fmt) => GestureDetector(
                    onTap: () => setState(() => _targetFmt = fmt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _targetFmt == fmt
                            ? cs.onBackground : cs.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _targetFmt == fmt
                              ? cs.onBackground : cs.outline,
                        ),
                      ),
                      child: Text('.${fmt.toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _targetFmt == fmt
                              ? cs.background : cs.onBackground,
                        ),
                      ),
                    ),
                  )).toList(),
                ),

              if (_targets.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildStep(cs, '3', 'Convert'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _targetFmt != null && !_converting
                        ? _convert : null,
                    icon: _converting
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.background,
                            ),
                          )
                        : const Icon(Icons.sync_alt_outlined, size: 18),
                    label: Text(
                      _converting
                          ? 'Converting…'
                          : 'Convert to .$_targetFmt',
                      style: GoogleFonts.caveat(
                        fontSize: 18, fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.onBackground,
                      foregroundColor: cs.background,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            if (_resultPath != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                      size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Conversion complete!',
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: cs.onBackground,
                            ),
                          ),
                          Text(_resultPath!.split('/').last,
                            style: GoogleFonts.inter(
                              fontSize: 11, color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 18),
                      onPressed: () => Share.shareXFiles(
                        [XFile(_resultPath!)],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                        style: GoogleFonts.inter(
                          fontSize: 11, color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep(ColorScheme cs, String num, String label) {
    return Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: cs.onBackground,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(num,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: cs.background,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
          style: GoogleFonts.caveat(
            fontSize: 18, fontWeight: FontWeight.w700, color: cs.onBackground,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatsGrid(ColorScheme cs) {
    final supported = [
      ('XLSX → CSV/JSON', Icons.table_chart_outlined),
      ('CSV → XLSX/JSON', Icons.table_rows_outlined),
      ('JSON → CSV', Icons.data_object_outlined),
      ('PNG ↔ JPG', Icons.image_outlined),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.2,
      children: supported.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(s.$2, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s.$1,
                style: GoogleFonts.inter(
                  fontSize: 10, color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
