import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/admin_models.dart';
import '../../core/theme.dart';

final NumberFormat _pkr = NumberFormat.decimalPattern('en_US');

String formatPkr(num v) => 'Rs. ${_pkr.format(v)}';

String formatDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy').format(d);

String formatDateTime(DateTime? d) =>
    d == null ? '—' : DateFormat('d MMM yyyy, h:mm a').format(d);

/// Headline number with a label (and optional sub-line).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Single-series bar chart: one hue, thin rounded bars, 2px gaps,
/// recessive axis labels, exact value in a tooltip on hover / tap.
class SimpleBarChart extends StatelessWidget {
  final String title;
  final List<ChartPoint> points;
  final String Function(ChartPoint) tooltip;
  final String Function(String label) axisLabel;
  final String Function(double max) maxLabel;
  final double height;

  const SimpleBarChart({
    super.key,
    required this.title,
    required this.points,
    required this.tooltip,
    required this.axisLabel,
    required this.maxLabel,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = points.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    final muted = TextStyle(fontSize: 11, color: Colors.grey.shade600);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Text('max ${maxLabel(maxV)}', style: muted),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: height,
              child: points.isEmpty
                  ? Center(child: Text('No data yet', style: muted))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final p in points)
                          Expanded(
                            child: Tooltip(
                              message: tooltip(p),
                              triggerMode: TooltipTriggerMode.tap,
                              waitDuration: Duration.zero,
                              child: Container(
                                // Full-height hit target, bar drawn at the bottom.
                                color: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: maxV == 0
                                      ? 0.02
                                      : (p.value / maxV).clamp(0.02, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: p.value == 0
                                          ? Colors.grey.shade300
                                          : AppTheme.primaryTeal,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 4),
            if (points.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(axisLabel(points.first.label), style: muted),
                  Text(axisLabel(points.last.label), style: muted),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Plan / state badge — always icon + text, never colour alone.
class StatusBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const StatusBadge({super.key, required this.text, required this.icon, required this.color});

  factory StatusBadge.plan(AdminUser u) => u.isPremium
      ? const StatusBadge(text: 'Premium', icon: Icons.star, color: Color(0xFFB8860B))
      : StatusBadge(text: 'Free', icon: Icons.person_outline, color: Colors.grey.shade700);

  factory StatusBadge.disabled() =>
      const StatusBadge(text: 'Blocked', icon: Icons.block, color: AppTheme.spoiledRed);

  factory StatusBadge.admin() => const StatusBadge(
      text: 'Admin', icon: Icons.admin_panel_settings, color: AppTheme.primaryDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final AdminUser user;
  final double radius;
  const UserAvatar({super.key, required this.user, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
      foregroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
          ? NetworkImage(user.photoUrl!)
          : null,
      child: Text(initial,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.8,
              color: AppTheme.primaryDark)),
    );
  }
}
