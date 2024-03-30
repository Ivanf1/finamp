import 'package:balanced_text/balanced_text.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class MarqueeFallbackText extends StatefulWidget {
  final Text text;
  const MarqueeFallbackText({super.key, required this.text});

  @override
  State<MarqueeFallbackText> createState() => _MarqueeFallbackTextState();
}

class _MarqueeFallbackTextState extends State<MarqueeFallbackText> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        /// Calculates the number of lines needed to display the text
        int getNumberOfLinesForText() {
          final textPainter = TextPainter(
            text: TextSpan(
              text: widget.text.data,
              style: widget.text.style,
            ),
            textScaler: MediaQuery.of(context).textScaler,
            textAlign: widget.text.textAlign ?? TextAlign.center,
            textDirection: widget.text.textDirection ?? TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          return textPainter.computeLineMetrics().length;
        }

        var neededLines = getNumberOfLinesForText();

        if (neededLines > (widget.text.maxLines ?? 1)) {
          return Marquee(
            text: widget.text.data!,
            blankSpace: 140,
            pauseAfterRound: const Duration(seconds: 4),
            startAfter: const Duration(seconds: 4),
            style: widget.text.style,
            textDirection: widget.text.textDirection ?? TextDirection.ltr,
          );
        } else {
          return BalancedText(
            widget.text.data!,
            textAlign: widget.text.textAlign,
            style: widget.text.style,
            overflow: widget.text.overflow,
            softWrap: widget.text.softWrap,
            maxLines: widget.text.maxLines,
          );
        }
      },
    );
  }
}
