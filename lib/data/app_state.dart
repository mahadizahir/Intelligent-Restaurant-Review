// ─────────────────────────────────────────────────────────────────────────────
// APP STATE – connected to Flask API + MySQL database
// Flutter → Flask API → MySQL/phpMyAdmin
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'host_helper.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  String name;
  String email;
  final String password;
  final bool isOwner;
  final String? restaurantId;
  String phone;
  Uint8List? avatarBytes;

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
  double averageRating;
  int totalReviews;

  Restaurant({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });
}

class MenuItem {
  final String id;
  final String restaurantId;
  String name;
  String price;
  String description;
  double rating;
  Uint8List? imageBytes;

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
  final List<Restaurant> _restaurants = [];
  final List<MenuItem> _menuItems = [];
  final List<Review> _reviews = [];

  AppState() {
    loadRestaurants();
  }

  static String get _apiBaseUrl => getApiBaseUrl();
  static String get _sentimentApiUrl => getSentimentApiUrl();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isOwner => _currentUser?.isOwner ?? false;

  List<Restaurant> get restaurants => List.unmodifiable(_restaurants);

  List<MenuItem> menuItemsFor(String restaurantId) =>
      _menuItems.where((m) => m.restaurantId == restaurantId).toList();

  List<Review> reviewsFor(String restaurantId) =>
      _reviews.where((r) => r.restaurantId == restaurantId).toList();

  Restaurant? get ownerRestaurant {
    if (_currentUser == null || !_currentUser!.isOwner) return null;
    try {
      return _restaurants.firstWhere((r) => r.id == _currentUser!.restaurantId);
    } catch (_) {
      return null;
    }
  }

  double averageRatingFor(String restaurantId) {
    final reviews = reviewsFor(restaurantId);
    if (reviews.isNotEmpty) {
      return reviews.map((r) => r.stars).reduce((a, b) => a + b) /
          reviews.length;
    }
    try {
      return _restaurants.firstWhere((r) => r.id == restaurantId).averageRating;
    } catch (_) {
      return 0.0;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatPrice(dynamic value) {
    final text = value?.toString().trim() ?? '0.00';
    if (text.toUpperCase().startsWith('RM')) return text;
    return 'RM $text';
  }

  String _responseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) return body['error'].toString();
      if (body is Map && body['message'] != null) return body['message'].toString();
    } catch (_) {}
    return 'Server error: ${response.statusCode}';
  }

  AppUser _parseUser(Map<String, dynamic> json, String password) {
    final isOwner = json['isOwner'] == true || json['role'] == 'owner';
    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      password: password,
      isOwner: isOwner,
      restaurantId: json['restaurantId']?.toString(),
      phone: json['phone']?.toString() ?? '',
    );
  }

  Restaurant _parseRestaurant(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? json['ownerId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      averageRating: _toDouble(json['average_rating'] ?? json['averageRating']),
      totalReviews: _toInt(json['total_reviews'] ?? json['totalReviews']),
    );
  }

  MenuItem _parseMenuItem(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id']?.toString() ?? '',
      restaurantId:
          json['restaurant_id']?.toString() ?? json['restaurantId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: _formatPrice(json['price']),
      description: json['description']?.toString() ?? '',
      rating: _toDouble(json['rating']),
    );
  }

  Review _parseReview(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      restaurantId:
          json['restaurant_id']?.toString() ?? json['restaurantId']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ??
          json['customerName']?.toString() ??
          'Guest',
      stars: _toInt(json['rating'] ?? json['stars']),
      text: json['comment']?.toString() ?? json['text']?.toString() ?? '',
      sentiment: (json['sentiment']?.toString() ?? 'neutral').toUpperCase(),
    );
  }

  // ── Load data from database ────────────────────────────────────────────────

  Future<void> loadRestaurants() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/restaurants'));
      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body);
      if (body is! List) return;

      _restaurants
        ..clear()
        ..addAll(body
            .whereType<Map>()
            .map((e) => _parseRestaurant(Map<String, dynamic>.from(e))));

      for (final r in _restaurants) {
        await loadRestaurantDetails(r.id, notify: false);
      }

      notifyListeners();
    } catch (_) {
      // Keep app usable even if API is temporarily offline.
    }
  }

  Future<void> loadRestaurantDetails(String restaurantId,
      {bool notify = true}) async {
    try {
      final menuResponse =
          await http.get(Uri.parse('$_apiBaseUrl/restaurants/$restaurantId/menu'));
      if (menuResponse.statusCode == 200) {
        final body = jsonDecode(menuResponse.body);
        if (body is List) {
          _menuItems.removeWhere((m) => m.restaurantId == restaurantId);
          _menuItems.addAll(body
              .whereType<Map>()
              .map((e) => _parseMenuItem(Map<String, dynamic>.from(e))));
        }
      }

      final reviewResponse = await http
          .get(Uri.parse('$_apiBaseUrl/restaurants/$restaurantId/reviews'));
      if (reviewResponse.statusCode == 200) {
        final body = jsonDecode(reviewResponse.body);
        if (body is List) {
          _reviews.removeWhere((r) => r.restaurantId == restaurantId);
          _reviews.addAll(body
              .whereType<Map>()
              .map((e) => _parseReview(Map<String, dynamic>.from(e))));
        }
      }

      if (notify) notifyListeners();
    } catch (_) {}
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required bool isOwner,
    String address = '',
    String phone = '',
  }) async {
    final trimEmail = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'Name cannot be empty.';
    if (trimEmail.isEmpty) return 'Email cannot be empty.';
    if (password.length < 6) return 'Password must be at least 6 characters.';

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': trimEmail,
          'password': password,
          'isOwner': isOwner,
          'address': address.trim(),
          'phone': phone.trim(),
        }),
      );

      if (response.statusCode != 201) return _responseError(response);

      final body = jsonDecode(response.body);
      final userJson = Map<String, dynamic>.from(body['user']);
      _currentUser = _parseUser(userJson, password);
      _users.removeWhere((u) => u.id == _currentUser!.id);
      _users.add(_currentUser!);

      await loadRestaurants();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Cannot connect to server. Make sure Flask API is running.';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
    required bool isOwner,
  }) async {
    final trimEmail = email.trim().toLowerCase();
    if (trimEmail.isEmpty) return 'Email cannot be empty.';
    if (password.isEmpty) return 'Password cannot be empty.';

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': trimEmail,
          'password': password,
          'isOwner': isOwner,
        }),
      );

      if (response.statusCode != 200) return _responseError(response);

      final body = jsonDecode(response.body);
      final userJson = Map<String, dynamic>.from(body['user']);
      _currentUser = _parseUser(userJson, password);
      _users.removeWhere((u) => u.id == _currentUser!.id);
      _users.add(_currentUser!);

      await loadRestaurants();
      if (_currentUser!.restaurantId != null) {
        await loadRestaurantDetails(_currentUser!.restaurantId!);
      }
      notifyListeners();
      return null;
    } catch (e) {
      return 'Cannot connect to server. Make sure Flask API is running.';
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

    if (_currentUser!.isOwner) {
      final idx =
          _restaurants.indexWhere((r) => r.id == _currentUser!.restaurantId);
      if (idx != -1) _restaurants[idx].name = name.trim();
    }
    notifyListeners();
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  Future<void> addMenuItem({
    required String restaurantId,
    required String name,
    required String price,
    required String description,
    Uint8List? imageBytes,
  }) async {
    String id = 'm_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/menu-items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'restaurantId': restaurantId,
          'name': name.trim(),
          'price': price.trim(),
          'description': description.trim(),
        }),
      );
      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        id = body['id']?.toString() ?? id;
      }
    } catch (_) {}

    _menuItems.add(MenuItem(
      id: id,
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

  Future<String> _predictSentimentWithModel(String text) async {
    final uri = Uri.parse(_sentimentApiUrl);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'reviews': [text]}),
    );

    if (response.statusCode != 200) {
      throw Exception('Sentiment API error: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is List && body.isNotEmpty && body[0]['sentiment'] != null) {
      return body[0]['sentiment'] as String;
    }
    throw Exception('Invalid sentiment API response');
  }

  Future<void> addReview({
    required String restaurantId,
    required int stars,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/reviews'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'restaurantId': restaurantId,
        'userId': _currentUser?.id,
        'customerName': _currentUser?.name ?? 'Guest',
        'stars': stars,
        'text': text.trim(),
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(_responseError(response));
    }

    final body = jsonDecode(response.body);
    final reviewJson = Map<String, dynamic>.from(body['review']);
    final review = _parseReview(reviewJson);

    _reviews.removeWhere((r) => r.id == review.id);
    _reviews.insert(0, review);

    await loadRestaurants();
    await loadRestaurantDetails(restaurantId);
    notifyListeners();
  }
}
