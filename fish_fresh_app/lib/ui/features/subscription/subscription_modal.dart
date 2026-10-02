import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/app_provider.dart';
import '../../core/theme.dart';

class SubscriptionModal extends StatefulWidget {
  const SubscriptionModal({super.key});

  @override
  State<SubscriptionModal> createState() => _SubscriptionModalState();
}

class _SubscriptionModalState extends State<SubscriptionModal> {
  String _selectedPayment = 'JazzCash';
  bool _isProcessing = false;

  Future<void> _processUpgrade() async {
    setState(() => _isProcessing = true);
    final state = context.read<AppStateProvider>();
    final ok = await state.upgradeTier(_selectedPayment);
    setState(() => _isProcessing = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? AppTheme.freshGreen : AppTheme.spoiledRed,
          content: Text(ok ? 'Successfully upgraded to Premium Access via $_selectedPayment!' : 'Upgrade failed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upgrade to Premium',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Unlock commercial features for market vendors and seafood lovers:'),
          const SizedBox(height: 14),

          _FeatureBullet('Unlimited AI Fish Scans per day (No quota limit)'),
          _FeatureBullet('Live Real-Time Market Price Alert Feeds'),
          _FeatureBullet('Export Quality Inspection Reports (PDF/CSV)'),
          _FeatureBullet('24/7 Unlimited AI Fishery Chatbot Access'),

          const SizedBox(height: 20),

          const Text('Select Payment Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),

          Row(
            children: [
              _PaymentOption(
                name: 'JazzCash',
                icon: Icons.account_balance_wallet,
                isSelected: _selectedPayment == 'JazzCash',
                onTap: () => setState(() => _selectedPayment = 'JazzCash'),
              ),
              const SizedBox(width: 8),
              _PaymentOption(
                name: 'SadaPay',
                icon: Icons.credit_card,
                isSelected: _selectedPayment == 'SadaPay',
                onTap: () => setState(() => _selectedPayment = 'SadaPay'),
              ),
              const SizedBox(width: 8),
              _PaymentOption(
                name: 'Debit Card',
                icon: Icons.payment,
                isSelected: _selectedPayment == 'Card',
                onTap: () => setState(() => _selectedPayment = 'Card'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isProcessing ? null : _processUpgrade,
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Subscribe for Rs. 999 / month', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  final String text;
  const _FeatureBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.freshGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTeal.withValues(alpha: 0.12) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppTheme.primaryTeal : Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primaryTeal : Colors.grey[700], size: 22),
              const SizedBox(height: 4),
              Text(name, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
