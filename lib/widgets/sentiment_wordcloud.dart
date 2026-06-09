import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Professional scattered sentiment word-cloud widget for the owner dashboard.
///
/// Expects already-grouped words with weights (e.g. from ML counts).
/// - positiveWords: list of (word, weight)
/// - negativeWords: list of (word, weight)
class SentimentWordCloud extends StatelessWidget {
  final List<WeightedWord> positiveWords;
  final List<WeightedWord> negativeWords;

  const SentimentWordCloud({
    super.key,
    required this.positiveWords,
    required this.negativeWords,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGrey, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AI-classified sentiment keywords',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Larger words reflect higher mention frequency in AI-classified reviews.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _WordCloudColumn(
                  title: 'Positive reviews',
                  subtitle: 'Green tones for strong customer praise',
                  color: const Color(0xFF1FAF63),
                  words: positiveWords,
                  emptyLabel: 'Awaiting positive feedback',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WordCloudColumn(
                  title: 'Negative reviews',
                  subtitle: 'Red tones for customer concerns',
                  color: const Color(0xFFE24D4D),
                  words: negativeWords,
                  emptyLabel: 'Awaiting concerns review',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WeightedWord {
  final String word;
  final double weight; // relative 0..1-ish is fine

  const WeightedWord({
    required this.word,
    required this.weight,
  });
}

class _WordCloudColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<WeightedWord> words;
  final String emptyLabel;

  const _WordCloudColumn({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.words,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final displayWords = words;

    // If no keywords, show an empty area (no placeholders inside the cloud).
    final maxW = displayWords.isEmpty
        ? 1.0
        : displayWords.map((e) => e.weight).reduce((a, b) => a > b ? a : b);



    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Height is fixed so we can place words within bounds.
          SizedBox(
            height: 190,
            child: _ScatteredWordCloud(
              words: displayWords,
              color: color,
              maxWeight: maxW,
              // Seed per-sentiment so columns are stable.
              seed: color.value,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScatteredWordCloud extends StatelessWidget {
  final List<WeightedWord> words;
  final Color color;
  final double maxWeight;
  final int seed;

  const _ScatteredWordCloud({
    required this.words,
    required this.color,
    required this.maxWeight,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cloudWidth = constraints.maxWidth;
        final cloudHeight = constraints.maxHeight;

        final placements = _computePlacements(
          width: cloudWidth,
          height: cloudHeight,
          words: words,
          maxWeight: maxWeight,
          seed: seed,
          textColor: color,
          // Keep sizing similar to prior implementation.
          minFont: 13,
          maxFont: 28,
          minFontWeight: FontWeight.w700,
          maxFontWeight: FontWeight.w800,
        );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: placements
              .map(
                (p) => Positioned(
                  left: p.dx,
                  top: p.dy,
                  child: Text(
                    p.text,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: p.fontSize,
                      fontWeight: p.fontWeight,
                      color: color,
                      height: 1.05,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _WordPlacement {
  final String text;
  final double dx;
  final double dy;
  final double fontSize;
  final FontWeight fontWeight;
  final Rect bounds;

  _WordPlacement({
    required this.text,
    required this.dx,
    required this.dy,
    required this.fontSize,
    required this.fontWeight,
    required this.bounds,
  });
}

List<_WordPlacement> _computePlacements({
  required double width,
  required double height,
  required List<WeightedWord> words,
  required double maxWeight,
  required int seed,
  required Color textColor,
  required double minFont,
  required double maxFont,
  required FontWeight minFontWeight,
  required FontWeight maxFontWeight,
}) {
  // Sort descending weight so the bigger terms get placed first.
  final sorted = words.toList()
    ..sort((a, b) => b.weight.compareTo(a.weight));

  final rand = math.Random(seed);

  // Gentle padding to avoid clipping at edges.
  final padding = 6.0;
  final usableWidth = (width - padding * 2).clamp(1, double.infinity);
  final usableHeight = (height - padding * 2).clamp(1, double.infinity);
  final center = Offset(padding + usableWidth / 2, padding + usableHeight / 2);

  final placed = <_WordPlacement>[];

  // Collision check list.
  final placedRects = <Rect>[];

  // Attempt placement for each word.
  // For a small list (<=12), this is fast.
  for (int i = 0; i < sorted.length; i++) {
    final w = sorted[i];
    final t = maxWeight > 0 ? (w.weight / maxWeight).clamp(0.0, 1.0) : 0.0;
    final fontSize = minFont + t * (maxFont - minFont);
    final fontWeight = t > 0.65 ? maxFontWeight : minFontWeight;

    // Measure via TextPainter.
    final textPainter = TextPainter(
      text: TextSpan(
        text: w.word,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          height: 1.05,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final textW = textPainter.width;
    final textH = textPainter.height;

    if (textW <= 0 || textH <= 0) continue;

    // Random spiral-ish placement.
    // Scale radius so larger text still fits.
    final baseRadius = math.min(usableWidth, usableHeight) * 0.08 + t * 6;
    final maxRadius = math.min(usableWidth, usableHeight) * 0.48;

    Rect? bestRect;
    Offset? bestOffset;

    final attempts = 260;
    for (int a = 0; a < attempts; a++) {
      final angle = (rand.nextDouble() * 2 * math.pi) + (i * 0.18);
      final radius = (baseRadius + (a / attempts) * maxRadius) * (0.65 + rand.nextDouble() * 0.7);

      final dx = center.dx + radius * math.cos(angle);
      final dy = center.dy + radius * math.sin(angle);

      final left = dx - textW / 2;
      final top = dy - textH / 2;

      // Bounds inside usable area.
      if (left < padding || top < padding) continue;
      if (left + textW > padding + usableWidth) continue;
      if (top + textH > padding + usableHeight) continue;

      final rect = Rect.fromLTWH(left, top, textW, textH);

      // Expand bounds slightly to reduce touching.
      final inflated = rect.inflate(1.2);

      final overlaps = placedRects.any((r) => r.overlaps(inflated));
      if (overlaps) continue;

      bestRect = rect;
      bestOffset = Offset(left, top);
      break;
    }

    // If we couldn’t find non-overlapping position, fall back by allowing overlap
    // but still keep it in bounds.
    if (bestRect == null || bestOffset == null) {
      final left = (padding + rand.nextDouble() * (usableWidth - textW)).clamp(padding, width - textW - padding);
      final top = (padding + rand.nextDouble() * (usableHeight - textH)).clamp(padding, height - textH - padding);
      bestRect = Rect.fromLTWH(left, top, textW, textH);
      bestOffset = Offset(left, top);
    }

    placedRects.add(bestRect);
    placed.add(
      _WordPlacement(
        text: w.word,
        dx: bestOffset.dx,
        dy: bestOffset.dy,
        fontSize: fontSize,
        fontWeight: fontWeight,
        bounds: bestRect,
      ),
    );
  }

  return placed;
}

