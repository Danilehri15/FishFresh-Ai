import 'dart:convert';
import 'dart:typed_data';
import '../models/heatmap_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/scan_result.dart';
import '../models/market_price_model.dart';
import '../models/subscription_model.dart';
import '../../ui/core/constants.dart';

class ApiService {
  String baseUrl = kIsWeb ? AppConstants.webApiUrl : AppConstants.defaultApiUrl;
  String _currentUserId = 'default_user';

  void setUserId(String userId) {
    _currentUserId = userId;
  }

  void setBaseUrl(String url) {
    baseUrl = url;
  }

  Future<ScanResponse> uploadAndPredict(
    Uint8List imageBytes,
    String filename, {
    String userId = 'default_user',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/predict');
      final request = http.MultipartRequest('POST', uri);
      request.fields['user_id'] = userId;
      
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 25),
      );
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final json = jsonDecode(responseBody);
        return ScanResponse.fromJson(json);
      } else if (streamedResponse.statusCode == 429) {
        throw Exception(
          'Daily free scan limit reached (20 scans/day). Resets at 12 AM.',
        );
      } else {
        throw Exception(
          'Server returned error: ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MarketPriceItem>> fetchMarketPrices() async {
    try {
      final uri = Uri.parse('$baseUrl/api/market-prices');
      final response = await http.get(uri, headers: {}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['data'] as List<dynamic>;
        return list.map((e) => MarketPriceItem.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> sendChatMessage(
    String query, {
    String? speciesId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/chat');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', },
            body: jsonEncode({'query': query, 'current_species': speciesId}),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'reply': 'Unable to connect to AI Fishery Assistant.',
        'category': 'error',
      };
    } catch (e) {
      return {
        'reply':
            'Network connection issue. Please ensure the backend is running.',
        'category': 'error',
      };
    }
  }

  Future<UserSubscription> fetchSubscriptionStatus({
    String userId = 'default_user',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/subscription/status?user_id=$userId');
      final response = await http.get(uri, headers: {}).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return UserSubscription.fromJson(jsonDecode(response.body));
      }
      return UserSubscription(
        userId: userId,
        tier: 'FREE',
        isPremium: false,
        dailyLimit: 5,
        scansUsedToday: 0,
        scansRemainingToday: 20,
        features: [],
      );
    } catch (e) {
      return UserSubscription(
        userId: userId,
        tier: 'FREE',
        isPremium: false,
        dailyLimit: 5,
        scansUsedToday: 0,
        scansRemainingToday: 20,
        features: [],
      );
    }
  }

  Future<bool> upgradeToPremium(
    String paymentMethod, {
    String userId = 'default_user',
    int amount = 999,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/subscription/upgrade');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', },
        body: jsonEncode({
          'user_id': userId,
          'payment_method': paymentMethod,
          'amount_pkr': amount,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<ScanResponse>> fetchUserScans({
    String userId = 'default_user',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/user/scans?user_id=$userId');
      final response = await http.get(uri, headers: {}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['scans'] as List<dynamic>;
        return list.map((e) => ScanResponse.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> checkFairPrice(
    String speciesId,
    double price,
    String city,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api/market-prices/check');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', },
        body: jsonEncode({
          'species_id': speciesId,
          'asking_price_pkr': price,
          'city': city,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Fetch heatmap data for market areas
  Future<List<MarketHeatmapPoint>> fetchHeatmapData({
    String city = 'all',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/heatmap?city=$city');
      final response = await http.get(uri, headers: {}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['markets'] as List<dynamic>;
        return list.map((e) => MarketHeatmapPoint.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch recommended markets
  Future<List<MarketHeatmapPoint>> fetchRecommendedMarkets({
    String city = 'all',
    int topN = 5,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/recommended-markets?city=$city&top_n=$topN',
      );
      final response = await http.get(uri, headers: {}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['recommended_markets'] as List<dynamic>;
        return list.map((e) => MarketHeatmapPoint.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch markets to avoid
  Future<List<MarketHeatmapPoint>> fetchAvoidMarkets({
    String city = 'all',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/avoid-markets?city=$city');
      final response = await http.get(uri, headers: {}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['avoid_markets'] as List<dynamic>;
        return list.map((e) => MarketHeatmapPoint.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Record a scan location for heatmap
  Future<bool> recordScanLocation({
    required double latitude,
    required double longitude,
    required String species,
    required double freshnessScore,
    required bool isFresh,
    String userId = 'default_user',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/scan-location');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'species': species,
          'freshness_score': freshnessScore,
          'is_fresh': isFresh,
          'user_id': userId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> registerUser(
    String email,
    String password,
    String name,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/register');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', },
            body: jsonEncode({
              'email': email,
              'password': password,
              'name': name,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['detail']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['detail']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error'};
    }
  }
}






