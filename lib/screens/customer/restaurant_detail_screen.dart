import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/image_helper.dart';

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

  void _submitReview() {
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
    context.read<AppState>().addReview(
          restaurantId: widget.restaurantId,
          stars: _reviewStars,
          text: _reviewController.text,
        );
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
    final reviews = state.reviewsFor(widget.restaurantId);
    final avg = state.averageRatingFor(widget.restaurantId);

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
                  const Icon(Icons.star, color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                      avg > 0 ? avg.toStringAsFixed(1) : '–',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
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
                    label: 'Reviews (${reviews.length})',
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
                    _ReviewsTab(
                      reviews: reviews,
                      stars: _reviewStars,
                      onStarTap: (s) => setState(() => _reviewStars = s),
                      reviewController: _reviewController,
                      onSubmit: _submitReview,
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
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Customer Reviews',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),

        // Existing reviews
        ...reviews.map((r) {
          final isPos = r.sentiment == 'POSITIVE';
          final isNeg = r.sentiment == 'NEGATIVE';
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
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.sentiment,
                    style: TextStyle(
                      color: isPos
                          ? AppColors.white
                          : isNeg
                              ? Colors.redAccent
                              : Colors.orangeAccent,
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