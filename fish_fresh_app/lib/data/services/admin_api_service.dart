import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/core/constants.dart';
import '../models/admin_models.dart';

class AdminApiException implements Exception {
  final String message;
  final int? statusCode;
  AdminApiException(this.message, [this.statusCode]);
  bool get isAuthError => statusCode == 401;
  @override
  String toString() => message;
}

/// Talks to /api/admin/* with the admin's bearer token (kept for 12h).
class AdminApiService {
  AdminApiService._();
  static final AdminApiService instance = AdminApiService._();

  static const _tokenKey = 'admin_token';
  static const _emailKey = 'admin_email';
  static const _nameKey = 'admin_name';

  final String _base = AppConstants.defaultApiUrl;
  String? _token;
  String adminEmail = '';
  String adminName = '';

  bool get isLoggedIn => _token != null;

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    adminEmail = prefs.getString(_emailKey) ?? '';
    adminName = prefs.getString(_nameKey) ?? '';
    if (_token == null) return false;
    try {
      await _get('/api/admin/me');
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> _saveSession(Map<String, dynamic> res) async {
    _token = res['token'];
    adminEmail = res['email'] ?? '';
    adminName = res['name'] ?? 'Admin';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_emailKey, adminEmail);
    await prefs.setString(_nameKey, adminName);
  }

  Future<void> logout() async {
    _token = null;
    adminEmail = '';
    adminName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  dynamic _decode(http.Response r) {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return body ?? {};
    throw AdminApiException(
      '${body?['detail'] ?? 'Request failed (HTTP ${r.statusCode})'}',
      r.statusCode,
    );
  }

  Future<dynamic> _send(Future<http.Response> req) async {
    try {
      return _decode(await req.timeout(const Duration(seconds: 60)));
    } on AdminApiException {
      rethrow;
    } catch (e) {
      throw AdminApiException('Connection error: $e');
    }
  }

  Future<dynamic> _get(String path) =>
      _send(http.get(Uri.parse('$_base$path'), headers: _headers));

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) => _send(
      http.post(Uri.parse('$_base$path'), headers: _headers, body: jsonEncode(body ?? {})));

  // ---------- auth ----------

  Future<void> loginWithPassword(String email, String password) async {
    final res = await _post('/api/admin/login', {'email': email.trim(), 'password': password});
    await _saveSession(res);
  }

  Future<void> loginWithGoogle(String idToken) async {
    final res = await _post('/api/admin/google', {'id_token': idToken});
    await _saveSession(res);
  }

  // ---------- data ----------

  Future<AdminStats> fetchStats() async => AdminStats.fromJson(await _get('/api/admin/stats'));

  Future<List<AdminUser>> fetchUsers() async {
    final res = await _get('/api/admin/users');
    return [for (final u in res['users'] as List) AdminUser.fromJson(u)];
  }

  Future<AdminUserDetail> fetchUser(String userId) async =>
      AdminUserDetail.fromJson(await _get('/api/admin/users/$userId'));

  Future<List<AdminPayment>> fetchPayments() async {
    final res = await _get('/api/admin/payments');
    return [for (final p in res['payments'] as List) AdminPayment.fromJson(p)];
  }

  // ---------- actions ----------

  Future<void> grantPremium(String userId, int days) =>
      _post('/api/admin/users/$userId/premium', {'days': days});

  Future<void> revokePremium(String userId) => _post('/api/admin/users/$userId/revoke');

  Future<void> setDisabled(String userId, bool disabled) =>
      _post('/api/admin/users/$userId/disable', {'disabled': disabled});

  Future<void> deleteUser(String userId) =>
      _send(http.delete(Uri.parse('$_base/api/admin/users/$userId'), headers: _headers));
}
