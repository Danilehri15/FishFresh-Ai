import 'scan_result.dart';

DateTime? _date(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

class AdminUser {
  final String userId;
  final String name;
  final String email;
  final String? photoUrl;
  final String plan;
  final String authProvider;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final DateTime? planStartedAt;
  final DateTime? planExpiresAt;
  final int? daysRemaining;
  final int scanCount;
  final int totalPaidPkr;
  final bool disabled;
  final bool isAdmin;

  AdminUser.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] ?? '',
        name = j['name'] ?? 'User',
        email = j['email'] ?? '',
        photoUrl = j['photo_url'],
        plan = j['plan'] ?? 'FREE',
        authProvider = j['auth_provider'] ?? 'email',
        createdAt = _date(j['created_at']),
        lastLogin = _date(j['last_login']),
        planStartedAt = _date(j['plan_started_at']),
        planExpiresAt = _date(j['plan_expires_at']),
        daysRemaining = j['days_remaining'] == null ? null : _int(j['days_remaining']),
        scanCount = _int(j['scan_count']),
        totalPaidPkr = _int(j['total_paid_pkr']),
        disabled = j['disabled'] == true,
        isAdmin = j['is_admin'] == true;

  bool get isPremium => plan == 'PREMIUM';
  bool get isGoogle => authProvider == 'google';
}

class AdminPayment {
  final String transactionId;
  final String userId;
  final String email;
  final String name;
  final int amountPkr;
  final String paymentMethod;
  final int days;
  final String? grantedBy;
  final DateTime? createdAt;

  AdminPayment.fromJson(Map<String, dynamic> j)
      : transactionId = j['transaction_id'] ?? '',
        userId = j['user_id'] ?? '',
        email = j['email'] ?? '',
        name = j['name'] ?? '',
        amountPkr = _int(j['amount_pkr']),
        paymentMethod = j['payment_method'] ?? '-',
        days = _int(j['days']),
        grantedBy = j['granted_by'],
        createdAt = _date(j['created_at']);
}

class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);
}

class AdminStats {
  final int totalUsers, premiumUsers, freeUsers, googleUsers, emailUsers, disabledUsers;
  final int newUsers7d, activeUsers7d;
  final int totalRevenuePkr, revenueThisMonthPkr, projectedMonthlyRevenuePkr, totalPayments;
  final int totalScans, scansToday, scans7d, freshScans, spoiledScans;
  final List<ChartPoint> topSpecies;
  final List<ChartPoint> signupsLast14Days;
  final List<ChartPoint> revenueLast6Months;
  final List<Map<String, dynamic>> expiringSoon;

  AdminStats.fromJson(Map<String, dynamic> j)
      : totalUsers = _int(j['total_users']),
        premiumUsers = _int(j['premium_users']),
        freeUsers = _int(j['free_users']),
        googleUsers = _int(j['google_users']),
        emailUsers = _int(j['email_users']),
        disabledUsers = _int(j['disabled_users']),
        newUsers7d = _int(j['new_users_7d']),
        activeUsers7d = _int(j['active_users_7d']),
        totalRevenuePkr = _int(j['total_revenue_pkr']),
        revenueThisMonthPkr = _int(j['revenue_this_month_pkr']),
        projectedMonthlyRevenuePkr = _int(j['projected_monthly_revenue_pkr']),
        totalPayments = _int(j['total_payments']),
        totalScans = _int(j['total_scans']),
        scansToday = _int(j['scans_today']),
        scans7d = _int(j['scans_7d']),
        freshScans = _int(j['fresh_scans']),
        spoiledScans = _int(j['spoiled_scans']),
        topSpecies = [
          for (final s in (j['top_species'] as List? ?? []))
            ChartPoint('${s['species']}', _int(s['count']).toDouble())
        ],
        signupsLast14Days = [
          for (final s in (j['signups_last_14_days'] as List? ?? []))
            ChartPoint('${s['date']}', _int(s['count']).toDouble())
        ],
        revenueLast6Months = [
          for (final s in (j['revenue_last_6_months'] as List? ?? []))
            ChartPoint('${s['month']}', _int(s['amount_pkr']).toDouble())
        ],
        expiringSoon = [
          for (final e in (j['expiring_soon'] as List? ?? [])) Map<String, dynamic>.from(e)
        ];
}

class AdminUserDetail {
  final AdminUser user;
  final List<ScanResponse> scans;
  final List<AdminPayment> payments;

  AdminUserDetail.fromJson(Map<String, dynamic> j)
      : user = AdminUser.fromJson(j['user']),
        scans = [
          for (final s in (j['scans'] as List? ?? []))
            ScanResponse.fromJson(Map<String, dynamic>.from(s))
        ],
        payments = [
          for (final p in (j['payments'] as List? ?? []))
            AdminPayment.fromJson(Map<String, dynamic>.from(p))
        ];
}
