import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';

class ImageScreen extends StatefulWidget {
  final String filePath;
  const ImageScreen({super.key, required this.filePath});

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  img.Image? _original;
  img.Image? _edited;
  Uint8List? _previewBytes;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  double _brightness = 0; // -100 to +100
  double _contrast = 0;   // -100 to +100
  double _saturation = 0; // -100 to +100
  double _blur = 0;       // 0 to 10
  int _rotation = 0;      // 0, 90, 180, 270
  bool _flipH = false;
  bool _flipV = false;

  String get _fileName => widget.filePath.split('/').last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Cannot decode image');
      setState(() {
        _original = decoded;
        _edited = decoded;
        _loading = false;
      });
      await _buildPreview();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _buildPreview() async {
    if (_original == null) return;
    setState(() => _processing = true);
    try {
      img.Image result = img.Image.from(_original!);

      // Rotation
      if (_rotation == 90) result = img.copyRotate(result, angle: 90);
      if (_rotation == 180) result = img.copyRotate(result, angle: 180);
      if (_rotation == 270) result = img.copyRotate(result, angle: 270);

      // Flip
      if (_flipH) result = img.flipHorizontal(result);
      if (_flipV) result = img.flipVertical(result);

      // Brightness / contrast / saturation
      if (_brightness != 0 || _contrast != 0 || _saturation != 0) {
        result = img.adjustColor(
          result,
          brightness: _brightness / 100,
          contrast: 1.0 + _contrast / 100,
          saturation: 1.0 + _saturation / 100,
        );
      }

      // Blur
      if (_blur > 0) {
        result = img.gaussianBlur(result, radius: _blur.round().clamp(1, 20));
      }

      setState(() {
        _edited = result;
        _previewBytes = Uint8List.fromList(img.encodeJpg(result, quality: 85));
        _processing = false;
      });
    } catch (e) {
      setState(() => _processing = false);
    }
  }

  void _rotate() {
    setState(() => _rotation = (_rotation + 90) % 360);
    _buildPreview();
  }

  Future<void> _export(String format) async {
    if (_edited == null) return;
    setState(() => _processing = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final base = _fileName.contains('.')
          ? _fileName.substring(0, _fileName.lastIndexOf('.'))
          : _fileName;
      final outPath = '${dir.path}/${base}_edited.$format';

      List<int> encoded;
      if (format == 'jpg') {
        encoded = img.encodeJpg(_edited!, quality: 92);
      } else if (format == 'png') {
        encoded = img.encodePng(_edited!);
      } else {
        encoded = img.encodeJpg(_edited!, quality: 88);
      }

      await File(outPath).writeAsBytes(encoded);
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: $base.$format')),
        );
        await Share.shareXFiles([XFile(outPath)]);
      }
    } catch (e) {
      setState(() => _processing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _reset() {
    setState(() {
      _brightness = 0;
      _contrast = 0;
      _saturation = 0;
      _blur = 0;
      _rotation = 0;
      _flipH = false;
      _flipV = false;
    });
    _buildPreview();
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
            fontSize: 18, fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_loading && _error == null) ...[
            IconButton(
              tooltip: 'Rotate 90°',
              icon: const Icon(Icons.rotate_90_degrees_ccw_outlined, size: 20),
              onPressed: _rotate,
            ),
            IconButton(
              tooltip: 'Flip H',
              icon: const Icon(Icons.flip_outlined, size: 20),
              onPressed: () {
                setState(() => _flipH = !_flipH);
                _buildPreview();
              },
            ),
            IconButton(
              tooltip: 'Reset',
              icon: const Icon(Icons.refresh_outlined, size: 20),
              onPressed: _reset,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.download_outlined, size: 20),
              tooltip: 'Export',
              onSelected: _export,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'jpg', child: Text('Export JPG')),
                const PopupMenuItem(value: 'png', child: Text('Export PNG')),
              ],
            ),
          ],
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: cs.primary))
          : _error != null
              ? _buildError(cs)
              : _buildEditor(cs),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text('Cannot open image',
              style: GoogleFonts.caveat(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.inter(
              fontSize: 12, color: cs.onSurfaceVariant,
            ), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(ColorScheme cs) {
    return Column(
      children: [
        // Image preview
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Container(
                color: cs.surfaceVariant,
                child: Center(
                  child: _previewBytes != null
                      ? Image.memory(_previewBytes!, fit: BoxFit.contain)
                      : Image.file(File(widget.filePath), fit: BoxFit.contain),
                ),
              ),
              if (_processing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Controls
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: cs.background,
              border: Border(top: BorderSide(color: cs.outline)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSlider(
                    cs,
                    label: 'Brightness',
                    value: _brightness,
                    min: -100, max: 100,
                    onChanged: (v) {
                      setState(() => _brightness = v);
                    },
                    onChangeEnd: (_) => _buildPreview(),
                  ),
                  _buildSlider(
                    cs,
                    label: 'Contrast',
                    value: _contrast,
                    min: -100, max: 100,
                    onChanged: (v) {
                      setState(() => _contrast = v);
                    },
                    onChangeEnd: (_) => _buildPreview(),
                  ),
                  _buildSlider(
                    cs,
                    label: 'Saturation',
                    value: _saturation,
                    min: -100, max: 100,
                    onChanged: (v) {
                      setState(() => _saturation = v);
                    },
                    onChangeEnd: (_) => _buildPreview(),
                  ),
                  _buildSlider(
                    cs,
                    label: 'Blur',
                    value: _blur,
                    min: 0, max: 10,
                    onChanged: (v) {
                      setState(() => _blur = v);
                    },
                    onChangeEnd: (_) => _buildPreview(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(
    ColorScheme cs, {
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: value,
                min: min, max: max,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.round().toString(),
              style: GoogleFonts.inter(
                fontSize: 11, color: cs.onBackground,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
