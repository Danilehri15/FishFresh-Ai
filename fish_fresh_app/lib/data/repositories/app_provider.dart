import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';
import 'package:geolocator/geolocator.dart';
import '../models/market_price_model.dart';
import '../models/chat_message.dart';
import '../models/subscription_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AppStateProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  ScanResponse? _latestScan;
  ScanResponse? get latestScan => _latestScan;

  List<ScanResponse> _scanHistory = [];
  List<ScanResponse> get scanHistory => List.unmodifiable(_scanHistory);

  List<MarketPriceItem> _marketPrices = [];
  List<MarketPriceItem> get marketPrices => _marketPrices;

  UserSubscription? _subscription;
  UserSubscription? get subscription => _subscription;

  final List<ChatMessage> _chatMessages = [
    ChatMessage(
      text:
          "Hello! I am your AI Fishery & Culinary Assistant. Ask me about seasonal fishing bans in Pakistan, fish preservation, cooking recipes, or your scan results.",
      isUser: false,
    ),
  ];
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);

  bool _isChatLoading = false;
  bool get isChatLoading => _isChatLoading;

  String _userId = '';
  String get userId => _userId;

  String _userName = '';
  String get userName => _userName;

  String _userEmail = '';
  String get userEmail => _userEmail;

  String? _userPhotoUrl;
  String? get userPhotoUrl => _userPhotoUrl;

  String _authProvider = '';
  String get authProvider => _authProvider;

  bool get isLoggedIn => _userId.isNotEmpty;
  bool get isGoogleUser => _authProvider == 'google';

  Timer? _keepAliveTimer;

  AppStateProvider() {
    _restoreSavedUserSession();
    _startKeepAlive();
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    // Immediate ping to wake server if cold
    _apiService.pingServer();
    // Ping every 10 minutes to prevent Render from sleeping
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _apiService.pingServer();
    });
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreSavedUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('saved_user_id') ?? '';
      if (savedId.isNotEmpty) {
        _userId = savedId;
        _userName = prefs.getString('saved_user_name') ?? '';
        _userEmail = prefs.getString('saved_user_email') ?? '';
        _userPhotoUrl = prefs.getString('saved_user_photo_url');
        _authProvider = prefs.getString('saved_auth_provider') ?? '';
        _apiService.setUserId(_userId);
      }
    } catch (_) {}
    await refreshData();
  }

  Future<void> _persistUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_user_id', _userId);
      await prefs.setString('saved_user_name', _userName);
      await prefs.setString('saved_user_email', _userEmail);
      if (_userPhotoUrl != null) {
        await prefs.setString('saved_user_photo_url', _userPhotoUrl!);
      } else {
        await prefs.remove('saved_user_photo_url');
      }
      await prefs.setString('saved_auth_provider', _authProvider);
    } catch (_) {}
  }

  Future<String?> register(String email, String password, String name) async {
    final res = await _authService.registerUser(email, password, name);
    if (res['success'] == true) {
      _userId = res['user_id'] ?? '';
      _userName = res['name'] ?? name;
      _userEmail = res['email'] ?? email;
      _authProvider = 'email';
      _userPhotoUrl = null;
      _apiService.setUserId(_userId);
      await _persistUserSession();
      await refreshData();
      return null;
    }
    return res['error'];
  }

  Future<String?> login(String email, String password) async {
    final res = await _authService.loginUser(email, password);
    if (res['success'] == true) {
      _userId = res['user_id'] ?? '';
      _userName = res['name'] ?? 'User';
      _userEmail = res['email'] ?? email;
      _authProvider = res['auth_provider'] ?? 'email';
      _userPhotoUrl = res['photo_url'];
      _apiService.setUserId(_userId);
      await _persistUserSession();
      await refreshData();
      return null;
    }
    return res['error'];
  }

  Future<String?> loginWithGoogle({
    required String email,
    String? name,
    String? googleId,
    String? photoUrl,
    String? idToken,
  }) async {
    final res = await _authService.loginWithGoogle(
      email: email,
      name: name,
      googleId: googleId,
      photoUrl: photoUrl,
      idToken: idToken,
    );
    if (res['success'] == true) {
      _userId = res['user_id'] ?? '';
      _userName = res['name'] ?? email.split('@')[0];
      _userEmail = res['email'] ?? email;
      _userPhotoUrl = res['photo_url'];
      _authProvider = 'google';
      _apiService.setUserId(_userId);
      await _persistUserSession();
      await refreshData();
      return null;
    }
    return res['error'] ?? 'Google sign-in failed';
  }

  Future<void> logout() async {
    _userId = '';
    _userName = '';
    _userEmail = '';
    _userPhotoUrl = null;
    _authProvider = '';
    _apiService.setUserId('default_user');
    _scanHistory = [];
    _subscription = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_user_id');
      await prefs.remove('saved_user_name');
      await prefs.remove('saved_user_email');
      await prefs.remove('saved_user_photo_url');
      await prefs.remove('saved_auth_provider');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> upgradeToPremium() async {
    final targetUserId = _userId.isNotEmpty ? _userId : 'default_user';
    await _apiService.upgradeToPremium('GooglePay', userId: targetUserId);
    await refreshData();
  }

  Future<void> refreshData() async {
    final targetUserId = _userId.isNotEmpty ? _userId : 'default_user';
    _marketPrices = await _apiService.fetchMarketPrices();
    _subscription = await _apiService.fetchSubscriptionStatus(
      userId: targetUserId,
    );
    _scanHistory = await _apiService.fetchUserScans(userId: targetUserId);
    notifyListeners();
  }

  Future<ScanResponse?> scanFishImage(Uint8List bytes, String filename) async {
    _isScanning = true;
    notifyListeners();

    try {
      final res = await _apiService.uploadAndPredict(
        bytes,
        filename,
        userId: _userId.isNotEmpty ? _userId : 'default_user',
      );
      _latestScan = res;
      if (res.isFish && res.status == 'SUCCESS') {
        _scanHistory.insert(0, res);
        try {
          LocationPermission perm = await Geolocator.checkPermission();
          if (perm == LocationPermission.denied) {
            perm = await Geolocator.requestPermission();
          }
          if (perm == LocationPermission.denied ||
              perm == LocationPermission.deniedForever)
            return res;
          final pos = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 5),
          );
          await _apiService.recordScanLocation(
            latitude: pos.latitude,
            longitude: pos.longitude,
            species: res.species?.predictedSpecies ?? 'Unknown',
            freshnessScore: res.freshness?.freshnessProbability ?? 0.0,
            isFresh: (res.freshness?.freshnessProbability ?? 0.0) >= 0.5,
            userId: _userId.isNotEmpty ? _userId : 'default_user',
          );
        } catch (_) {}
      }
      await refreshData(); // update quota
      return res;
    } catch (e) {
      rethrow;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> sendChat(String query) async {
    if (query.trim().isEmpty) return;
    _chatMessages.add(ChatMessage(text: query, isUser: true));
    _isChatLoading = true;
    notifyListeners();

    final speciesId = _latestScan?.species?.predictedSpecies;
    final res = await _apiService.sendChatMessage(query, speciesId: speciesId);

    _chatMessages.add(
      ChatMessage(
        text: res['reply'] ?? 'No response received.',
        isUser: false,
        category: res['category'],
      ),
    );
    _isChatLoading = false;
    notifyListeners();
  }

  Future<bool> upgradeTier(String paymentMethod) async {
    final ok = await _apiService.upgradeToPremium(
      paymentMethod,
      userId: _userId.isNotEmpty ? _userId : 'default_user',
    );
    if (ok) {
      await refreshData();
    }
    return ok;
  }

  Future<Map<String, dynamic>> checkPrice(
    String speciesId,
    double price,
    String city,
  ) {
    return _apiService.checkFairPrice(speciesId, price, city);
  }
}
