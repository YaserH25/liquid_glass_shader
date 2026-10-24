import 'package:flutter/material.dart';

/// A scrolling page of saturated colour and text, so the glass above it
/// has something to refract.
class ColorfulBackdrop extends StatelessWidget {
  const ColorfulBackdrop({
    super.key,
    required this.header,
    required this.padding,
  });

  /// Shown at the top of the page.
  final Widget header;

  /// Around the page's content, clear of the bars floating over it.
  final EdgeInsets padding;

  static const _colors = [
    Colors.deepOrange,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
    Colors.pink,
    Colors.lightGreen,
    Colors.cyan,
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: 21,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final color = _colors[index % _colors.length];
        return Container(
          height: 120,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [color, color.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: AlignmentDirectional.bottomStart,
          child: Text(
            'Block $index',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}
