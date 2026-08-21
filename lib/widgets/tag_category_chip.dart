import 'package:flutter/material.dart';

class TagCategoryChip extends StatelessWidget {
  final String category;
  final Color? color;
  final VoidCallback? onTap;
  final bool isSelected;

  const TagCategoryChip({
    super.key,
    required this.category,
    this.color,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: isSelected,
      label: Text(category),
      avatar: Icon(
        Icons.label,
        size: 16,
        color:
            isSelected ? Colors.white : color ?? Theme.of(context).primaryColor,
      ),
      onSelected: (value) => onTap?.call(),
      selectedColor: color ?? Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
    );
  }
}
