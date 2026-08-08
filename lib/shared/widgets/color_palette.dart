import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pastel palette offered in the class color picker, matching the
/// "soft rounded corners, pastel color-coding per subject" design note.
const List<String> kPastelPalette = [
  '#FFB3BA', // pastel red
  '#FFDFBA', // pastel orange
  '#FFFFBA', // pastel yellow
  '#BAFFC9', // pastel green
  '#BAE1FF', // pastel blue
  '#D5BAFF', // pastel purple
  '#FFBAF0', // pastel pink
  '#C9C9C9', // pastel grey
];

Color hexToColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

String colorToHex(Color color) {
  final hex = color.value.toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2).toUpperCase()}';
}

/// Row of pastel swatches plus a "custom" tile that opens a full color
/// picker. Some users won't be happy with any of the 8 presets, so this
/// makes sure the entire color spectrum is reachable, not just the
/// pastel set — while still defaulting to the quick-tap palette for
/// people who just want something fast.
class ColorPickerRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  bool get _selectedIsCustom =>
      !kPastelPalette.any((hex) => hex.toUpperCase() == selected.toUpperCase());

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...kPastelPalette.map((hex) {
          final isSelected = hex.toUpperCase() == selected.toUpperCase();
          return _Swatch(
            color: hexToColor(hex),
            selected: isSelected,
            onTap: () => onSelected(hex),
          );
        }),
        // If the user previously picked a custom color, show it as its
        // own selected swatch so the row doesn't look like nothing is
        // chosen.
        if (_selectedIsCustom)
          _Swatch(
            color: hexToColor(selected),
            selected: true,
            onTap: () => _openPicker(context),
          ),
        _AddCustomColorButton(onTap: () => _openPicker(context)),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final initial = hexToColor(selected);
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _CustomColorPickerDialog(initialColor: initial),
    );
    if (picked != null) {
      onSelected(colorToHex(picked));
    }
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black87 : Colors.black12,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                size: 18,
                color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
              )
            : null,
      ),
    );
  }
}

/// Dashed-ish "+" tile that opens the full picker. Styled to read as
/// "more colors" rather than another preset swatch.
class _AddCustomColorButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCustomColorButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Colors.red, Colors.yellow, Colors.green, Colors.cyan,
              Colors.blue, Colors.purple, Colors.red,
            ],
          ),
          border: Border.all(color: Colors.black12, width: 1),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 18, color: Colors.white, shadows: [
            Shadow(color: Colors.black45, blurRadius: 3),
          ]),
        ),
      ),
    );
  }
}

/// Full-spectrum picker: hex entry + HSV sliders, with the pastel
/// palette also available inline for a quick jump-off point.
class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _CustomColorPickerDialog({required this.initialColor});

  @override
  State<_CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexCtrl;
  String? _hexError;

  Color get _current => _hsv.toColor();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexCtrl = TextEditingController(text: colorToHex(_current));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _updateFromHsv(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      _hexCtrl.text = colorToHex(_current);
      _hexError = null;
    });
  }

  void _submitHex(String value) {
    final cleaned = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
      setState(() => _hexError = 'Enter 6 hex digits, e.g. 4F86C6');
      return;
    }
    setState(() {
      _hsv = HSVColor.fromColor(hexToColor(cleaned));
      _hexError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        // Must constrain BOTH dimensions here, not just maxHeight.
        // BoxConstraints() defaults maxWidth to double.infinity, so a
        // height-only constraint silently strips the bounded width the
        // Dialog would otherwise provide — every child below that needs
        // a finite width (like the Expanded(TextField) in the hex row)
        // then fails to lay out at all, which is what produced the
        // "BoxConstraints forces an infinite width" crash and left the
        // dialog completely blank.
        constraints: BoxConstraints(
          maxWidth: screenSize.width * 0.9,
          maxHeight: screenSize.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pick a color',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _current,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Hex code',
                      prefixText: '#',
                      errorText: _hexError,
                    ),
                    onSubmitted: _submitHex,
                    onEditingComplete: () => _submitHex(_hexCtrl.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SliderRow(
              label: 'Hue',
              value: _hsv.hue,
              min: 0,
              max: 360,
              trackColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
              onChanged: (v) => _updateFromHsv(_hsv.withHue(v)),
            ),
            _SliderRow(
              label: 'Saturation',
              value: _hsv.saturation,
              min: 0,
              max: 1,
              trackColor: _hsv.withSaturation(1).toColor(),
              onChanged: (v) => _updateFromHsv(_hsv.withSaturation(v)),
            ),
            _SliderRow(
              label: 'Brightness',
              value: _hsv.value,
              min: 0,
              max: 1,
              trackColor: _hsv.withValue(1).toColor(),
              onChanged: (v) => _updateFromHsv(_hsv.withValue(v)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quick picks',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kPastelPalette.map((hex) {
                return GestureDetector(
                  onTap: () => _updateFromHsv(HSVColor.fromColor(hexToColor(hex))),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: hexToColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  // The app-wide FilledButtonThemeData sets
                  // minimumSize: Size.fromHeight(52), i.e. infinite
                  // width — meant for full-width buttons alone in a
                  // Column. Placed in this Row next to Cancel with no
                  // Expanded around it, that infinite-width demand has
                  // nowhere to go and breaks layout, so it's overridden
                  // here with a normal, bounded button size.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 46),
                  ),
                  onPressed: () => Navigator.pop(context, _current),
                  child: const Text('Use Color'),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color trackColor;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.trackColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: trackColor,
            thumbColor: trackColor,
            overlayColor: trackColor.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}