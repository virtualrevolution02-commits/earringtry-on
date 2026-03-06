import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/earring_model.dart';

/// HTTP service for communicating with the Node.js backend.
class ApiService {
  // Update this URL to your deployed backend. For local dev use localhost.
  static const String _baseUrl = 'http://localhost:5000/api';

  /// GET /api/earrings
  Future<List<EarringModel>> getEarrings() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/earrings'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => EarringModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load earrings: ${response.statusCode}');
    }
  }

  /// POST /api/wishlist
  Future<void> addToWishlist(String earringId) async {
    await http
        .post(
          Uri.parse('$_baseUrl/wishlist'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'earringId': earringId}),
        )
        .timeout(const Duration(seconds: 5));
  }

  /// POST /api/analytics
  Future<void> trackTryOn(String earringId) async {
    await http
        .post(
          Uri.parse('$_baseUrl/analytics'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'earringId': earringId,
            'event': 'tryon',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 5));
  }
}
