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
// Cleanliness / place / environment keywords
  'bersih',
  'kotor',
  'dirty',
  'clean',
  'unclean',
  'filthy',
  'messy',
  'smelly',
  'stinky',
  'hygiene',
  'hygienic',

  // Place / restaurant environment
  'tempat',
  'place',
  'restaurant',
  'restoran',
  'kedai',
  'cafe',
  'area',
  'environment',
  'surrounding',
  'surroundings',
  'ambience',
  'ambiance',
  'premis',
  'persekitaran',
  'suasana',

  // Restaurant objects / hygiene areas
  'tandas',
  'toilet',
  'washroom',
  'bathroom',
  'busuk',
  'berbau',
  'sampah',
  'meja',
  'table',
  'lantai',
  'floor',
  'pinggan',
  'plate',
  'cawan',
  'cup',
  'gelas',
  'glass',
  'lipas',
  'cockroach',
  'tikus',
  'rat',
  'lalat',
  'fly',
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

  // Negation handling: if a negation word appears immediately before a
  // positive keyword, treat it as negative sentiment.
  const negations = {'tak', 'tidak', 'bukan', 'kurang'};

  for (int i = 0; i < tokens.length; i++) {
    final token = tokens[i];

    // Explicit negative keywords always count as negative.
    if (_NEGATIVE_WORDS.contains(token)) {
      negCount++;
      continue;
    }

    // Positive keywords are overridden by negation when negation comes
    // immediately before the positive keyword.
    if (_POSITIVE_WORDS.contains(token)) {
      final prev = i > 0 ? tokens[i - 1] : '';
      if (negations.contains(prev)) {
        negCount++;
      } else {
        posCount++;
      }
      continue;
    }
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
/// Requirements:
/// - Must use the exact same aspect detection as the bottom sheet.
///   => Use filterReviewsByAspect(reviews, aspectKey).
/// - N/A only when there are zero reviews mentioning the aspect.
/// - Score calculation uses sentiment keywords:
///   positive = 5
///   neutral  = 3
///   negative = 1
List<AspectResult> analyzeCategoryScores(List<Review> reviews) {
  final labels = const {
    'food': 'Food',
    'service': 'Service',
    'price': 'Price',
    'cleanliness': 'Cleanliness',
  };

  double _mapToRequiredScale(double score5Scale) {
    // _scoreReview() outputs approximately:
    // - negative: 0.0..2.0
    // - neutral: 2.5
    // - positive: 3.0..5.0
    if (score5Scale >= 3.0 && score5Scale <= 5.0) return 5.0;
    if (score5Scale == 2.5) return 3.0;
    if (score5Scale < 2.5) return 1.0;
    return 3.0;
  }

  final results = <AspectResult>[];

  for (final entry in labels.entries) {
    final aspectKey = entry.key;
    final label = entry.value;

    // Must share the same detection logic as bottom sheet.
    final relatedReviews = filterReviewsByAspect(reviews, aspectKey);

    if (relatedReviews.isEmpty) {
      results.add(
        AspectResult(
          label: label,
          avgScore: 0.0,
          hasData: false,
          count: 0,
        ),
      );
      continue;
    }

    final aspectScores = <double>[];
    for (final r in relatedReviews) {
      final raw = _scoreReview(r.text);
      if (raw == null) continue; // no sentiment data; skip
      aspectScores.add(_mapToRequiredScale(raw));
    }

    // If we detected aspect mentions but none had sentiment keywords,
    // treat as no data.
    if (aspectScores.isEmpty) {
      results.add(
        AspectResult(
          label: label,
          avgScore: 0.0,
          hasData: false,
          count: 0,
        ),
      );
      continue;
    }

    final avg = aspectScores.reduce((a, b) => a + b) / aspectScores.length;

    results.add(
      AspectResult(
        label: label,
        avgScore: avg.clamp(0.0, 5.0),
        hasData: true,
        count: aspectScores.length,
      ),
    );
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

  for (int mIndex = 0; mIndex < matches.length; mIndex++) {
    final match = matches[mIndex];

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
      // Negation handling for highlighting:
      // if a negation word appears immediately before a positive keyword,
      // highlight the positive keyword as NEGATIVE.
      const negations = {'tak', 'tidak', 'bukan', 'kurang'};

      final prevWordLower =
          (mIndex > 0 && match.start > 0) ? _tokenize(text.substring(0, match.start)).lastOrNull : null;
      final isNegatedPositive = prevWordLower != null &&
          negations.contains(prevWordLower) &&
          _POSITIVE_WORDS.contains(wordLower);


      if (_NEGATIVE_WORDS.contains(wordLower) || isNegatedPositive) {
        chipBg = const Color(0xFFFDE2E2);
        chipTextColor = const Color(0xFFC62828);
      } else if (_POSITIVE_WORDS.contains(wordLower)) {
        chipBg = const Color(0xFFDFF5E1);
        chipTextColor = const Color(0xFF2E7D32);
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
