import 'package:flutter/material.dart';

class TagWidget extends StatelessWidget {
  const TagWidget({
    super.key,
    required this.tag,
    required this.color,
    this.textStyle,
    this.overflow = TextOverflow.ellipsis,
  });

  final TextStyle? textStyle;
  final String tag;
  final Color color;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 2.0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: color,
      ),
      child: Text(
        tag,
        style: textStyle,
        overflow: overflow,
      ),
    );
  }
}
