import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_state.dart';
import '../../theme/app_colors.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/profile_screen.dart';
import '../../widgets/image_helper.dart';
import 'package:http/http.dart' as http;

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  
List<Review> _reviews = [];
double _avgRating = 0.0;

double _foodRating = 0.0;
double _serviceRating = 0.0;
double _priceRating = 0.0;
double _cleanlinessRating = 0.0;

 @override
void initState() {
  super.initState();

  print("OWNER DASHBOARD OPENED");

  WidgetsBinding.instance.addPostFrameCallback((_) async {

    print("CALLING LOAD RESTAURANTS");

    final state = context.read<AppState>();

await state.loadRestaurants();

await state.loadMenuItems();

final restaurant = state.ownerRestaurant;

if (restaurant != null) {

  _reviews =
      await state.loadReviews(restaurant.id);

  _avgRating =
      await state.loadAverageRating(restaurant.id);

      final metrics =
    await state.loadRestaurantMetrics(
      restaurant.id,
    );

_foodRating = metrics['food']!;
_serviceRating = metrics['service']!;
_priceRating = metrics['price']!;
_cleanlinessRating = metrics['cleanliness']!;

  setState(() {});
}

    print(
      "OWNER PAGE RESTAURANTS = ${context.read<AppState>().restaurants.length}"
    );
  });
}
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
                          : editItem?.imagePath != null &&
                        editItem!.imagePath!.isNotEmpty
                    ? Image.network(
                        "http://127.0.0.1:5000/uploads/${editItem.imagePath}",
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 52,
                            color: AppColors.grey.withOpacity(0.65),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tap to add food photo',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey.withOpacity(0.8),
                            ),
                          ),
                        ],
                      )
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
                        onPressed: () async {
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
                            if (pickedBytes != null) {

                              var request = http.MultipartRequest(
                                'POST',
                                Uri.parse(
                                  'http://127.0.0.1:5000/update_menu_image',
                                ),
                              );

                              request.fields['menu_id'] = editItem.id;

                              request.files.add(
                                http.MultipartFile.fromBytes(
                                  'image',
                                  pickedBytes!,
                                  filename: 'menu_${editItem.id}.jpg',
                                ),
                              );

                              print("UPLOADING IMAGE...");
                              print("MENU ID = ${editItem.id}");

                              print("UPLOADING MENU ID = ${editItem.id}");

                              var response = await request.send();

                              print("UPLOAD STATUS = ${response.statusCode}");

                              await st.loadMenuItems();
                            }

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

    print("USER ID = ${state.currentUser?.id}");
    print("USER RESTAURANT ID = ${state.currentUser?.restaurantId}");
    print("TOTAL RESTAURANTS = ${state.restaurants.length}");
    print("OWNER RESTAURANT = ${restaurant?.name}");

    final reviews = _reviews;
    final menuItems = restaurant != null
        ? state.menuItemsFor(restaurant.id)
        : <MenuItem>[];
    final avgRating = _avgRating;

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
                        ? Image.memory(user!.avatarBytes!,
                            fit: BoxFit.cover)
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
                  _RatingSummaryCard(
                      avgRating: avgRating,
                      totalRatings: reviews.length),
                  const SizedBox(height: 8),
                  _CategoryScoresCard(
                    food: _foodRating,
                    service: _serviceRating,
                    price: _priceRating,
                    cleanliness: _cleanlinessRating,
                  ),
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
  final double avgRating;
  final int totalRatings;
  const _RatingSummaryCard(
      {required this.avgRating, required this.totalRatings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(avgRating > 0 ? avgRating.toStringAsFixed(1) : '–',
                  style: const TextStyle(
                      fontSize: 42, fontWeight: FontWeight.bold)),
              Row(
                  children: List.generate(
                5,
                (i) => Icon(
                    i < avgRating.round()
                        ? Icons.star
                        : Icons.star_border,
                    color: const Color(0xFFFFC107),
                    size: 20),
              )),
              const SizedBox(height: 4),
              Text(
                  '$totalRatings ${totalRatings == 1 ? 'rating' : 'ratings'}',
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final frac = star == 5
                    ? 0.75
                    : star == 4
                        ? 0.10
                        : 0.05;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Text('$star',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 6,
                          backgroundColor: AppColors.lightGrey,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFC107)),
                        ),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryScoresCard extends StatelessWidget {
  
  final double food;
  final double service;
  final double price;
  final double cleanliness;

  const _CategoryScoresCard({
    required this.food,
    required this.service,
    required this.price,
    required this.cleanliness,
  });

  @override
  Widget build(BuildContext context) {
   final scores = [
  {'label': 'Food', 'value': food},
  {'label': 'Service', 'value': service},
  {'label': 'Price', 'value': price},
  {'label': 'Cleanliness', 'value': cleanliness},
];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: scores.map((s) {
          final val = s['value'] as double;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B7FA3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s['label'] as String,
                    style: const TextStyle(
                        color: AppColors.white, fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: val / 5.0,
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
                  Text(val.toStringAsFixed(1),
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AISummaryCard extends StatelessWidget {
  final List<Review> reviews;
  const _AISummaryCard({required this.reviews});

  String _summary() {
    if (reviews.isEmpty) {
      return 'No reviews yet. Share your restaurant with customers to get started!';
    }
    final pos =
        reviews.where((r) => r.sentiment == 'POSITIVE').length;
    final neg =
        reviews.where((r) => r.sentiment == 'NEGATIVE').length;
    final avg = reviews.map((r) => r.stars).reduce((a, b) => a + b) /
        reviews.length;
    if (pos > neg) {
      return 'Overall ${reviews.length} review${reviews.length > 1 ? 's' : ''} with a ${avg.toStringAsFixed(1)} average — mostly positive. Customers are happy!';
    } else if (neg > pos) {
      return '${reviews.length} review${reviews.length > 1 ? 's' : ''} averaging ${avg.toStringAsFixed(1)} stars. Some concerns raised — consider improving service.';
    }
    return 'Mixed reviews with ${avg.toStringAsFixed(1)} average. Keep improving!';
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
          Text(_summary(),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textDark)),
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
            'No reviews yet.\nCustomers can leave reviews from the restaurant page.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          ),
        ),
      );
    }
    return Column(
      children: reviews.reversed.map((r) {
        final isPos = r.sentiment == 'POSITIVE';
        final isNeg = r.sentiment == 'NEGATIVE';
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
                      (i) => Icon(
                          i < r.stars
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFFFFC107),
                          size: 18),
                    )),
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

      print("MENU TAB ITEMS = ${items.length}");

  for (var item in items) {
    print(
      "DISPLAYING ${item.name} | imagePath=${item.imagePath}"
    );
  }

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imagePath != null &&
                              item.imagePath!.isNotEmpty
                          ? Image.network(
                              "http://127.0.0.1:5000/uploads/${item.imagePath}",
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,

                              loadingBuilder: (context, child, loadingProgress) {
                                print("LOADING IMAGE = ${item.imagePath}");
                                return child;
                              },

                              errorBuilder: (context, error, stackTrace) {
                                print("IMAGE ERROR = $error");

                                return Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.red,
                                );
                              },
                            )
                          : Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.restaurant),
                            ),
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
                              const Icon(Icons.star,
                                  color: Color(0xFFFFC107),
                                  size: 14),
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
        ],
      ),
    );
  }
}