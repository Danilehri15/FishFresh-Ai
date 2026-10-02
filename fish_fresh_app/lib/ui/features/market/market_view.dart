import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/repositories/app_provider.dart';
import '../../core/theme.dart';

class MarketView extends StatefulWidget {
  const MarketView({super.key});

  @override
  State<MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends State<MarketView> {
  String _selectedCity = 'Lahore';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final items = state.marketPrices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Market Prices (PKR / kg)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => state.refreshData(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // City Selector Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Market Rates',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                ),
                DropdownButton<String>(
                  value: _selectedCity,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'Karachi', child: Text('Karachi')),
                    DropdownMenuItem(value: 'Lahore', child: Text('Lahore')),
                    DropdownMenuItem(value: 'Islamabad', child: Text('Islamabad')),
                  ],
                  onChanged: (val) => setState(() => _selectedCity = val ?? 'Lahore'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  int price = item.lahorePkr;
                  if (_selectedCity == 'Karachi') price = item.karachiPkr;
                  if (_selectedCity == 'Islamabad') price = item.islamabadPkr;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                            child: const Icon(Icons.set_meal, color: AppTheme.primaryTeal),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  item.category,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fair: Rs. ${item.fairMin} - ${item.fairMax} / kg',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.freshGreen, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs. $price',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                              Text(
                                item.trend,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: item.trend.startsWith('+') ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
