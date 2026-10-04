class UserSubscription {
  final String userId;
  final String tier;
  final bool isPremium;
  final dynamic dailyLimit;
  final int scansUsedToday;
  final dynamic scansRemainingToday;
  final List<String> features;

  UserSubscription({
    required this.userId,
    required this.tier,
    required this.isPremium,
    required this.dailyLimit,
    required this.scansUsedToday,
    required this.scansRemainingToday,
    required this.features,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['user_id'] ?? 'default_user',
      tier: json['tier'] ?? 'FREE',
      isPremium: json['is_premium'] ?? false,
      dailyLimit: json['daily_limit'] ?? 5,
      scansUsedToday: json['scans_used_today'] ?? 0,
      scansRemainingToday: json['scans_remaining_today'] ?? 20,
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

