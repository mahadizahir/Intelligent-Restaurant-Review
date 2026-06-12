import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/image_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  Uint8List? _avatarBytes;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    // For owners, pre-fill address from their restaurant
    final restaurant = context.read<AppState>().ownerRestaurant;
    _addressCtrl =
        TextEditingController(text: restaurant?.address ?? '');
    _avatarBytes = user?.avatarBytes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final bytes = await ImageHelper.showPickerSheet(context);
    if (bytes != null) setState(() => _avatarBytes = bytes);
  }

  void _saveProfile() {
    final state = context.read<AppState>();
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    // Update address on restaurant if owner
    if (state.isOwner) {
      final r = state.ownerRestaurant;
      if (r != null) r.address = _addressCtrl.text.trim();
    }

    state.updateProfile(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      avatarBytes: _avatarBytes,
    );

    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser;
    final isOwner = state.isOwner;
    final restaurant = state.ownerRestaurant;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            color: AppColors.headerBlue,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'MY PROFILE',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_editing) {
                      _saveProfile();
                    } else {
                      setState(() => _editing = true);
                    }
                  },
                  child: Text(
                    _editing ? 'SAVE' : 'EDIT',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Avatar ────────────────────────────────────────────
                  const SizedBox(height: 12),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightGrey,
                          border: Border.all(
                              color: AppColors.headerBlue, width: 3),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: _avatarBytes != null
                            ? Image.memory(_avatarBytes!,
                                fit: BoxFit.cover)
                            : const Icon(Icons.person,
                                size: 54, color: AppColors.grey),
                      ),
                      if (_editing)
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: AppColors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOwner
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.headerBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOwner ? '🏪 Restaurant Owner' : '👤 Customer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isOwner
                            ? AppColors.primary
                            : AppColors.headerBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Info card ─────────────────────────────────────────
                  _Card(
                    title: 'Personal Information',
                    child: Column(
                      children: [
                        _Field(
                          icon: Icons.person_outline,
                          label: isOwner
                              ? 'Restaurant / Owner Name'
                              : 'Full Name',
                          controller: _nameCtrl,
                          enabled: _editing,
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          controller: TextEditingController(
                              text: user?.email ?? ''),
                          enabled: false, // email not editable
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          icon: Icons.phone_outlined,
                          label: 'Phone Number',
                          controller: _phoneCtrl,
                          enabled: _editing,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),

                  // ── Owner-only: restaurant info ────────────────────────
                  if (isOwner && restaurant != null) ...[
                    const SizedBox(height: 16),
                    _Card(
                      title: 'Restaurant Information',
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.storefront_outlined,
                            label: 'Restaurant Name',
                            value: restaurant.name,
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            icon: Icons.location_on_outlined,
                            label: 'Address',
                            controller: _addressCtrl,
                            enabled: _editing,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 14),
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Business Email',
                            value: restaurant.email,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Stats card ────────────────────────────────────────
                  _Card(
                    title: isOwner ? 'Restaurant Stats' : 'Activity',
                    child: isOwner
                        ? _OwnerStats(restaurantId: restaurant?.id ?? '')
                        : _CustomerStats(),
                  ),

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

// ── Reusable card ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Editable field ────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;
  final int maxLines;

  const _Field({
    required this.icon,
    required this.label,
    required this.controller,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child:
              Icon(icon, size: 18, color: AppColors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textDark),
            decoration: InputDecoration(
              labelText: label,
              labelStyle:
                  const TextStyle(fontSize: 12, color: AppColors.grey),
              filled: true,
              fillColor: enabled
                  ? AppColors.lightGrey
                  : Colors.transparent,
              border: enabled
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    )
                  : const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: AppColors.lightGrey)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Read-only info row ────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppColors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grey)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Owner stats widget ────────────────────────────────────────────────────────
class _OwnerStats extends StatelessWidget {
  final String restaurantId;
  const _OwnerStats({required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reviews = state.reviewsFor(restaurantId);
    final menuItems = state.menuItemsFor(restaurantId);
    final avg = state.averageRatingFor(restaurantId);
    final pos =
      reviews.where((r) => r.sentiment.trim().toUpperCase() == 'POSITIVE').length;

    return Row(
      children: [
        _StatTile(
            label: 'Avg Rating',
            value: avg > 0 ? avg.toStringAsFixed(1) : '-',
            icon: Icons.star,
            color: const Color(0xFFFFC107)),
        _StatTile(
            label: 'Reviews',
            value: '${reviews.length}',
            icon: Icons.rate_review_outlined,
            color: AppColors.headerBlue),
        _StatTile(
            label: 'Menu Items',
            value: '${menuItems.length}',
            icon: Icons.restaurant_menu,
            color: AppColors.primary),
        _StatTile(
            label: 'Positive',
            value: '$pos',
            icon: Icons.thumb_up_outlined,
            color: Colors.green),
      ],
    );
  }
}

// ── Customer stats widget ─────────────────────────────────────────────────────
class _CustomerStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.currentUser?.name ?? '';
    // Count reviews by this customer across all restaurants
    int myReviews = 0;
    for (final r in state.restaurants) {
      myReviews +=
          state.reviewsFor(r.id).where((rv) => rv.customerName == name).length;
    }
    return Row(
      children: [
        _StatTile(
            label: 'Restaurants',
            value: '${state.restaurants.length}',
            icon: Icons.storefront_outlined,
            color: AppColors.primary),
        _StatTile(
            label: 'My Reviews',
            value: '$myReviews',
            icon: Icons.rate_review_outlined,
            color: AppColors.headerBlue),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}