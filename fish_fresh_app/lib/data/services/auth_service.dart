import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../ui/core/constants.dart';

class AuthService {
  final String baseUrl = AppConstants.defaultApiUrl;

  Future<Map<String, dynamic>> registerUser(String email, String password, String name) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/register');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        return {'success': false, 'error': body['detail'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        return {'success': false, 'error': body['detail'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
