import 'package:flutter/material.dart';

/// Very small “word cloud” widget.
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
    if (positiveWords.isEmpty && negativeWords.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No keywords found', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _WordCloudColumn(
            title: 'Positive',
            color: Colors.green,
            words: positiveWords,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _WordCloudColumn(
            title: 'Negative',
            color: Colors.red,
            words: negativeWords,
          ),
        ),
      ],
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
  final Color color;
  final List<WeightedWord> words;

  const _WordCloudColumn({
    required this.title,
    required this.color,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = words.isEmpty
        ? 1.0
        : words.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: words
              .map((e) {
                // Map weight to font size range.
final t = (maxW <= 0) ? 0.0 : ((e.weight / maxW).clamp(0.0, 1.0) as double);
                final fontSize = 12 + t * 14; // 12..26
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    e.word,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              })
              .toList(),
        ),
      ],
    );
  }
}

