import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  bool get isLoggedIn => _userId.isNotEmpty;

  Future<String?> register(String email, String password, String name) async {
    final res = await _authService.registerUser(email, password, name);
    if (res['success'] == true) {
      _userId = res['user_id'];
      _userName = res['name'];
      _apiService.setUserId(_userId);
      await refreshData();
      return null;
    }
    return res['error'];
  }

  Future<String?> login(String email, String password) async {
    final res = await _authService.loginUser(email, password);
    if (res['success'] == true) {
      _userId = res['user_id'];
      _userName = res['name'];
      _apiService.setUserId(_userId);
      await refreshData();
      return null;
    }
    return res['error'];
  }

  void logout() {
    _userId = '';
    _userName = '';
    _apiService.setUserId('default_user');
    _scanHistory = [];
    _subscription = null;
    notifyListeners();
  }

  Future<void> upgradeToPremium() async {
    final targetUserId = _userId.isNotEmpty ? _userId : 'default_user';
    await _apiService.upgradeToPremium('GooglePay', userId: targetUserId);
    await refreshData();
  }

  AppStateProvider() {
    refreshData();
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
          if (perm == LocationPermission.denied) { perm = await Geolocator.requestPermission(); }
          if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return res;
          final pos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 5));
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



