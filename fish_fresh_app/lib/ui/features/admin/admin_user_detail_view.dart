import 'package:flutter/material.dart';

import '../../../data/models/admin_models.dart';
import '../../../data/models/scan_result.dart';
import '../../../data/services/admin_api_service.dart';
import '../../core/theme.dart';
import 'admin_widgets.dart';

/// One user's profile, subscription, payments and full scan history,
/// with admin actions (grant / extend / revoke Premium, block, delete).
class AdminUserDetailView extends StatefulWidget {
  final String userId;
  const AdminUserDetailView({super.key, required this.userId});

  @override
  State<AdminUserDetailView> createState() => _AdminUserDetailViewState();
}

class _AdminUserDetailViewState extends State<AdminUserDetailView> {
  final _api = AdminApiService.instance;
  AdminUserDetail? _detail;
  String? _error;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _api.fetchUser(widget.userId);
      if (mounted) setState(() => _detail = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      await _load();
      _toast(done);
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.spoiledRed : null,
    ));
  }

  Future<bool> _confirm(String title, String body, String action, {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: AppTheme.spoiledRed) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _grantPremium(AdminUser u) async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(u.isPremium ? 'Extend Premium' : 'Give Premium'),
        children: [
          for (final d in const [7, 30, 90, 365])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(d == 365 ? '1 year' : '$d days'),
              ),
            ),
        ],
      ),
    );
    if (days == null) return;
    await _run(() => _api.grantPremium(u.userId, days),
        'Premium ${u.isPremium ? 'extended' : 'granted'} for $days days (no charge).');
  }

  Future<void> _revoke(AdminUser u) async {
    if (!await _confirm('Remove Premium?',
        '${u.name} will be moved to the Free plan immediately.', 'Remove')) {
      return;
    }
    await _run(() => _api.revokePremium(u.userId), 'Moved to Free plan.');
  }

  Future<void> _toggleBlock(AdminUser u) async {
    if (!u.disabled &&
        !await _confirm('Block this user?',
            '${u.name} will not be able to log in until unblocked.', 'Block',
            danger: true)) {
      return;
    }
    await _run(() => _api.setDisabled(u.userId, !u.disabled),
        u.disabled ? 'User unblocked.' : 'User blocked.');
  }

  Future<void> _delete(AdminUser u) async {
    if (!await _confirm(
        'Delete user permanently?',
        'This deletes ${u.email} and all ${u.scanCount} scans. '
            'Payment records are kept. This cannot be undone.',
        'Delete',
        danger: true)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.deleteUser(u.userId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast('$e', error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          title: Text(_detail?.user.name ?? 'User'),
          backgroundColor: AppTheme.primaryDark,
          foregroundColor: Colors.white,
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3))
              : null,
        ),
        body: _detail == null
            ? Center(
                child: _error != null
                    ? Text(_error!, textAlign: TextAlign.center)
                    : const CircularProgressIndicator())
            : RefreshIndicator(onRefresh: _load, child: _body(_detail!)),
      ),
    );
  }

  Widget _body(AdminUserDetail d) {
    final u = d.user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          Column(
            children: [
              Row(
                children: [
                  UserAvatar(user: u, radius: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        SelectableText(u.email,
                            style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 4, runSpacing: 4, children: [
                          StatusBadge.plan(u),
                          if (u.isAdmin) StatusBadge.admin(),
                          if (u.disabled) StatusBadge.disabled(),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _info('Signed up with', u.isGoogle ? 'Google' : 'Email & password'),
              _info('Joined', formatDateTime(u.createdAt)),
              _info('Last login', formatDateTime(u.lastLogin)),
              _info('Total scans', '${u.scanCount}'),
              _info('Total paid', formatPkr(u.totalPaidPkr)),
              _info('User ID', u.userId, selectable: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _subscriptionCard(u),
        const SizedBox(height: 12),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Account actions', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy || u.isAdmin ? null : () => _toggleBlock(u),
                    icon: Icon(u.disabled ? Icons.lock_open : Icons.block),
                    label: Text(u.disabled ? 'Unblock user' : 'Block user'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.spoiledRed),
                    onPressed: _busy || u.isAdmin ? null : () => _delete(u),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete user'),
                  ),
                ],
              ),
              if (u.isAdmin)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Admin accounts cannot be blocked or deleted here.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (d.payments.isNotEmpty) ...[
          _heading('Payments (${d.payments.length})'),
          _card(Column(children: [
            for (final p in d.payments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    p.grantedBy != null ? Icons.card_giftcard : Icons.payments_outlined,
                    color: AppTheme.primaryDark),
                title: Text('${formatPkr(p.amountPkr)} · ${p.paymentMethod}'),
                subtitle: Text('${p.days} days · ${formatDateTime(p.createdAt)}'
                    '${p.grantedBy != null ? ' · by ${p.grantedBy}' : ''}'),
              ),
          ])),
          const SizedBox(height: 12),
        ],
        _heading('Scan history (${d.scans.length})'),
        if (d.scans.isEmpty)
          _card(const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: Text('This user has no scans yet.')),
          ))
        else
          for (final s in d.scans) _scanTile(s),
      ],
    );
  }

  Widget _subscriptionCard(AdminUser u) {
    final days = u.daysRemaining;
    double? progress;
    if (u.isPremium && u.planStartedAt != null && u.planExpiresAt != null) {
      final total = u.planExpiresAt!.difference(u.planStartedAt!).inSeconds;
      final left = u.planExpiresAt!.difference(DateTime.now()).inSeconds;
      if (total > 0) progress = (left / total).clamp(0.0, 1.0);
    }
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (u.isPremium) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(days == null ? '∞' : '$days',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(days == null ? 'no expiry set' : 'days left on monthly bill',
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: (days ?? 99) <= 7 ? AppTheme.warningOrange : AppTheme.primaryTeal,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _info('Started', formatDate(u.planStartedAt)),
            _info('Expires', formatDateTime(u.planExpiresAt)),
          ] else
            Text('Free plan — no active subscription.',
                style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _grantPremium(u),
                icon: const Icon(Icons.star),
                label: Text(u.isPremium ? 'Extend Premium' : 'Give Premium'),
              ),
              if (u.isPremium)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _revoke(u),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Move to Free'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanTile(ScanResponse s) {
    final fresh = s.freshness?.isFresh ?? false;
    final name = s.isFish
        ? (s.species?.displayName ?? 'Unknown fish')
        : 'Rejected (not a fish)';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: !s.isFish
              ? Colors.grey.shade400
              : fresh
                  ? AppTheme.freshGreen
                  : AppTheme.spoiledRed,
          child: Icon(!s.isFish ? Icons.block : (fresh ? Icons.check : Icons.warning),
              color: Colors.white, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          s.isFish
              ? '${fresh ? 'Fresh' : 'Spoiled'} · ${s.freshness?.confidencePercent.toStringAsFixed(1) ?? '-'}% · '
                  '${s.freshness?.qualityGrade ?? ''}'
              : (s.rejectionReason ?? ''),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(formatDateTime(s.scannedAt),
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ),
    );
  }

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _card(Widget child) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _info(String label, String value, {bool selectable = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
            Expanded(
              child: selectable
                  ? SelectableText(value, style: const TextStyle(fontSize: 13))
                  : Text(value, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}
