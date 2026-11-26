import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/admin_models.dart';
import '../../../data/services/admin_api_service.dart';
import '../../../data/services/google_auth_service.dart';
import '../../core/theme.dart';
import 'admin_login_view.dart';
import 'admin_user_detail_view.dart';
import 'admin_widgets.dart';

enum _PlanFilter { all, premium, free, expiring, blocked }

enum _Sort { newest, name, mostScans, expirySoonest, lastActive }

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final _api = AdminApiService.instance;
  final _searchCtrl = TextEditingController();

  AdminStats? _stats;
  List<AdminUser> _users = [];
  List<AdminPayment> _payments = [];
  bool _loading = true;
  String? _error;
  _PlanFilter _filter = _PlanFilter.all;
  _Sort _sort = _Sort.newest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchStats(),
        _api.fetchUsers(),
        _api.fetchPayments(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _users = results[1] as List<AdminUser>;
        _payments = results[2] as List<AdminPayment>;
        _loading = false;
      });
    } on AdminApiException catch (e) {
      if (e.isAuthError) return _logout(message: e.message);
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout({String? message}) async {
    await _api.logout();
    await GoogleAuthService.signOut();
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginView()),
    );
  }

  Future<void> _openUser(String userId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminUserDetailView(userId: userId)),
    );
    if (changed == true) _load();
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Dashboard'),
              if (_api.adminEmail.isNotEmpty)
                Text(_api.adminEmail,
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          actions: [
            IconButton(
                tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
            IconButton(
                tooltip: 'Log out', icon: const Icon(Icons.logout), onPressed: _logout),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Payments'),
            ],
          ),
        ),
        body: _loading && _stats == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _stats == null
                ? _ErrorView(message: _error!, onRetry: _load)
                : TabBarView(
                    children: [_overviewTab(), _usersTab(), _paymentsTab()],
                  ),
      ),
    );
  }

  // ------------------------------- Overview ----------------------------------

  Widget _overviewTab() {
    final s = _stats!;
    final scanned = s.freshScans + s.spoiledScans;
    final freshPct = scanned == 0 ? 0 : (s.freshScans * 100 / scanned).round();
    final tiles = [
      StatTile(
          label: 'Total users',
          value: '${s.totalUsers}',
          icon: Icons.people,
          sub: '+${s.newUsers7d} new this week'),
      StatTile(
          label: 'Premium users',
          value: '${s.premiumUsers}',
          icon: Icons.star,
          sub: s.totalUsers == 0
              ? '—'
              : '${(s.premiumUsers * 100 / s.totalUsers).round()}% of users'),
      StatTile(
          label: 'Free users', value: '${s.freeUsers}', icon: Icons.person_outline),
      StatTile(
          label: 'Total revenue',
          value: formatPkr(s.totalRevenuePkr),
          icon: Icons.payments_outlined,
          sub: '${s.totalPayments} payments'),
      StatTile(
          label: 'Revenue this month',
          value: formatPkr(s.revenueThisMonthPkr),
          icon: Icons.calendar_month),
      StatTile(
          label: 'Expected monthly revenue',
          value: formatPkr(s.projectedMonthlyRevenuePkr),
          icon: Icons.trending_up,
          sub: 'active Premium × Rs. 999'),
      StatTile(
          label: 'Active users (7 days)',
          value: '${s.activeUsers7d}',
          icon: Icons.bolt,
          sub: '${s.googleUsers} Google · ${s.emailUsers} email'),
      StatTile(
          label: 'Total scans',
          value: '${s.totalScans}',
          icon: Icons.document_scanner_outlined,
          sub: '${s.scansToday} today · ${s.scans7d} this week'),
      StatTile(
          label: 'Fresh results',
          value: '$freshPct%',
          icon: Icons.verified_outlined,
          sub: '${s.freshScans} fresh · ${s.spoiledScans} spoiled'),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 560 ? 3 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: cols == 2 ? 1.45 : 1.7,
              children: tiles,
            );
          }),
          const SizedBox(height: 12),
          if (s.expiringSoon.isNotEmpty) ...[
            _sectionTitle('Premium expiring within 7 days', Icons.timer_outlined),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  for (final e in s.expiringSoon)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warningOrange),
                      title: Text('${e['name']}'),
                      subtitle: Text('${e['email']}'),
                      trailing: Text(
                        e['days_remaining'] == 0
                            ? 'expires today'
                            : '${e['days_remaining']} days left',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _openUser('${e['user_id']}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SimpleBarChart(
            title: 'New sign-ups · last 14 days',
            points: s.signupsLast14Days,
            tooltip: (p) =>
                '${DateFormat('EEE d MMM').format(DateTime.parse(p.label))}: ${p.value.toInt()} sign-ups',
            axisLabel: (l) => DateFormat('d MMM').format(DateTime.parse(l)),
            maxLabel: (m) => '${m.toInt()}/day',
          ),
          const SizedBox(height: 8),
          SimpleBarChart(
            title: 'Revenue · last 6 months',
            points: s.revenueLast6Months,
            tooltip: (p) =>
                '${DateFormat('MMMM yyyy').format(DateTime.parse('${p.label}-01'))}: ${formatPkr(p.value)}',
            axisLabel: (l) => DateFormat('MMM yy').format(DateTime.parse('$l-01')),
            maxLabel: (m) => formatPkr(m),
          ),
          const SizedBox(height: 12),
          if (s.topSpecies.isNotEmpty) ...[
            _sectionTitle('Most scanned species', Icons.set_meal_outlined),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    for (final sp in s.topSpecies) _speciesRow(sp, s.topSpecies.first.value),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _speciesRow(ChartPoint sp, double max) {
    final name = sp.label.replaceAll('_', ' ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              name.isEmpty ? '—' : name[0].toUpperCase() + name.substring(1),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : sp.value / max,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primaryTeal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text('${sp.value.toInt()}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      );

  // -------------------------------- Users ------------------------------------

  List<AdminUser> get _visibleUsers {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _users.where((u) {
      if (q.isNotEmpty &&
          !u.name.toLowerCase().contains(q) &&
          !u.email.toLowerCase().contains(q)) {
        return false;
      }
      switch (_filter) {
        case _PlanFilter.all:
          return true;
        case _PlanFilter.premium:
          return u.isPremium;
        case _PlanFilter.free:
          return !u.isPremium;
        case _PlanFilter.expiring:
          return u.isPremium && u.daysRemaining != null && u.daysRemaining! <= 7;
        case _PlanFilter.blocked:
          return u.disabled;
      }
    }).toList();

    int cmpDate(DateTime? a, DateTime? b) =>
        (b ?? DateTime(1970)).compareTo(a ?? DateTime(1970));
    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => cmpDate(a.createdAt, b.createdAt));
      case _Sort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.mostScans:
        list.sort((a, b) => b.scanCount.compareTo(a.scanCount));
      case _Sort.expirySoonest:
        list.sort((a, b) => (a.daysRemaining ?? 1 << 30).compareTo(b.daysRemaining ?? 1 << 30));
      case _Sort.lastActive:
        list.sort((a, b) => cmpDate(a.lastLogin, b.lastLogin));
    }
    return list;
  }

  Widget _usersTab() {
    final users = _visibleUsers;
    const filterLabels = {
      _PlanFilter.all: 'All',
      _PlanFilter.premium: 'Premium',
      _PlanFilter.free: 'Free',
      _PlanFilter.expiring: 'Expiring ≤7d',
      _PlanFilter.blocked: 'Blocked',
    };
    const sortLabels = {
      _Sort.newest: 'Newest',
      _Sort.name: 'Name',
      _Sort.mostScans: 'Most scans',
      _Sort.expirySoonest: 'Expiry soonest',
      _Sort.lastActive: 'Last active',
    };

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_searchCtrl.clear),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in _PlanFilter.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(filterLabels[f]!),
                                selected: _filter == f,
                                onSelected: (_) => setState(() => _filter = f),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<_Sort>(
                    tooltip: 'Sort',
                    initialValue: _sort,
                    onSelected: (s) => setState(() => _sort = s),
                    itemBuilder: (_) => [
                      for (final s in _Sort.values)
                        PopupMenuItem(value: s, child: Text(sortLabels[s]!)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.sort, size: 18),
                          const SizedBox(width: 4),
                          Text(sortLabels[_sort]!, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Showing ${users.length} of ${_users.length} users',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: users.isEmpty
                ? ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('No users match.')),
                    )
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _userCard(users[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _userCard(AdminUser u) {
    final subtitle = u.isPremium
        ? (u.daysRemaining != null
            ? 'Premium · ${u.daysRemaining} days left (until ${formatDate(u.planExpiresAt)})'
            : 'Premium · no expiry set')
        : 'Free plan';
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _openUser(u.userId),
        leading: UserAvatar(user: u),
        title: Row(
          children: [
            Flexible(
              child: Text(u.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            StatusBadge.plan(u),
            if (u.isAdmin) ...[const SizedBox(width: 4), StatusBadge.admin()],
            if (u.disabled) ...[const SizedBox(width: 4), StatusBadge.disabled()],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.email, overflow: TextOverflow.ellipsis),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: u.isPremium && (u.daysRemaining ?? 99) <= 7
                        ? AppTheme.warningOrange
                        : Colors.grey.shade600)),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${u.scanCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('scans', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ------------------------------- Payments ----------------------------------

  Widget _paymentsTab() {
    final total = _payments.fold<int>(0, (s, p) => s + p.amountPkr);
    return RefreshIndicator(
      onRefresh: _load,
      child: _payments.isEmpty
          ? ListView(children: const [
              Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No payments yet.')),
              )
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _payments.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: Text(
                      '${_payments.length} payments · ${formatPkr(total)} total',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  );
                }
                final p = _payments[i - 1];
                final isGrant = p.grantedBy != null;
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    onTap: p.userId.isEmpty ? null : () => _openUser(p.userId),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                      child: Icon(isGrant ? Icons.card_giftcard : Icons.payments_outlined,
                          color: AppTheme.primaryDark, size: 20),
                    ),
                    title: Text(p.name.isNotEmpty ? p.name : p.email),
                    subtitle: Text(
                      '${p.email}\n${p.paymentMethod} · ${p.days} days · ${formatDateTime(p.createdAt)}'
                      '${isGrant ? '\nGranted by ${p.grantedBy}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      formatPkr(p.amountPkr),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
