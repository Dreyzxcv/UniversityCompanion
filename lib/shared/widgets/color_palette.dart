import 'package:flutter/material.dart';

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

class ColorPickerRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const ColorPickerRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kPastelPalette.map((hex) {
        final isSelected = hex == selected;
        return GestureDetector(
          onTap: () => onSelected(hex),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hexToColor(hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black87 : Colors.black12,
                width: isSelected ? 2.5 : 1,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.black87)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
