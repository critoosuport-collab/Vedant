import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class PDFScreen extends StatefulWidget {
  final String filePath;
  const PDFScreen({super.key, required this.filePath});

  @override
  State<PDFScreen> createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> {
  PDFViewController? _ctrl;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String? _error;

  String get _fileName => widget.filePath.split('/').last;

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
            if (_isReady)
              Text('$_totalPages pages',
                style: GoogleFonts.inter(
                  fontSize: 10, color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (_isReady) ...[
            IconButton(
              icon: const Icon(Icons.first_page, size: 20),
              onPressed: _currentPage > 0
                  ? () => _ctrl?.setPage(0)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page, size: 20),
              onPressed: _currentPage < _totalPages - 1
                  ? () => _ctrl?.setPage(_totalPages - 1)
                  : null,
            ),
          ],
        ],
        bottom: _isReady
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0,
                  backgroundColor: cs.outline,
                  color: cs.primary,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: _error != null
          ? _buildError(cs)
          : Stack(
              children: [
                PDFView(
                  filePath: widget.filePath,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  fitPolicy: FitPolicy.WIDTH,
                  backgroundColor: cs.background == Colors.white
                      ? '#FFFFFF'
                      : '#0E0E0E',
                  onError: (e) => setState(() => _error = e.toString()),
                  onRender: (pages) => setState(() {
                    _totalPages = pages ?? 0;
                    _isReady = true;
                  }),
                  onViewCreated: (ctrl) => setState(() => _ctrl = ctrl),
                  onPageChanged: (page, total) => setState(() {
                    _currentPage = page ?? 0;
                    _totalPages = total ?? 0;
                  }),
                ),
                if (!_isReady)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Loading PDF…',
                          style: GoogleFonts.inter(
                            fontSize: 12, color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: _isReady
          ? _buildPageBar(cs)
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
            Icon(Icons.error_outline, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text('Could not open PDF',
              style: GoogleFonts.caveat(
                fontSize: 22, fontWeight: FontWeight.w700, color: cs.onBackground,
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

  Widget _buildPageBar(ColorScheme cs) {
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
            onPressed: _currentPage > 0
                ? () => _ctrl?.setPage(_currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Page ${_currentPage + 1} of $_totalPages',
            style: GoogleFonts.caveat(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: cs.onBackground,
            ),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages - 1
                ? () => _ctrl?.setPage(_currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
