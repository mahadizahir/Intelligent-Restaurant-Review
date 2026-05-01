// ─────────────────────────────────────────────────────────────────────────────
// APP STATE  –  single source of truth (no Firebase, pure in-memory)
// Images stored as Uint8List bytes → works on Web + Mobile
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:typed_data';
import 'package:flutter/material.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  String name;
  String email;
  final String password;
  final bool isOwner;
  final String? restaurantId;
  String phone;
  Uint8List? avatarBytes; // profile photo bytes

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.isOwner,
    this.restaurantId,
    this.phone = '',
    this.avatarBytes,
  });
}

class Restaurant {
  final String id;
  final String ownerId;
  String name;
  String address;
  String phone;
  String email;

  Restaurant({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
  });
}

class MenuItem {
  final String id;
  final String restaurantId;
  String name;
  String price;
  String description;
  double rating;
  Uint8List? imageBytes; // food photo bytes — works on Web + Mobile

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.price,
    required this.description,
    this.rating = 0.0,
    this.imageBytes,
  });
}

class Review {
  final String id;
  final String restaurantId;
  final String customerName;
  final int stars;
  final String text;
  final String sentiment;

  Review({
    required this.id,
    required this.restaurantId,
    required this.customerName,
    required this.stars,
    required this.text,
    required this.sentiment,
  });
}

// ── AppState ──────────────────────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  final List<AppUser> _users = [];

  final List<Restaurant> _restaurants = [
    Restaurant(
      id: 'r_seed1',
      ownerId: 'seed_owner1',
      name: 'Restoran Wardini Ikan Bakar',
      address: 'Taman Bendahara, 16100 Pengkalan Chepa, Kelantan',
      phone: '09-000 0001',
      email: 'wardini@restaurant.com',
    ),
    Restaurant(
      id: 'r_seed2',
      ownerId: 'seed_owner2',
      name: 'Chil Garden Restaurant',
      address: 'Lot 3633, Jln Tok Guru, Kampung Baung, 16100 Kota Bharu, Kelantan',
      phone: '09-000 0002',
      email: 'chil@restaurant.com',
    ),
  ];

  final List<MenuItem> _menuItems = [
    MenuItem(
      id: 'm_seed1',
      restaurantId: 'r_seed1',
      name: 'Ikan Bakar Spesial',
      price: 'RM 15.00',
      description: 'Grilled fish marinated in aromatic spices.',
      rating: 4.2,
    ),
    MenuItem(
      id: 'm_seed2',
      restaurantId: 'r_seed2',
      name: 'Chil Garden Set',
      price: 'RM 22.00',
      description: 'Signature set with garden-fresh greens and grilled chicken.',
      rating: 4.7,
    ),
  ];

  final List<Review> _reviews = [
    Review(
      id: 'rv_seed1',
      restaurantId: 'r_seed1',
      customerName: 'Guest',
      stars: 4,
      text: 'Fresh fish and great service!',
      sentiment: 'POSITIVE',
    ),
    Review(
      id: 'rv_seed2',
      restaurantId: 'r_seed2',
      customerName: 'Guest',
      stars: 5,
      text: 'Amazing ambience and food.',
      sentiment: 'POSITIVE',
    ),
  ];

  // ── Session ───────────────────────────────────────────────────────────────
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isOwner => _currentUser?.isOwner ?? false;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<Restaurant> get restaurants => List.unmodifiable(_restaurants);

  List<MenuItem> menuItemsFor(String restaurantId) =>
      _menuItems.where((m) => m.restaurantId == restaurantId).toList();

  List<Review> reviewsFor(String restaurantId) =>
      _reviews.where((r) => r.restaurantId == restaurantId).toList();

  Restaurant? get ownerRestaurant {
    if (_currentUser == null || !_currentUser!.isOwner) return null;
    try {
      return _restaurants
          .firstWhere((r) => r.id == _currentUser!.restaurantId);
    } catch (_) {
      return null;
    }
  }

  double averageRatingFor(String restaurantId) {
    final reviews = reviewsFor(restaurantId);
    if (reviews.isEmpty) return 0.0;
    return reviews.map((r) => r.stars).reduce((a, b) => a + b) /
        reviews.length;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  String? register({
    required String name,
    required String email,
    required String password,
    required bool isOwner,
    String address = '',
    String phone = '',
  }) {
    final trimEmail = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'Name cannot be empty.';
    if (trimEmail.isEmpty) return 'Email cannot be empty.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (_users.any((u) => u.email.toLowerCase() == trimEmail)) {
      return 'An account with this email already exists.';
    }

    String? restaurantId;

    if (isOwner) {
      final rid = 'r_${DateTime.now().millisecondsSinceEpoch}';
      final uid = 'u_${DateTime.now().millisecondsSinceEpoch}';
      _restaurants.add(Restaurant(
        id: rid,
        ownerId: uid,
        name: name.trim(),
        address: address.trim().isNotEmpty
            ? address.trim()
            : 'Address not set – update in profile',
        phone: phone.trim().isNotEmpty ? phone.trim() : '-',
        email: trimEmail,
      ));
      restaurantId = rid;

      final user = AppUser(
        id: uid,
        name: name.trim(),
        email: trimEmail,
        password: password,
        isOwner: true,
        restaurantId: restaurantId,
        phone: phone.trim(),
      );
      _users.add(user);
      _currentUser = user;
      notifyListeners();
      return null;
    }

    final uid = 'u_${DateTime.now().millisecondsSinceEpoch}';
    final user = AppUser(
      id: uid,
      name: name.trim(),
      email: trimEmail,
      password: password,
      isOwner: false,
      phone: phone.trim(),
    );
    _users.add(user);
    _currentUser = user;
    notifyListeners();
    return null;
  }

  String? login({
    required String email,
    required String password,
    required bool isOwner,
  }) {
    final trimEmail = email.trim().toLowerCase();
    try {
      final user = _users.firstWhere(
        (u) =>
            u.email.toLowerCase() == trimEmail &&
            u.password == password &&
            u.isOwner == isOwner,
      );
      _currentUser = user;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Invalid email, password, or account type.';
    }
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  void updateProfile({
    required String name,
    required String phone,
    Uint8List? avatarBytes,
  }) {
    if (_currentUser == null) return;
    _currentUser!.name = name.trim();
    _currentUser!.phone = phone.trim();
    if (avatarBytes != null) _currentUser!.avatarBytes = avatarBytes;

    // If owner, also update restaurant name
    if (_currentUser!.isOwner) {
      final idx = _restaurants
          .indexWhere((r) => r.id == _currentUser!.restaurantId);
      if (idx != -1) _restaurants[idx].name = name.trim();
    }
    notifyListeners();
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  void addMenuItem({
    required String restaurantId,
    required String name,
    required String price,
    required String description,
    Uint8List? imageBytes,
  }) {
    _menuItems.add(MenuItem(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      restaurantId: restaurantId,
      name: name.trim(),
      price: price.trim(),
      description: description.trim(),
      rating: 0.0,
      imageBytes: imageBytes,
    ));
    notifyListeners();
  }

  void editMenuItem({
    required String menuItemId,
    required String name,
    required String price,
    required String description,
    Uint8List? imageBytes,
    bool clearImage = false,
  }) {
    final idx = _menuItems.indexWhere((m) => m.id == menuItemId);
    if (idx == -1) return;
    final old = _menuItems[idx];
    _menuItems[idx] = MenuItem(
      id: old.id,
      restaurantId: old.restaurantId,
      name: name.trim(),
      price: price.trim(),
      description: description.trim(),
      rating: old.rating,
      imageBytes: clearImage ? null : (imageBytes ?? old.imageBytes),
    );
    notifyListeners();
  }

  void deleteMenuItem(String menuItemId) {
    _menuItems.removeWhere((m) => m.id == menuItemId);
    notifyListeners();
  }

  // ── Reviews ───────────────────────────────────────────────────────────────

  String _autoSentiment(int stars, String text) {
    if (stars >= 4) return 'POSITIVE';
    if (stars <= 2) return 'NEGATIVE';
    final lower = text.toLowerCase();
    final pos = ['good', 'great', 'amazing', 'love', 'excellent', 'nice', 'best', 'delicious'];
    final neg = ['bad', 'terrible', 'awful', 'worst', 'horrible', 'slow', 'cold', 'wrong'];
    final p = pos.where((w) => lower.contains(w)).length;
    final n = neg.where((w) => lower.contains(w)).length;
    if (p > n) return 'POSITIVE';
    if (n > p) return 'NEGATIVE';
    return 'NEUTRAL';
  }

  void addReview({
    required String restaurantId,
    required int stars,
    required String text,
  }) {
    _reviews.add(Review(
      id: 'rv_${DateTime.now().millisecondsSinceEpoch}',
      restaurantId: restaurantId,
      customerName: _currentUser?.name ?? 'Guest',
      stars: stars,
      text: text.trim(),
      sentiment: _autoSentiment(stars, text),
    ));
    notifyListeners();
  }
}