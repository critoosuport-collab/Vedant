import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart' as ex;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class ExcelScreen extends StatefulWidget {
  final String filePath;
  final bool isText;
  const ExcelScreen({super.key, required this.filePath, this.isText = false});

  @override
  State<ExcelScreen> createState() => _ExcelScreenState();
}

class _ExcelScreenState extends State<ExcelScreen>
    with SingleTickerProviderStateMixin {
  ex.Excel? _workbook;
  String? _textContent;
  bool _loading = true;
  String? _error;
  int _activeSheet = 0;
  final Map<String, TextEditingController> _controllers = {};
  bool _dirty = false;

  String get _fileName => widget.filePath.split('/').last;
  bool get _isCsv =>
      widget.filePath.toLowerCase().endsWith('.csv') || widget.isText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.isText) {
        final content = await File(widget.filePath).readAsString();
        setState(() {
          _textContent = content;
          _loading = false;
        });
        return;
      }

      final bytes = await File(widget.filePath).readAsBytes();
      final ext = widget.filePath.split('.').last.toLowerCase();

      if (ext == 'csv') {
        final text = String.fromCharCodes(bytes);
        final workbook = ex.Excel.createExcel();
        final sheet = workbook.sheets[workbook.getDefaultSheet()!]!;
        int row = 0;
        for (final line in text.split('\n')) {
          if (line.trim().isEmpty) continue;
          int col = 0;
          for (final cell in line.split(',')) {
            sheet
                .cell(ex.CellIndex.indexByColumnRow(
                    columnIndex: col, rowIndex: row))
                .value = ex.TextCellValue(cell.trim());
            col++;
          }
          row++;
        }
        setState(() {
          _workbook = workbook;
          _loading = false;
        });
      } else {
        final workbook = ex.Excel.decodeBytes(bytes);
        setState(() {
          _workbook = workbook;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  TextEditingController _ctrl(int sheetIdx, int row, int col) {
    final key = '$sheetIdx,$row,$col';
    if (!_controllers.containsKey(key)) {
      final sheet = _workbook!.tables.values.elementAt(sheetIdx);
      final cell = row < sheet.rows.length && col < sheet.rows[row].length
          ? sheet.rows[row][col]
          : null;
      String value = '';
      if (cell?.value != null) {
        value = cell!.value.toString();
      }
      _controllers[key] = TextEditingController(text: value);
    }
    return _controllers[key]!;
  }

  void _addRow() {
    if (_workbook == null) return;
    final sheetName = _workbook!.tables.keys.elementAt(_activeSheet);
    final sheet = _workbook!.tables[sheetName]!;
    final newRow = sheet.maxRows;
    final cols = sheet.maxCols;
    for (int c = 0; c < cols; c++) {
      sheet
          .cell(ex.CellIndex.indexByColumnRow(
              columnIndex: c, rowIndex: newRow))
          .value = ex.TextCellValue('');
    }
    setState(() => _dirty = true);
  }

  void _addColumn() {
    if (_workbook == null) return;
    final sheetName = _workbook!.tables.keys.elementAt(_activeSheet);
    final sheet = _workbook!.tables[sheetName]!;
    final newCol = sheet.maxCols;
    for (int r = 0; r < sheet.maxRows; r++) {
      sheet
          .cell(ex.CellIndex.indexByColumnRow(
              columnIndex: newCol, rowIndex: r))
          .value = ex.TextCellValue('');
    }
    setState(() => _dirty = true);
  }

  Future<void> _saveXlsx() async {
    if (_workbook == null) return;
    _flushControllers();
    try {
      final bytes = _workbook!.save()!;
      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/${_fileName.replaceAll('.csv', '.xlsx')}';
      await File(outPath).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $outPath')),
        );
        setState(() => _dirty = false);
        await Share.shareXFiles([XFile(outPath)]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _saveCsv() async {
    if (_workbook == null) return;
    _flushControllers();
    try {
      final sheetName = _workbook!.tables.keys.elementAt(_activeSheet);
      final sheet = _workbook!.tables[sheetName]!;
      final buf = StringBuffer();
      for (final row in sheet.rows) {
        buf.writeln(
            row.map((c) => c?.value?.toString() ?? '').join(','));
      }
      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/${_fileName.replaceAll('.xlsx', '.csv')}';
      await File(outPath).writeAsString(buf.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $outPath')),
        );
        await Share.shareXFiles([XFile(outPath)]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  void _flushControllers() {
    if (_workbook == null) return;
    for (final entry in _controllers.entries) {
      final parts = entry.key.split(',');
      final si = int.parse(parts[0]);
      final row = int.parse(parts[1]);
      final col = int.parse(parts[2]);
      if (si >= _workbook!.tables.length) continue;
      final sheetName = _workbook!.tables.keys.elementAt(si);
      final sheet = _workbook!.tables[sheetName]!;
      if (row < sheet.maxRows && col < sheet.maxCols) {
        sheet
            .cell(ex.CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: row))
            .value = ex.TextCellValue(entry.value.text);
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
        title: Text(_fileName,
          style: GoogleFonts.caveat(
            fontSize: 18, fontWeight: FontWeight.w700, color: cs.onBackground,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!widget.isText && _workbook != null) ...[
            IconButton(
              tooltip: 'Add Row',
              icon: const Icon(Icons.add_box_outlined, size: 20),
              onPressed: _addRow,
            ),
            IconButton(
              tooltip: 'Add Column',
              icon: const Icon(Icons.view_column_outlined, size: 20),
              onPressed: _addColumn,
            ),
            IconButton(
              tooltip: 'Save XLSX',
              icon: Icon(Icons.save_outlined, size: 20,
                color: _dirty ? cs.primary : null),
              onPressed: _saveXlsx,
            ),
          ],
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2, color: cs.primary,
              ),
            )
          : _error != null
              ? _buildError(cs)
              : widget.isText
                  ? _buildTextView(cs)
                  : _buildSpreadsheet(cs),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text('Could not open file',
              style: GoogleFonts.caveat(
                fontSize: 22, fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
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

  Widget _buildTextView(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _textContent ?? '',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: cs.onBackground,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildSpreadsheet(ColorScheme cs) {
    if (_workbook == null || _workbook!.tables.isEmpty) {
      return Center(
        child: Text('Empty file',
          style: GoogleFonts.caveat(
            fontSize: 22, color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    final sheetNames = _workbook!.tables.keys.toList();
    final sheet = _workbook!.tables.values.elementAt(_activeSheet);

    return Column(
      children: [
        // Sheet tabs
        if (sheetNames.length > 1)
          Container(
            height: 36,
            color: cs.surfaceVariant,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: sheetNames.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _activeSheet = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: i == _activeSheet ? cs.background : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: i == _activeSheet ? cs.primary : cs.outline,
                    ),
                  ),
                  child: Center(
                    child: Text(sheetNames[i],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: i == _activeSheet
                            ? FontWeight.w600 : FontWeight.w400,
                        color: i == _activeSheet
                            ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTable(cs, sheet),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(ColorScheme cs, dynamic sheet) {
    const cellW = 110.0;
    const cellH = 36.0;
    final rows = sheet.rows as List;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Empty sheet',
          style: GoogleFonts.inter(color: cs.onSurfaceVariant),
        ),
      );
    }

    return Table(
      defaultColumnWidth: const FixedColumnWidth(cellW),
      border: TableBorder(
        horizontalInside: BorderSide(color: cs.outline, width: 0.5),
        verticalInside: BorderSide(color: cs.outline, width: 0.5),
        bottom: BorderSide(color: cs.outline),
        right: BorderSide(color: cs.outline),
      ),
      children: List.generate(rows.length, (ri) {
        final row = rows[ri] as List;
        return TableRow(
          decoration: BoxDecoration(
            color: ri == 0 ? cs.surfaceVariant : null,
          ),
          children: List.generate(row.length, (ci) {
            final ctrl = _ctrl(_activeSheet, ri, ci);
            return SizedBox(
              height: cellH,
              child: TextFormField(
                controller: ctrl,
                onChanged: (_) => setState(() => _dirty = true),
                style: GoogleFonts.inter(
                  fontSize: ri == 0 ? 11 : 12,
                  fontWeight: ri == 0 ? FontWeight.w600 : FontWeight.w400,
                  color: cs.onBackground,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
