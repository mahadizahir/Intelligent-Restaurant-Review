import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../data/app_state.dart';
import '../../data/aspect_analyzer.dart';
import '../../theme/app_colors.dart';

import '../../screens/auth/register_screen.dart';
import '../../screens/profile_screen.dart';
import '../../widgets/image_helper.dart';
import '../../widgets/sentiment_wordcloud.dart';
import '../../data/app_state.dart';


const _sentimentStopWords = {
  // English common stopwords + explicit low-information terms.
  'the', 'and', 'for', 'with', 'that', 'this', 'have', 'from',
  'they', 'their', 'there', 'very', 'were', 'been', 'what', 'when', 'your',
  'you', 'but', 'not', 'are', 'was', 'had', 'has', 'our', 'out',
  'all', 'too', 'its', 'just', 'can', 'will', 'one', 'about', 'some',
  'more', 'also', 'would', 'could', 'should', 'youre', 'does', 'did',
  'because', 'after', 'before', 'while',
  // Malay common stopwords / filler terms
  'yang', 'dan', 'atau', 'di', 'ke', 'dari', 'pada', 'untuk', 'dengan',
  'ini', 'itu', 'saya', 'kami', 'anda', 'kita', 'mereka', 'dia',
  'juga', 'lagi', 'pun', 'telah', 'ada', 'tidak', 'tak', 'sekali',
  'sangat', 'terlalu',
  // Domain too-generic terms (requested)
  'tempat', 'restaurant',
};

const List<WeightedWord> _fallbackPositiveKeywords = [
  WeightedWord(word: 'sedap', weight: 1.00),
  WeightedWord(word: 'fresh', weight: 0.96),
  WeightedWord(word: 'friendly', weight: 0.92),
  WeightedWord(word: 'clean', weight: 0.90),
  WeightedWord(word: 'delicious', weight: 0.88),
  WeightedWord(word: 'excellent', weight: 0.86),
  WeightedWord(word: 'tasty', weight: 0.82),
  WeightedWord(word: 'pleasant', weight: 0.78),
  WeightedWord(word: 'spacious', weight: 0.75),
  WeightedWord(word: 'fast', weight: 0.71),
  WeightedWord(word: 'hot', weight: 0.68),
  WeightedWord(word: 'value', weight: 0.64),
];

const List<WeightedWord> _fallbackNegativeKeywords = [
  WeightedWord(word: 'slow', weight: 1.00),
  WeightedWord(word: 'dirty', weight: 0.96),
  WeightedWord(word: 'basi', weight: 0.92),
  WeightedWord(word: 'expensive', weight: 0.90),
  WeightedWord(word: 'rude', weight: 0.88),
  WeightedWord(word: 'terrible', weight: 0.86),
  WeightedWord(word: 'cold', weight: 0.82),
  WeightedWord(word: 'crowded', weight: 0.78),
  WeightedWord(word: 'smelly', weight: 0.75),
  WeightedWord(word: 'noisy', weight: 0.71),
  WeightedWord(word: 'late', weight: 0.68),
  WeightedWord(word: 'wait', weight: 0.64),
];

Widget _starGlyph(bool filled, {double size = 18, Color? color}) {
  return Text(
    filled ? '★' : '☆',
    style: TextStyle(
      fontSize: size,
      color: color ?? (filled ? const Color(0xFFFFC107) : Colors.grey.shade300),
      fontWeight: FontWeight.w700,
    ),
  );
}

List<WeightedWord> _buildWordCloud(
    List<Review> reviews, String sentiment, int limit) {
  // Keyword extraction without another ML model: tokenize + preprocess + count.
  // Requirements:
  // - remove punctuation/numbers via token filtering (keep alphabetic tokens only)
  // - remove English + Malay stopwords and low-information terms
  // - de-duplicate per review for DF-like weighting (prevents one review spamming a single keyword)
  // - generate word weights based on frequency (requested)
  final tokenRegex = RegExp(r"[a-zA-Z]+");

  final Map<String, int> freq = {};
  var totalTokens = 0;

  for (final review in reviews) {
    if (review.sentiment.trim().toLowerCase() != sentiment.trim().toLowerCase()) continue;

    final text = review.text.toLowerCase();
    final tokens = tokenRegex
        .allMatches(text)
        .map((m) => (m.group(0) ?? '').trim())
        .where((w) => w.isNotEmpty)
        .where((w) => w.length >= 3)
        .where((w) => !_sentimentStopWords.contains(w))
        .toList();

    // De-duplicate per review so repeating the same keyword in a single review
    // doesn't overweight everything.
    final uniqueTokens = tokens.toSet();
    for (final w in uniqueTokens) {
      freq[w] = (freq[w] ?? 0) + 1;
      totalTokens++;
    }
  }

  if (freq.isEmpty) {
    return sentiment.toUpperCase() == 'POSITIVE'
        ? _fallbackPositiveKeywords.take(limit).toList()
        : _fallbackNegativeKeywords.take(limit).toList();
  }

  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final top = sorted.take(limit).toList();
  final maxCount = top.isNotEmpty ? top.first.value : 1;

  return top.map((e) {
    final normalized = maxCount > 0 ? (e.value / maxCount) : 0.0;
    return WeightedWord(word: e.key, weight: normalized);
  }).toList();
}

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = [
    'Recent Reviews',
    'Menu Management',
    'Analytics'
  ];

  void _logout() {
    context.read<AppState>().logout();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  void _goToProfile() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  // ── Add / Edit menu dialog ─────────────────────────────────────────────────
  void _showMenuDialog({MenuItem? editItem}) {
    final restaurant = context.read<AppState>().ownerRestaurant;
    if (restaurant == null) return;

    final nameCtrl =
        TextEditingController(text: editItem?.name ?? '');
    final priceCtrl =
        TextEditingController(text: editItem?.price ?? '');
    final descCtrl =
        TextEditingController(text: editItem?.description ?? '');
    Uint8List? pickedBytes = editItem?.imageBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> pickImage() async {
            final bytes = await ImageHelper.showPickerSheet(context);
            if (bytes != null) setDlg(() => pickedBytes = bytes);
          }

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Title row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        editItem == null
                            ? 'ADD MENU ITEM'
                            : 'EDIT MENU ITEM',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Image picker zone ─────────────────────────────────
                  const Text('FOOD PHOTO',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 170,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.grey.withOpacity(0.35),
                            width: 1.5),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: pickedBytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(pickedBytes!,
                                    fit: BoxFit.cover),
                                // Overlay edit hint
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    color:
                                        Colors.black.withOpacity(0.45),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.edit,
                                            color: Colors.white,
                                            size: 14),
                                        SizedBox(width: 6),
                                        Text('Tap to change photo',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons
                                        .add_photo_alternate_outlined,
                                    size: 52,
                                    color: AppColors.grey
                                        .withOpacity(0.65)),
                                const SizedBox(height: 10),
                                Text('Tap to add food photo',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.grey
                                            .withOpacity(0.8))),
                                const SizedBox(height: 4),
                                Text(
                                    'Gallery • Camera (mobile)',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grey
                                            .withOpacity(0.6))),
                              ],
                            ),
                    ),
                  ),

                  // Remove photo button
                  if (pickedBytes != null)
                    TextButton.icon(
                      onPressed: () =>
                          setDlg(() => pickedBytes = null),
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('Remove photo',
                          style: TextStyle(
                              color: Colors.red, fontSize: 12)),
                    ),

                  const SizedBox(height: 12),

                  // Name
                  const Text('FOOD MENU NAME',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  _dlgField(nameCtrl,
                      'e.g. Nasi Kukus Ayam Berempah'),
                  const SizedBox(height: 12),

                  // Price
                  const Text('COST',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  _dlgField(priceCtrl, 'e.g. RM 10.50'),
                  const SizedBox(height: 12),

                  // Description
                  const Text('FOOD DETAILS',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe this menu item...',
                      hintStyle: const TextStyle(
                          color: AppColors.grey, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel',
                            style:
                                TextStyle(color: AppColors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty ||
                              priceCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text(
                                  'Name and price are required.'),
                            ));
                            return;
                          }
                          final st = context.read<AppState>();
                          if (editItem == null) {
                            st.addMenuItem(
                              restaurantId: restaurant.id,
                              name: nameCtrl.text,
                              price: priceCtrl.text,
                              description: descCtrl.text,
                              imageBytes: pickedBytes,
                            );
                          } else {
                            st.editMenuItem(
                              menuItemId: editItem.id,
                              name: nameCtrl.text,
                              price: priceCtrl.text,
                              description: descCtrl.text,
                              imageBytes: pickedBytes,
                              clearImage: pickedBytes == null,
                            );
                          }
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(editItem == null
                                  ? 'Menu item added! Customers can see it now.'
                                  : 'Menu item updated!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.black,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                            editItem == null ? 'ADD' : 'SAVE'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dlgField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.grey, fontSize: 13),
        filled: true,
        fillColor: AppColors.lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: const Text('Delete this item?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AppState>().deleteMenuItem(id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: AppColors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    final restaurant = state.ownerRestaurant;
    final reviews = restaurant != null
        ? state.reviewsFor(restaurant.id)
        : <Review>[];
    final menuItems = restaurant != null
        ? state.menuItemsFor(restaurant.id)
        : <MenuItem>[];
    final avgRating = restaurant != null
        ? state.averageRatingFor(restaurant.id)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────
          Container(
            color: AppColors.headerBlue,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              right: 12,
              bottom: 12,
            ),
            child: Row(
              children: [
                // Avatar / profile button
                GestureDetector(
                  onTap: _goToProfile,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      border: Border.all(
                          color: Colors.white70, width: 2),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: user?.avatarBytes != null
                        ? BytesImage(
                            bytes: user!.avatarBytes,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(999),
                            placeholder: const Icon(Icons.storefront,
                                color: AppColors.headerBlue, size: 24),
                          )
                        : const Icon(Icons.storefront,
                            color: AppColors.headerBlue,
                            size: 24),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('WELCOME',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      Text(
                        restaurant?.name.toUpperCase() ??
                            'MY RESTAURANT',
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Profile text button
                TextButton(
                  onPressed: _goToProfile,
                  child: const Text('Profile',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12)),
                ),
                // Logout
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('LOG OUT',
                        style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _RatingSummaryCard(reviews: reviews),
                  const SizedBox(height: 8),
                  _CategoryScoresCard(reviews: reviews),
                  const SizedBox(height: 8),
                  _AISummaryCard(reviews: reviews),
                  const SizedBox(height: 8),
                  _TabBar(
                    tabs: _tabs,
                    selected: _selectedTab,
                    onTap: (i) => setState(() => _selectedTab = i),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedTab == 0) _ReviewsTab(reviews: reviews),
                  if (_selectedTab == 1)
                    _MenuTab(
                      items: menuItems,
                      onAdd: () => _showMenuDialog(),
                      onEdit: (item) => _showMenuDialog(editItem: item),
                      onDelete: _confirmDelete,
                    ),
                  if (_selectedTab == 2)
                    _AnalyticsTab(reviews: reviews),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RatingSummaryCard extends StatelessWidget {
  final List<Review> reviews;
  const _RatingSummaryCard({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final total = reviews.length;
    final avg = total > 0
        ? reviews.map((r) => r.stars).reduce((a, b) => a + b) / total
        : 0.0;

    // Count reviews per star (1–5)
    final counts = List.generate(6, (_) => 0); // index 0 unused
    for (final r in reviews) {
      if (r.stars >= 1 && r.stars <= 5) counts[r.stars]++;
    }

    // Determine if we're on a narrow screen (mobile portrait)
    final isNarrow = MediaQuery.of(context).size.width < 480;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isNarrow
          ? Column(
              children: [
                _buildAverageColumn(avg, total),
                const SizedBox(height: 20),
                _buildDistributionBars(counts, total),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAverageColumn(avg, total),
                const SizedBox(width: 32),
                Expanded(child: _buildDistributionBars(counts, total)),
              ],
            ),
    );
  }

  Widget _buildAverageColumn(double avg, int total) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Text(
            avg > 0 ? avg.toStringAsFixed(1) : '0.0',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 40,
              color: AppColors.textDark,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  avg > 0 && i < avg.round()
                      ? Icons.star
                      : Icons.star_border,
                  color: avg > 0
                      ? const Color(0xFFFFC107)
                      : AppColors.grey,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total > 0 ? '$total rating${total == 1 ? '' : 's'}' : 'No ratings yet',
            style: TextStyle(
              fontSize: 12,
              color: total > 0 ? AppColors.textMuted : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBars(List<int> counts, int total) {
    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i;
        final count = counts[star];
        final fraction = total > 0 ? count / total : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$star',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark)),
                    const SizedBox(width: 3),
                    const Icon(Icons.star,
                        size: 13, color: Color(0xFFFFC107)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 12,
                    backgroundColor: AppColors.lightGrey,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFC107)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CategoryScoresCard extends StatelessWidget {
  final List<Review> reviews;
  const _CategoryScoresCard({required this.reviews});

  void _showAspectReviews(BuildContext context, String aspectKey, String label) {
    final allReviews = filterReviewsByAspect(reviews, aspectKey);

    // Compute stats for header
    final totalCount = allReviews.length;
    final positiveCount = allReviews.where((r) => r.sentiment.trim().toUpperCase() == 'POSITIVE').length;
    final negativeCount = allReviews.where((r) => r.sentiment.trim().toUpperCase() == 'NEGATIVE').length;
    final avgAspectRating = totalCount > 0
        ? allReviews.map((r) => r.stars).reduce((a, b) => a + b) / totalCount
        : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AspectReviewSheet(
          allReviews: allReviews,
          aspectKey: aspectKey,
          label: label,
          totalCount: totalCount,
          positiveCount: positiveCount,
          negativeCount: negativeCount,
          avgAspectRating: avgAspectRating,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = analyzeCategoryScores(reviews);

    final aspectKeys = ['food', 'service', 'price', 'cleanliness'];
    final aspectLabels = ['Food', 'Service', 'Price', 'Cleanliness'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: List.generate(4, (i) {
          final result = results[i];
          return GestureDetector(
            onTap: () =>
                _showAspectReviews(context, aspectKeys[i], aspectLabels[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7FA3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(result.label,
                            style: const TextStyle(
                                color: AppColors.white, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: result.hasData
                                    ? result.avgScore / 5.0
                                    : 0.0,
                                minHeight: 5,
                                backgroundColor:
                                    AppColors.white.withOpacity(0.3),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFFC107)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            result.hasData
                                ? result.avgScore.toStringAsFixed(1)
                                : 'N/A',
                            style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AISummaryCard extends StatefulWidget {
  final List<Review> reviews;
  const _AISummaryCard({required this.reviews});

  @override
  State<_AISummaryCard> createState() => _AISummaryCardState();
}

class _AISummaryCardState extends State<_AISummaryCard> {
  bool _isLoading = false;
  String? _groqSummary;
  String? _error;

  List<String> _topKeywords(List<Review> reviews, String sentiment, {int limit = 5}) {
    if (reviews.isEmpty) return const [];

    const tokenRegex = r"[a-zA-Z]+";
    final freq = <String, int>{};

    for (final review in reviews) {
      if (review.sentiment.trim().toLowerCase() != sentiment.trim().toLowerCase()) continue;
      final text = review.text.toLowerCase();
      final tokens = tokenRegex
          .allMatches(text)
          .map((m) => (m.group(0) ?? '').trim())
          .where((w) => w.isNotEmpty)
          .where((w) => w.length >= 3)
          .where((w) => !_sentimentStopWords.contains(w))
          .toList();

      final uniqueTokens = tokens.toSet();
      for (final w in uniqueTokens) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }

    if (freq.isEmpty) return const [];

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroqSummary();
    });
  }

  @override
  void didUpdateWidget(covariant _AISummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.reviews.length != widget.reviews.length) {
      _groqSummary = null;
      _error = null;
      _loadGroqSummary();
    }
  }

  Future<void> _loadGroqSummary() async {

    if (widget.reviews.isEmpty) {
      // Keep UX: show fallback message.
      setState(() {
        _groqSummary = 'No reviews yet. AI summary will appear once customers submit reviews.';
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Normalize sentiment casing once to avoid mismatches like 'positive' vs 'POSITIVE'.
      final normalizedSentiments = widget.reviews
          .map((r) => r.sentiment.trim().toUpperCase())
          .toList();

      final pos = normalizedSentiments.where((s) => s == 'POSITIVE').length;
      final neg = normalizedSentiments.where((s) => s == 'NEGATIVE').length;
      final total = widget.reviews.length;

      final avg =
          widget.reviews.map((r) => r.stars).reduce((a, b) => a + b) / total;

      final positiveKeywords = _topKeywords(widget.reviews, 'POSITIVE', limit: 8);
      final negativeKeywords = _topKeywords(widget.reviews, 'NEGATIVE', limit: 8);

      // Requested debug logging
      // ignore: avoid_print
      print('AI Summary Debug -> totalReviews=$total');
      // ignore: avoid_print
      print('AI Summary Debug -> positive review count=$pos');
      // ignore: avoid_print
      print('AI Summary Debug -> negative review count=$neg');
      // ignore: avoid_print
      print('AI Summary Debug -> extracted positive keywords=$positiveKeywords');
      // ignore: avoid_print
      print('AI Summary Debug -> extracted negative keywords=$negativeKeywords');

      // Debug logging: show extracted keywords before fallback/Groq call.
      // ignore: avoid_print
      print('AI Summary Debug -> positiveKeywords extracted(before fallback)=$positiveKeywords');
      // ignore: avoid_print
      print('AI Summary Debug -> negativeKeywords extracted(before fallback)=$negativeKeywords');

      // If keyword extraction yields empty, fall back to the rule-based keyword sets.
      final fallbackPositive = _fallbackPositiveKeywords.map((e) => e.word).take(8).toList();
      final fallbackNegative = _fallbackNegativeKeywords.map((e) => e.word).take(8).toList();

      // Hard guarantee: never send empty arrays.
      final positiveKeywordsToSend =
          (positiveKeywords.isEmpty ? fallbackPositive : positiveKeywords).where((x) => x.trim().isNotEmpty).toList();
      final negativeKeywordsToSend =
          (negativeKeywords.isEmpty ? fallbackNegative : negativeKeywords).where((x) => x.trim().isNotEmpty).toList();

      // Final guard for extreme cases.
      final positiveKeywordsFinal = positiveKeywordsToSend.isEmpty
          ? fallbackPositive
          : positiveKeywordsToSend;
      final negativeKeywordsFinal = negativeKeywordsToSend.isEmpty
          ? fallbackNegative
          : negativeKeywordsToSend;

      // ignore: avoid_print
      print('AI Summary Debug -> sending positiveKeywords=$positiveKeywordsFinal');
      // ignore: avoid_print
      print('AI Summary Debug -> sending negativeKeywords=$negativeKeywordsFinal');

      // NOTE: update to your Flask host if different.
      const flaskBaseUrl = 'http://127.0.0.1:5000';
      final uri = Uri.parse('$flaskBaseUrl/groq/summary');



// Requested debug: print exact values being sent to Groq via Flask.
      final reviewsForDebug = widget.reviews;
      // ignore: avoid_print
      print('REVIEWS: ${reviewsForDebug.length}');
      // ignore: avoid_print
      print(
          'SENTIMENTS: ${reviewsForDebug.map((r) => r.sentiment).toList()}');

      final posWords = _buildWordCloud(
        reviewsForDebug,
        'POSITIVE',
        5,
      );
      final negWords = _buildWordCloud(
        reviewsForDebug,
        'NEGATIVE',
        5,
      );

      // ignore: avoid_print
      print('POS WORDS: ${posWords.map((w) => w.word).toList()}');
      // ignore: avoid_print
      print('NEG WORDS: ${negWords.map((w) => w.word).toList()}');

      final posKeywordsToSend = posWords.map((w) => w.word).toList();
      final negKeywordsToSend = negWords.map((w) => w.word).toList();

      // Do not send "—". If keyword list is empty, send fallback keywords.
      List<String> _fallbackFromWeighted(List<WeightedWord> src) =>
          src.map((e) => e.word).where((x) => x.trim().isNotEmpty).toList();

      final groqFallbackPositive = _fallbackFromWeighted(
        _fallbackPositiveKeywords.take(5).toList(),
      );
      final groqFallbackNegative = _fallbackFromWeighted(
        _fallbackNegativeKeywords.take(5).toList(),
      );

      final positiveKeywordsForGroq = posKeywordsToSend.isEmpty
          ? groqFallbackPositive
          : posKeywordsToSend;
      final negativeKeywordsForGroq = negKeywordsToSend.isEmpty
          ? groqFallbackNegative
          : negKeywordsToSend;

      // Final guard: remove blanks and ensure no '—' gets sent.
      final positiveKeywordsFinalForGroq = positiveKeywordsForGroq
          .map((x) => x.toString().trim())
          .where((x) => x.isNotEmpty)
          .where((x) => x != '—')
          .toList();
      final negativeKeywordsFinalForGroq = negativeKeywordsForGroq
          .map((x) => x.toString().trim())
          .where((x) => x.isNotEmpty)
          .where((x) => x != '—')
          .toList();

      // ignore: avoid_print
      print(
          'AI Summary Debug -> sending positiveKeywords=${positiveKeywordsFinalForGroq}');
      // ignore: avoid_print
      print(
          'AI Summary Debug -> sending negativeKeywords=${negativeKeywordsFinalForGroq}');

      // Use the printed keyword lists for the payload.
      final body = {
        'totalReviews': total,
        'avgRating': avg,
        'positiveCount': pos,
        'negativeCount': neg,
        'positiveKeywords': positiveKeywordsFinalForGroq,
        'negativeKeywords': negativeKeywordsFinalForGroq,
      };


      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Groq summary request failed: ${resp.statusCode} ${resp.body}');
      }

      final decoded = jsonDecode(resp.body);
      final summary = decoded['summary'];
      if (summary is String && summary.trim().isNotEmpty) {
        setState(() {
          _groqSummary = summary.trim();
          _isLoading = false;
          _error = null;
        });
      } else {
        throw Exception('Invalid Groq response format');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _groqSummary = null;
        _isLoading = false;
      });
    }
  }

  String _summaryRuleBased(List<Review> reviews) {

    if (reviews.isEmpty) {
      return 'No reviews available yet. Customer insights will appear once reviews are submitted.';
    }


    final pos =
        reviews.where((r) => r.sentiment.trim().toLowerCase() == 'positive').length;
    final neg =
        reviews.where((r) => r.sentiment.trim().toLowerCase() == 'negative').length;

    final avg =
        reviews.map((r) => r.stars).reduce((a, b) => a + b) / reviews.length;

    final total = reviews.length;
    final trend = () {
      if (pos > neg) return 'mostly positive';
      if (neg > pos) return 'mostly negative';
      return 'mixed';
    }();

    // Reuse existing rule-based tokenization + stopwords (no additional ML).
    const tokenRegex = r"[a-zA-Z]+";

    List<WeightedWord> topPositive = [];
    List<WeightedWord> topNegative = [];

    Map<String, int> _buildFreq(String sentiment) {
      final freq = <String, int>{};
      for (final review in reviews) {
        if (review.sentiment.trim().toUpperCase() != sentiment) continue;

        final text = review.text.toLowerCase();
        final tokens = tokenRegex
            .allMatches(text)
            .map((m) => (m.group(0) ?? '').trim())
            .where((w) => w.isNotEmpty)
            .where((w) => w.length >= 3)
            .where((w) => !_sentimentStopWords.contains(w))
            .toList();

        final uniqueTokens = tokens.toSet();
        for (final w in uniqueTokens) {
          freq[w] = (freq[w] ?? 0) + 1;
        }
      }
      return freq;
    }

    Map<String, int> _freqToTop(Map<String, int> freq, int limit) {
      if (freq.isEmpty) return {};
      final sorted = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.take(limit).toList();
      final maxCount = top.isNotEmpty ? top.first.value : 1;
      final out = <String, int>{};
      for (final e in top) {
        // Weight isn't used for text summary; keep simple counts.
        out[e.key] = maxCount > 0 ? (e.value / maxCount * 1000).toInt() : 0;
      }
      return out;
    }

    final posFreq = _buildFreq('POSITIVE');
    final negFreq = _buildFreq('NEGATIVE');

    final posTopMap = _freqToTop(posFreq, 5);
    final negTopMap = _freqToTop(negFreq, 5);

    topPositive = posTopMap.entries
        .map((e) => WeightedWord(word: e.key, weight: e.value.toDouble()))
        .toList();
    topNegative = negTopMap.entries
        .map((e) => WeightedWord(word: e.key, weight: e.value.toDouble()))
        .toList();

    String _fmtKeywords(List<WeightedWord> words) {
      if (words.isEmpty) return '—';
      final list = words.take(3).map((w) => "'${w.word}'").toList();
      return list.join(', ');
    }

    final mostPos = _fmtKeywords(topPositive);
    final mostNeg = _fmtKeywords(topNegative);

    // Actionable recommendations driven by keyword patterns.
    // (Still rule-based; multilingual friendly keywords included.)
    final negativeRecs = <String>[];
    void addRec(String rec) {
      if (!negativeRecs.contains(rec)) negativeRecs.add(rec);
    }

    bool containsAny(List<WeightedWord> words, List<String> keys) {
      final set = words.map((w) => w.word.toLowerCase()).toSet();
      return keys.any(set.contains);
    }

    final negWords = topNegative;

    if (containsAny(negWords, ['dirty', 'clean', 'smelly', 'basi', 'cold', 'crowded'])) {
      // cleanliness-related hints
      if (containsAny(negWords, ['dirty', 'smelly'])) {
        addRec('Focus on cleanliness and odor control (e.g., sanitize tables/toilets more consistently).');
      }
      if (containsAny(negWords, ['clean'])) {
        // if 'clean' appears as negative keyword, it can indicate mismatch (e.g., “not clean”)—still a cleanliness cue.
        addRec('Double-check cleanliness checkpoints (tables, utensils, and washroom).');
      }
      if (containsAny(negWords, ['cold'])) {
        addRec('Improve temperature consistency so food arrives hot/fresh.');
      }
      if (containsAny(negWords, ['basi'])) {
        addRec('Improve freshness and prep timing to avoid “stale/old” taste.');
      }
    }

    if (containsAny(negWords, ['slow'])) {
      addRec('Reduce waiting time by optimizing kitchen workflow and queue management.');
    }

    if (containsAny(negWords, ['wait', 'late'])) {
      addRec('Set clearer service expectations and work on faster order turnaround.');
    }

    if (containsAny(negWords, ['rude'])) {
      addRec('Re-train staff on friendly service and faster, more polite responses.');
    }

    if (containsAny(negWords, ['expensive'])) {
      addRec('Review pricing/value: consider bundle deals, promotions, or portion/value alignment.');
    }

    if (containsAny(negWords, ['noisy', 'crowded'])) {
      addRec('Manage crowding/noise (spacing, seating flow, and staff coverage) for a calmer dining experience.');
    }

    if (negativeRecs.isEmpty) {
      // Generic but still actionable.
      addRec('Keep improving service and food consistency—use the feedback themes from your next reviews to target specific fixes.');
    }

    // Positive recommendations (what to keep doing)
    final posRecs = <String>[];
    final posWords = topPositive;
    void addPosRec(String rec) {
      if (!posRecs.contains(rec)) posRecs.add(rec);
    }

    if (containsAny(posWords, ['sedap', 'delicious', 'tasty', 'fresh', 'hot', 'pleasant'])) {
      addPosRec('Keep doing what customers love about food quality—maintain freshness and taste consistency.');
    }
    if (containsAny(posWords, ['friendly', 'fast', 'excellent'])) {
      addPosRec('Strengthen the strengths in service speed and friendliness with consistent staff practices.');
    }

    String _joinRecs(List<String> recs) {
      if (recs.isEmpty) return '';
      final shown = recs.take(2).toList();
      return shown.join(' ');
    }

    String recommendations = '';
    if (trend == 'mostly positive') {
      recommendations = 'Keep the momentum. ' +
          (posRecs.isEmpty
              ? 'Monitor what’s working and maintain quality standards across food and service.'
              : _joinRecs(posRecs));

      // Add one gentle improvement from negative side if available.
      if (topNegative.isNotEmpty) {
        recommendations += ' At the same time, address the biggest concerns (e.g., ' +
            mostNeg.replaceAll("'", '') + ' ) to make the experience even smoother.';
      }
    } else if (trend == 'mostly negative') {
      recommendations = 'Prioritize fixes that match the feedback. ' + _joinRecs(negativeRecs);
      if (topPositive.isNotEmpty) {
        recommendations += ' Also, protect your strengths (e.g., ' +
            mostPos.replaceAll("'", '') + ') so improvement doesn’t reduce quality.';
      }
    } else {
      recommendations = 'You have a mix of praise and concerns. ' +
          'Focus on resolving the top negative themes first (e.g., ' +
          mostNeg.replaceAll("'", '') + ') while continuing what customers like most (e.g., ' +
          mostPos.replaceAll("'", '') + ').';
    }

    // Final owner-friendly business insight summary.
    final trendLabel = () {
      if (trend == 'mostly positive') return 'Overall sentiment is positive';
      if (trend == 'mostly negative') return 'Overall sentiment is negative';
      return 'Overall sentiment is mixed';
    }();

    return '$trendLabel with an average rating of ${avg.toStringAsFixed(1)}★ from $total reviews. ' +
        'Most common positive keywords: $mostPos. ' +
        'Most common negative keywords: $mostNeg. ' +
        recommendations;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Summary',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          const Text('Based on recent reviews',
              style:
                  TextStyle(color: AppColors.grey, fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            _isLoading
                ? 'Generating summary…'
                : (_groqSummary != null
                    ? _groqSummary!
                    : 'GROQ FAILED: $_error'),
            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          ),


        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTap;
  const _TabBar(
      {required this.tabs,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4)
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(tabs[i],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: AppColors.textDark)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  final List<Review> reviews;
  const _ReviewsTab({required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No reviews yet.\nThe summaries will appear after user make a review.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          ),
        ),
      );
    }
    return Column(
      children: reviews.reversed.map((r) {
        final isPos = r.sentiment.trim().toUpperCase() == 'POSITIVE';
        final isNeg = r.sentiment.trim().toUpperCase() == 'NEGATIVE';
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.lightGrey)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: _starGlyph(
                            i < r.stars,
                            size: 17,
                            color: const Color(0xFFFFC107),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(r.text,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('— ${r.customerName}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                alignment: Alignment.topRight,
                decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(r.sentiment,
                    style: TextStyle(
                        color: isPos
                            ? AppColors.white
                            : isNeg
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MenuTab extends StatelessWidget {
  final List<MenuItem> items;
  final VoidCallback onAdd;
  final ValueChanged<MenuItem> onEdit;
  final ValueChanged<String> onDelete;

  const _MenuTab({
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Menu Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No menu items yet.\nTap "Add Menu Item" to get started.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.grey, fontSize: 14),
              ),
            ),
          )
        else
          ...items.map((item) => Container(
                margin:
                    const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food image (bytes)
                    BytesImage(
                      bytes: item.imageBytes,
                      width: 70,
                      height: 70,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(item.name,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 13))),
                            GestureDetector(
                                onTap: () => onEdit(item),
                                child: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: AppColors.textDark)),
                            const SizedBox(width: 8),
                            GestureDetector(
                                onTap: () => onDelete(item.id),
                                child: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Colors.red)),
                          ]),
                          const SizedBox(height: 4),
                          Text(item.price,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          if (item.rating > 0)
                            Row(children: [
                              _starGlyph(true, size: 14, color: const Color(0xFFFFC107)),
                              const SizedBox(width: 3),
                              Text(item.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 12)),
                            ]),
                          const SizedBox(height: 4),
                          Text(item.description,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final List<Review> reviews;
  const _AnalyticsTab({required this.reviews});

  @override
  Widget build(BuildContext context) {
    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in reviews) {
      counts[r.stars] = (counts[r.stars] ?? 0) + 1;
    }
    final maxCount =
        counts.values.reduce((a, b) => a > b ? a : b).toDouble();

    // Calculate sentiment distribution
    final positiveCount =
      reviews.where((r) => r.sentiment.trim().toUpperCase() == 'POSITIVE').length;
    final negativeCount =
      reviews.where((r) => r.sentiment.trim().toUpperCase() == 'NEGATIVE').length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rating Distribution',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data yet.',
                  style: TextStyle(color: AppColors.grey)),
            ))
          else
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [5, 4, 3, 2, 1].map((star) {
                  final count = counts[star] ?? 0;
                  final frac =
                      maxCount > 0 ? count / maxCount : 0.0;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$count',
                            style: const TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: frac == 0 ? 0.02 : frac,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(
                                      horizontal: 4),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFC107),
                                  borderRadius:
                                      BorderRadius.circular(4)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('$star★',
                            style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          // Sentiment Distribution Section
          const Text('Sentiment Distribution',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          if (reviews.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data yet.',
                  style: TextStyle(color: AppColors.grey)),
            ))
          else
            Column(
              children: [
                SizedBox(
                  height: 300,
                  child: Center(
                    child: SizedBox(
                      width: 220,
                      height: 220,
                      child: CustomPaint(
                        painter: _SentimentPiePainter(
                          positiveCount: positiveCount,
                          negativeCount: negativeCount,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 15, height: 15, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Positive',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 15, height: 15, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Negative',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Text('Sentiment Word Cloud',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'AI-classified review keywords with larger terms reflecting more frequent mentions.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SentimentWordCloud(
            positiveWords:
                reviews.isEmpty ? const [] : _buildWordCloud(reviews, 'POSITIVE', 12),
            negativeWords:
                reviews.isEmpty ? const [] : _buildWordCloud(reviews, 'NEGATIVE', 12),
          ),
          const SizedBox(height: 16),
          const Text('AI Recommendations',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'AI-generated actionable insights based on customer review sentiment.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          _AISuggestionsCard(reviews: reviews),
        ],
      ),
    );
  }
}

class _AISuggestionsCard extends StatefulWidget {
  final List<Review> reviews;
  const _AISuggestionsCard({required this.reviews});

  @override
  State<_AISuggestionsCard> createState() => _AISuggestionsCardState();
}

class _AISuggestionsCardState extends State<_AISuggestionsCard> {
  bool _isLoading = false;
  Map<String, List<String>>? _suggestions;
  String? _error;

  List<String> _topKeywords(List<Review> reviews, String sentiment, {int limit = 8}) {
    if (reviews.isEmpty) return const [];
    final tokenRegex = RegExp(r"[a-zA-Z]+");
    final freq = <String, int>{};
    for (final review in reviews) {
      if (review.sentiment.trim().toUpperCase() != sentiment.trim().toUpperCase()) continue;
      final text = review.text.toLowerCase();
      final tokens = tokenRegex
          .allMatches(text)
          .map((m) => (m.group(0) ?? '').trim())
          .where((w) => w.isNotEmpty)
          .where((w) => w.length >= 3)
          .where((w) => !_sentimentStopWords.contains(w))
          .toList();
      final uniqueTokens = tokens.toSet();
      for (final w in uniqueTokens) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    if (freq.isEmpty) return const [];
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
    });
  }

  @override
  void didUpdateWidget(covariant _AISuggestionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reviews.length != widget.reviews.length) {
      _suggestions = null;
      _error = null;
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    if (widget.reviews.isEmpty) {
      setState(() {
        _suggestions = null;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pos = widget.reviews.where((r) => r.sentiment.trim().toUpperCase() == 'POSITIVE').length;
      final neg = widget.reviews.where((r) => r.sentiment.trim().toUpperCase() == 'NEGATIVE').length;
      final total = widget.reviews.length;
      final avg = widget.reviews.map((r) => r.stars).reduce((a, b) => a + b) / total;

      final posKeywords = _topKeywords(widget.reviews, 'POSITIVE', limit: 8);
      final negKeywords = _topKeywords(widget.reviews, 'NEGATIVE', limit: 8);

      final body = {
        'totalReviews': total,
        'avgRating': avg,
        'positiveCount': pos,
        'negativeCount': neg,
        'positiveKeywords': posKeywords,
        'negativeKeywords': negKeywords,
      };

      const flaskBaseUrl = 'http://127.0.0.1:5000';
      final uri = Uri.parse('$flaskBaseUrl/groq/suggestions');

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Groq suggestions request failed: ${resp.statusCode}');
      }

      final decoded = jsonDecode(resp.body);
      final suggestions = decoded['suggestions'];
      if (suggestions is Map) {
        final parsed = <String, List<String>>{};
        for (final key in ['Strengths', 'Areas to Improve', 'Recommended Actions']) {
          if (suggestions[key] is List) {
            parsed[key] = (suggestions[key] as List).map((e) => e.toString()).toList();
          } else {
            parsed[key] = [];
          }
        }
        setState(() {
          _suggestions = parsed;
          _isLoading = false;
          _error = null;
        });
      } else {
        throw Exception('Invalid suggestions response format');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _suggestions = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B7FA3)),
            ),
            SizedBox(width: 10),
            Text('Generating AI suggestions…',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCC80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE65100), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('GROQ FAILED: $_error',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE65100))),
            ),
          ],
        ),
      );
    }

    if (_suggestions == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Color(0xFF6B7FA3), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('No reviews yet. AI suggestions will appear once customers submit reviews.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
          ],
        ),
      );
    }

    final sectionConfig = <String, Map<String, dynamic>>{
      'Strengths': {
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF2E7D32),
        'bgColor': const Color(0xFFE8F5E9),
        'borderColor': const Color(0xFFA5D6A7),
      },
      'Areas to Improve': {
        'icon': Icons.warning_amber_outlined,
        'color': const Color(0xFFE65100),
        'bgColor': const Color(0xFFFFF3E0),
        'borderColor': const Color(0xFFFFCC80),
      },
      'Recommended Actions': {
        'icon': Icons.lightbulb_outline,
        'color': const Color(0xFF1565C0),
        'bgColor': const Color(0xFFE3F2FD),
        'borderColor': const Color(0xFF90CAF9),
      },
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _suggestions!.keys.map((sectionTitle) {
          final items = _suggestions![sectionTitle] ?? [];
          if (items.isEmpty) return const SizedBox.shrink();
          final config = sectionConfig[sectionTitle]!;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: config['bgColor'] as Color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: config['borderColor'] as Color, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(config['icon'] as IconData, size: 16, color: config['color'] as Color),
                      const SizedBox(width: 6),
                      Text(sectionTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: config['color'] as Color,
                          )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 12, height: 1.4)),
                        Expanded(
                          child: Text(item,
                              style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.4)),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aspect Review Bottom Sheet (with interactive filter chips)
// ─────────────────────────────────────────────────────────────────────────────
class _AspectReviewSheet extends StatefulWidget {
  final List<Review> allReviews;
  final String aspectKey;
  final String label;
  final int totalCount;
  final int positiveCount;
  final int negativeCount;
  final double avgAspectRating;

  const _AspectReviewSheet({
    required this.allReviews,
    required this.aspectKey,
    required this.label,
    required this.totalCount,
    required this.positiveCount,
    required this.negativeCount,
    required this.avgAspectRating,
  });

  @override
  State<_AspectReviewSheet> createState() => _AspectReviewSheetState();
}

class _AspectReviewSheetState extends State<_AspectReviewSheet> {
  String _filter = 'all'; // 'all', 'positive', 'negative'

  List<Review> get _filteredReviews {
    switch (_filter) {
      case 'positive':
        return widget.allReviews
            .where((r) => r.sentiment.trim().toUpperCase() == 'POSITIVE')
            .toList();
      case 'negative':
        return widget.allReviews
            .where((r) => r.sentiment.trim().toUpperCase() == 'NEGATIVE')
            .toList();
      default:
        return widget.allReviews;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredReviews;
    final displayedCount = displayed.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color(0xFFD0D0D0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // ── Header section ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aspect title - 24px semi-bold
                    Text(
                      '${widget.label} Reviews',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Total reviews
                    Text(
                      '${widget.totalCount} Review${widget.totalCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interactive filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All (${widget.totalCount})',
                            isActive: _filter == 'all',
                            activeColor: const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 10),
                          _buildFilterChip(
                            label: 'Positive (${widget.positiveCount})',
                            isActive: _filter == 'positive',
                            activeColor: const Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 10),
                          _buildFilterChip(
                            label: 'Negative (${widget.negativeCount})',
                            isActive: _filter == 'negative',
                            activeColor: const Color(0xFFD32F2F),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Review list ─────────────────────────────────────────
              if (displayed.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No reviews found for this filter',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: displayed.length,
                    itemBuilder: (ctx, i) {
                      final r = displayed[i];
                      final isPos = r.sentiment.trim().toUpperCase() == 'POSITIVE';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: stars (left) + sentiment badge (right)
                            Row(
                              children: [
                                // Stars
                                Row(
                                  children: List.generate(
                                    5,
                                    (starI) => Padding(
                                      padding: const EdgeInsets.only(right: 2),
                                      child: Icon(
                                        starI < r.stars
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFFFFC107),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                // Sentiment badge (top-right)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPos
                                        ? const Color(0xFFDFF5E1)
                                        : const Color(0xFFFDE2E2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isPos ? 'POSITIVE' : 'NEGATIVE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPos
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Highlighted review text
                            buildHighlightedReviewText(r.text,
                                aspectKey: widget.aspectKey),
                            const SizedBox(height: 8),
                            // Guest name
                            Text(
                              r.customerName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          switch (label.split(' ').first.toLowerCase()) {
            case 'all':
              _filter = 'all';
              break;
            case 'positive':
              _filter = 'positive';
              break;
            case 'negative':
              _filter = 'negative';
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _SentimentPiePainter extends CustomPainter {
  final int positiveCount;
  final int negativeCount;

  _SentimentPiePainter({
    required this.positiveCount,
    required this.negativeCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final total = positiveCount + negativeCount;
    final paint = Paint()..style = PaintingStyle.fill;

    if (total == 0) {
      paint.color = AppColors.lightGrey;
      canvas.drawCircle(center, radius, paint);
      final textSpan = TextSpan(
        text: '0%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      return;
    }

    final positiveAngle = (positiveCount / total) * 2 * math.pi;
    final negativeAngle = (negativeCount / total) * 2 * math.pi;
    final startAngle = -math.pi / 2;

    paint.color = Colors.green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      positiveAngle,
      true,
      paint,
    );

    paint.color = Colors.red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + positiveAngle,
      negativeAngle,
      true,
      paint,
    );

    final positivePct = positiveCount / total * 100;
    final negativePct = negativeCount / total * 100;

    void drawLabel(double angle, String label) {
      final labelRadius = radius * 0.55;
      final offset = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2));
    }

    if (positiveCount > 0) {
      drawLabel(startAngle + positiveAngle / 2,
          '${positivePct.toStringAsFixed(1)}%');
    }
    if (negativeCount > 0) {
      drawLabel(startAngle + positiveAngle + negativeAngle / 2,
          '${negativePct.toStringAsFixed(1)}%');
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.lightGrey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SentimentPiePainter oldDelegate) {
    return oldDelegate.positiveCount != positiveCount ||
        oldDelegate.negativeCount != negativeCount;
  }
}

