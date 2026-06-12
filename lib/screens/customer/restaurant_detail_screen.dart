import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/image_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RestaurantDetailScreen extends StatefulWidget {
  final String restaurantId;
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  State<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  int _tab = 0; // 0=Menu 1=Reviews 2=About
  int _reviewStars = 0;
  final _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<Future<void>> _submitReview() async async {
    if (_reviewStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a star rating.')));
      return;
    }
    if (_reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please write your review.')));
      return;
    }
    final state = context.read<AppState>();

final response = await http.post(
  Uri.parse('http://127.0.0.1:5000/add_review'),
  headers: {
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'user_id': int.parse(state.currentUser!.id),
    'restaurant_id': int.parse(widget.restaurantId),
    'rating': _reviewStars,
    'comment': _reviewController.text,

    'food_rating': _reviewStars.toDouble(),
    'service_rating': _reviewStars.toDouble(),
    'price_rating': _reviewStars.toDouble(),
    'cleanliness_rating': _reviewStars.toDouble(),
  }),
);

final data = jsonDecode(response.body);

if (data['success'] != true) {
  throw Exception(data['message']);
}

await state.loadRestaurants();

    setState(() {
      _reviewStars = 0;
      _reviewController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Review submitted! Owner can now see it.'),
          backgroundColor: Colors.green),
    );
  }

  Color _bannerColor() {
    const colors = [
      Color(0xFFE8741A),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFF9C27B0),
    ];
    return colors[widget.restaurantId.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final restaurant =
        state.restaurants.firstWhere((r) => r.id == widget.restaurantId);
    final menuItems = state.menuItemsFor(widget.restaurantId);

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: Column(
        children: [
          // ── Banner ─────────────────────────────────────────────────────
          Stack(
            children: [
              Container(
                height: 120,
                width: double.infinity,
                color: _bannerColor(),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    restaurant.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),

          // ── Name + rating ───────────────────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(restaurant.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Row(children: [
                  Icon(Icons.star,
                      color: avg > 0 ? AppColors.primary : AppColors.grey,
                      size: 16),
                  const SizedBox(width: 4),
                  
                  FutureBuilder<double>(
  future: (() {
    print(
      'Calling loadAverageRating for restaurant ${widget.restaurantId}'
    );
    return state.loadAverageRating(widget.restaurantId);
  })(),
  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const Text(
        '-',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Text(
      snapshot.data!.toStringAsFixed(1),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  },
),
                ]),
              ],
            ),
          ),

          // ── Tab bar ─────────────────────────────────────────────────────
          Container(
            color: AppColors.white,
            child: Row(
              children: [
                _TabBtn(
                    label: 'Menu',
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0)),
                _TabBtn(
                    label: 'Reviews',
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1)),
                _TabBtn(
                    label: 'About',
                    active: _tab == 2,
                    onTap: () => setState(() => _tab = 2)),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  if (_tab == 0) _MenuTab(items: menuItems),
                  if (_tab == 1)
  FutureBuilder<List<Review>>(
    future: state.loadReviews(widget.restaurantId),
    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        );
      }

      final reviews = snapshot.data!;

      return _ReviewsTab(
        reviews: reviews,
        stars: _reviewStars,
        onStarTap: (s) => setState(() => _reviewStars = s),
        reviewController: _reviewController,
        onSubmit: _submitReview,
      );
    },
  ),
                  if (_tab == 2) _AboutTab(restaurant: restaurant),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AppColors.black : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              color: active ? AppColors.textDark : AppColors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Menu tab — shows food images from bytes ───────────────────────────────────
class _MenuTab extends StatelessWidget {
  final List<MenuItem> items;
  const _MenuTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
            child: Text('No menu items yet.',
                style: TextStyle(color: AppColors.grey))),
      );
    }
    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightGrey),
          ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // keep badge aligned to the top-right corner

              // ── Food image from bytes ──────────────────────────────────
              BytesImage(
                bytes: item.imageBytes,
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(10),
                placeholder: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_menu,
                      color: AppColors.grey, size: 34),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(item.price,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary)),
                    if (item.rating > 0)
                      Row(children: [
                        const Icon(Icons.star,
                            color: Color(0xFFFFC107), size: 14),
                        const SizedBox(width: 3),
                        Text(item.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12)),
                      ]),
                    const SizedBox(height: 4),
                    Text(item.description,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Rating summary card ───────────────────────────────────────────────────────
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                // ── Average rating (centered on narrow screens) ──────
                _buildAverageColumn(avg, total),
                const SizedBox(height: 20),
                // ── Distribution bars ─────────────────────────────────
                _buildDistributionBars(counts, total),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Average rating (left side on wider screens) ──────
                _buildAverageColumn(avg, total),
                const SizedBox(width: 32),
                // ── Distribution bars (right side) ────────────────────
                Expanded(child: _buildDistributionBars(counts, total)),
              ],
            ),
    );
  }

  // ── Left side: average rating column ──────────────────────────────────────
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
          // Stars
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
          // Total count / empty label
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

  // ── Right side: distribution bars ─────────────────────────────────────────
  Widget _buildDistributionBars(List<int> counts, int total) {
    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i; // 5, 4, 3, 2, 1
        final count = counts[star];
        final fraction = total > 0 ? count / total : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Star label
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
              // Progress bar
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
              // Count
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

// ── Reviews tab ───────────────────────────────────────────────────────────────
class _ReviewsTab extends StatelessWidget {
  final List<Review> reviews;
  final int stars;
  final ValueChanged<int> onStarTap;
  final TextEditingController reviewController;
  final VoidCallback onSubmit;

  const _ReviewsTab({
    required this.reviews,
    required this.stars,
    required this.onStarTap,
    required this.reviewController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Customer Reviews',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (reviews.length > 1)
                Text('${reviews.length} total',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grey)),
            ],
          ),
        ),

        // Rating summary card
        _RatingSummaryCard(reviews: reviews),

        // Existing reviews
        ...reviews.map((r) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.lightGrey),
            ),
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
                        (i) => Icon(
                            i < r.stars
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFFFC107),
                            size: 16),
                      )),
                      const SizedBox(height: 4),
                      Text(r.text,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('— ${r.customerName}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  alignment: Alignment.topRight,
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.sentiment.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Write a review
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Write a Review',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              const Text('Your Rating',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textDark)),
              const SizedBox(height: 6),
              Row(
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => onStarTap(i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        i < stars ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFC107),
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Your Review',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Share your thoughts about this restaurant...',
                  hintStyle: const TextStyle(
                      color: AppColors.grey, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.lightGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.black,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Submit Review'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Cancel',
                        style:
                            TextStyle(color: AppColors.textDark)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── About tab ─────────────────────────────────────────────────────────────────
class _AboutTab extends StatelessWidget {
  final Restaurant restaurant;
  const _AboutTab({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About ${restaurant.name}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _row(Icons.location_on_outlined, restaurant.address),
          const SizedBox(height: 8),
          _row(Icons.phone_outlined, restaurant.phone),
          const SizedBox(height: 8),
          _row(Icons.email_outlined, restaurant.email),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.grey),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textDark))),
      ],
    );
  }
}