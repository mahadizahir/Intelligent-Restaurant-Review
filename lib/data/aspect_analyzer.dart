import 'package:flutter/material.dart';
import 'app_state.dart';

// ── Aspect keyword lists ──────────────────────────────────────────────────
// Neutral words that indicate WHICH aspect the review is about.
const _FOOD_KEYWORDS = {
  'food', 'meal', 'dish', 'cuisine', 'flavour', 'flavor',
  'ingredient', 'portion', 'menu', 'cooking', 'recipe',
  'makanan', 'masakan', 'hidangan', 'lauk', 'nasi', 'mee', 'mi',
  'kuih', 'sambal', 'sup', 'sop', 'gulai', 'kari', 'ikan',
  'ayam', 'daging', 'sayur', 'telur', 'roti', 'bubur',
};

const _SERVICE_KEYWORDS = {
  'service', 'staff', 'waiter', 'waitress', 'server', 'attendant',
  'host', 'bartender', 'chef', 'serve', 'serving',
  'servis', 'pelayan', 'pekerja', 'staf', 'khidmat',
  'layanan', 'sambutan', 'menunggu', 'tunggu',
};

const _PRICE_KEYWORDS = {
  'price', 'cost', 'bill', 'charge', 'fee', 'payment',
  'harga', 'kos', 'bayaran', 'bil', 'nilai',
};

const _CLEANLINESS_KEYWORDS = {
  'toilet', 'washroom', 'bathroom', 'restroom',
  'table', 'chair', 'floor', 'kitchen', 'utensil',
  'kebersihan', 'tandas', 'lantai', 'meja', 'kerusi',
  'pinggan', 'cawan', 'gelas', 'sudu', 'garfu',
  'premis', 'kedai', 'restoran', 'cafe',
  'kotor', 'bersih', 'berbau', 'busuk', 'sampah', 'habuk',
  // Place words — only when paired with cleanliness sentiment
  'place', 'tempat', 'dining',
};

// ── Positive sentiment keywords ────────────────────────────────────────────
const _POSITIVE_WORDS = {
  'good', 'great', 'excellent', 'amazing', 'awesome', 'fantastic',
  'wonderful', 'delicious', 'tasty', 'fresh', 'perfect', 'best',
  'nice', 'pleasant', 'love', 'loved', 'satisfied', 'friendly',
  'helpful', 'polite', 'fast', 'quick', 'efficient', 'clean',
  'spotless', 'tidy', 'neat', 'hygienic', 'comfortable',
  'reasonable', 'affordable', 'cheap', 'value',
  'sedap', 'enak', 'nikmat', 'mantap', 'puas', 'hebat',
  'ramah', 'mesra', 'peramah', 'baik', 'cekap', 'pantas', 'cepat',
  'bersih', 'rapi', 'kemas', 'nyaman', 'selesa', 'murah', 'berbaloi',
};

// ── Negative sentiment keywords ────────────────────────────────────────────
const _NEGATIVE_WORDS = {
  'bad', 'terrible', 'awful', 'horrible', 'disgusting', 'worst',
  'poor', 'disappointed', 'disappointing', 'bland', 'stale', 'cold',
  'slow', 'rude', 'dirty', 'messy', 'smelly', 'expensive',
  'overpriced', 'tough', 'dry', 'burnt', 'raw',
  'teruk', 'kecewa', 'lambat', 'kasar',
  'busuk', 'basi', 'kotor', 'berbau', 'mahal',
  'tawar', 'hambar', 'liat', 'keras',
};

List<String> _tokenize(String text) {
  final lowered = text.toLowerCase();
  final regex = RegExp(r"[a-zA-Z']+");
  return regex.allMatches(lowered).map((m) => m.group(0)!).toList();
}

/// Detect which aspects are mentioned in a review text.
Set<String> _detectAspects(String text) {
  final tokens = _tokenize(text);
  final aspects = <String>{};
  for (final token in tokens) {
    if (_FOOD_KEYWORDS.contains(token)) aspects.add('food');
    if (_SERVICE_KEYWORDS.contains(token)) aspects.add('service');
    if (_PRICE_KEYWORDS.contains(token)) aspects.add('price');
    if (_CLEANLINESS_KEYWORDS.contains(token)) aspects.add('cleanliness');
  }
  return aspects;
}

/// Score sentiment for a review on a 0.0–5.0 scale.
/// Counts positive vs negative keywords and maps to a score.
/// Returns null if no sentiment words found (no opinion expressed).
double? _scoreReview(String text) {
  final tokens = _tokenize(text);
  int posCount = 0;
  int negCount = 0;
  for (final token in tokens) {
    if (_POSITIVE_WORDS.contains(token)) posCount++;
    if (_NEGATIVE_WORDS.contains(token)) negCount++;
  }
  if (posCount == 0 && negCount == 0) return null; // no data
  
  final net = posCount - negCount;
  if (net > 0) {
    // Positive: scale from 3.0 to 5.0 based on strength
    return (3.0 + (net.clamp(1, 5) / 5.0) * 2.0).clamp(3.0, 5.0);
  } else if (net < 0) {
    // Negative: scale from 0.0 to 2.0 based on strength
    final absNet = (-net).clamp(1, 5);
    return (2.0 - (absNet / 5.0) * 2.0).clamp(0.0, 2.0);
  } else {
    // Neutral (equal pos and neg): return exactly 2.5
    return 2.5;
  }
}

/// Result for a single aspect across all reviews.
class AspectResult {
  final String label;
  final double avgScore; // 0.0 to 5.0 scale
  final bool hasData;    // false = N/A
  final int count;

  AspectResult({
    required this.label,
    required this.avgScore,
    required this.hasData,
    required this.count,
  });
}

/// Analyze all reviews and return aggregated results per aspect.
///
/// Rules:
/// - Only score aspects that are explicitly mentioned in each review.
/// - Each aspect is scored independently using sentiment keywords only.
/// - Overall star rating is NEVER used for aspect scoring.
/// - If no reviews mention an aspect, hasData = false.
/// - If a review mentions an aspect but has no sentiment words, it's skipped.
List<AspectResult> analyzeCategoryScores(List<Review> reviews) {
  // Track scores per aspect — ONLY when that aspect is mentioned
  final Map<String, List<double>> aspectScores = {};

  for (final review in reviews) {
    final mentioned = _detectAspects(review.text);
    if (mentioned.isEmpty) continue;

    for (final aspect in mentioned) {
      // Score this aspect independently using ONLY the review text
      final score = _scoreReview(review.text);
      if (score == null) continue; // no sentiment data for this review

      if (!aspectScores.containsKey(aspect)) {
        aspectScores[aspect] = [];
      }
      aspectScores[aspect]!.add(score);
    }
  }

  final labels = {
    'food': 'Food',
    'service': 'Service',
    'price': 'Price',
    'cleanliness': 'Cleanliness',
  };

  final results = <AspectResult>[];
  for (final entry in labels.entries) {
    final key = entry.key;
    final label = entry.value;
    final scores = aspectScores[key];

    if (scores == null || scores.isEmpty) {
      results.add(AspectResult(
        label: label,
        avgScore: 0.0,
        hasData: false,
        count: 0,
      ));
    } else {
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      results.add(AspectResult(
        label: label,
        avgScore: avg.clamp(0.0, 5.0),
        hasData: true,
        count: scores.length,
      ));
    }
  }

  return results;
}

/// Filter reviews that mention a specific aspect.
List<Review> filterReviewsByAspect(List<Review> reviews, String aspectKey) {
  return reviews.where((r) {
    final aspects = _detectAspects(r.text);
    return aspects.contains(aspectKey);
  }).toList();
}

/// Build a RichText widget with keyword highlighting for a review.
///
/// Uses rounded chip-style highlights for keywords.
///
/// Highlight rules:
/// - Aspect keywords: pastel yellow chip, black text
/// - Positive sentiment keywords: pastel green chip, dark green text
/// - Negative sentiment keywords: pastel red chip, dark red text
///
/// If [aspectKey] is provided, only that aspect's keywords are highlighted
/// as aspect keywords (the rest still get sentiment highlighting).
Widget buildHighlightedReviewText(String text, {String? aspectKey}) {
  final tokens = _tokenize(text);
  if (tokens.isEmpty) return Text(text);

  final wordRegex = RegExp(r"[a-zA-Z']+");
  final matches = wordRegex.allMatches(text).toList();

  // Build a list of inline widgets: plain text spans and chip containers
  final children = <InlineSpan>[];
  int lastEnd = 0;

  for (final match in matches) {
    // Add any non-word text before this word (spaces, punctuation)
    if (match.start > lastEnd) {
      children.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }

    final word = text.substring(match.start, match.end);
    final wordLower = word.toLowerCase();

    // Determine highlight colors
    Color? chipBg;
    Color? chipTextColor;

    // Aspect keyword check
    if (aspectKey != null) {
      final keywordSet = _getAspectKeywords(aspectKey);
      if (keywordSet.contains(wordLower)) {
        chipBg = const Color(0xFFFFF8C4);
        chipTextColor = Colors.black;
      }
    } else {
      for (final key in ['food', 'service', 'price', 'cleanliness']) {
        if (_getAspectKeywords(key).contains(wordLower)) {
          chipBg = const Color(0xFFFFF8C4);
          chipTextColor = Colors.black;
          break;
        }
      }
    }

    // Sentiment keyword check (only if not already highlighted as aspect)
    if (chipBg == null) {
      if (_POSITIVE_WORDS.contains(wordLower)) {
        chipBg = const Color(0xFFDFF5E1);
        chipTextColor = const Color(0xFF2E7D32);
      } else if (_NEGATIVE_WORDS.contains(wordLower)) {
        chipBg = const Color(0xFFFDE2E2);
        chipTextColor = const Color(0xFFC62828);
      }
    }

    if (chipBg != null) {
      // Rounded chip-style highlight using WidgetSpan
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            word,
            style: TextStyle(
              color: chipTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ));
    } else {
      children.add(TextSpan(text: word));
    }

    lastEnd = match.end;
  }

  // Add any remaining text after last match
  if (lastEnd < text.length) {
    children.add(TextSpan(text: text.substring(lastEnd)));
  }

  return RichText(
    text: TextSpan(
      style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
      children: children,
    ),
  );
}

/// Get the aspect keyword set for a given aspect key.
Set<String> _getAspectKeywords(String aspectKey) {
  switch (aspectKey) {
    case 'food':
      return _FOOD_KEYWORDS;
    case 'service':
      return _SERVICE_KEYWORDS;
    case 'price':
      return _PRICE_KEYWORDS;
    case 'cleanliness':
      return _CLEANLINESS_KEYWORDS;
    default:
      return {};
  }
}
