import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

Color hexToColor(String hex) =>
    Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

String colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

// ── HSV Color Picker Dialog ───────────────────────────────────────────────────

Future<String?> showGroupColorPicker(
  BuildContext context, {
  String? initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ColorPickerSheet(initial: initial),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  final String? initial;
  const _ColorPickerSheet({this.initial});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;
  late TextEditingController _hexCtrl;
  final GlobalKey _svKey = GlobalKey();
  final GlobalKey _hueKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final init = widget.initial != null
        ? hexToColor(widget.initial!)
        : const Color(0xFF4F7CFF);
    _hsv = HSVColor.fromColor(init);
    _hexCtrl = TextEditingController(
      text: colorToHex(init).replaceAll('#', ''),
    );
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      _hexCtrl.text = colorToHex(hsv.toColor()).replaceAll('#', '');
    });
  }

  void _onHexChanged(String raw) {
    final clean = raw.replaceAll('#', '');
    if (clean.length == 6) {
      try {
        final color = hexToColor('#$clean');
        setState(() => _hsv = HSVColor.fromColor(color));
      } catch (_) {}
    }
  }

  // Position relative to widget → saturation & value
  void _handleSVDrag(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
    _setHsv(_hsv.withSaturation(s).withValue(v));
  }

  Offset _svToLocal(Size size) {
    return Offset(_hsv.saturation * size.width, (1 - _hsv.value) * size.height);
  }

  void _handleHueDrag(Offset local, Size size) {
    final h = (local.dx / size.width * 360).clamp(0.0, 360.0);
    _setHsv(_hsv.withHue(h));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── SV square ────────────────────────────────────────────
          LayoutBuilder(builder: (_, constraints) {
            final size = Size(constraints.maxWidth, 200);
            return GestureDetector(
              onPanStart: (d) => _handleSVDrag(d.localPosition, size),
              onPanUpdate: (d) => _handleSVDrag(d.localPosition, size),
              onTapDown: (d) => _handleSVDrag(d.localPosition, size),
              child: SizedBox(
                key: _svKey,
                width: size.width,
                height: size.height,
                child: CustomPaint(
                  painter: _SVPainter(_hsv.hue, _svToLocal(size)),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // ── Hue bar ──────────────────────────────────────────────
          LayoutBuilder(builder: (_, constraints) {
            final size = Size(constraints.maxWidth, 24);
            return GestureDetector(
              onPanStart: (d) => _handleHueDrag(d.localPosition, size),
              onPanUpdate: (d) => _handleHueDrag(d.localPosition, size),
              onTapDown: (d) => _handleHueDrag(d.localPosition, size),
              child: SizedBox(
                key: _hueKey,
                width: size.width,
                height: size.height,
                child: CustomPaint(
                  painter: _HuePainter(_hsv.hue / 360),
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // ── Preview + hex input ──────────────────────────────────
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _hexCtrl,
                  onChanged: _onHexChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    prefixText: '#',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    hintText: 'RRGGBB',
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Actions ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, colorToHex(color)),
                  child: const Text('Ajouter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _SVPainter extends CustomPainter {
  final double hue;
  final Offset cursor;

  _SVPainter(this.hue, this.cursor);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // White → saturated hue
    final satPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
      ).createShader(rect);
    canvas.drawRRect(rrect, satPaint);

    // Transparent → black
    final valPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRRect(rrect, valPaint);

    // Cursor
    final cursorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(cursor, 10, Paint()..color = Colors.black38);
    canvas.drawCircle(cursor, 9, cursorPaint);
  }

  @override
  bool shouldRepaint(_SVPainter old) =>
      old.hue != hue || old.cursor != cursor;
}

class _HuePainter extends CustomPainter {
  final double position; // 0..1

  _HuePainter(this.position);

  static const _hueColors = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    // Rainbow gradient
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(colors: _hueColors).createShader(rect),
    );

    // Cursor line
    final x = position * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2, -2, 4, size.height + 4),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1, -1, 2, size.height + 2),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.black45,
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.position != position;
}

// ── ColorPickerRow widget ─────────────────────────────────────────────────────

class ColorPickerRow extends StatelessWidget {
  final String? selected;
  final List<String> extraColors;
  final ValueChanged<String> onSelect;
  final ValueChanged<String>? onAddColor;

  /// Palette de base affichée. Par défaut : AppColors.tabPalette.
  final List<String>? basePalette;

  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onSelect,
    this.extraColors = const [],
    this.onAddColor,
    this.basePalette,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...(basePalette ?? AppColors.tabPalette), ...extraColors];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...all.map((hex) => _ColorCircle(
              hex: hex,
              isSelected: selected == hex,
              onTap: () => onSelect(hex),
            )),
        if (onAddColor != null)
          GestureDetector(
            onTap: () async {
              final hex = await showGroupColorPicker(context, initial: selected);
              if (hex != null) onAddColor!(hex);
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
                color: AppColors.background,
              ),
              child: const Icon(Icons.add, size: 16, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final String hex;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.hex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black38 : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }
}
