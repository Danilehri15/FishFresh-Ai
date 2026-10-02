import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../data/models/scan_result.dart';
import '../../core/theme.dart';
import '../chatbot/chatbot_view.dart';

class ResultView extends StatelessWidget {
  final ScanResponse result;
  final Uint8List? imageBytes;

  const ResultView({super.key, required this.result, this.imageBytes});

  @override
  Widget build(BuildContext context) {
    // 1. Handle Non-Fish Rejection
    if (!result.isFish || result.status == 'REJECTED') {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan Result')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(
                        Icons.cancel,
                        color: AppTheme.spoiledRed,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Non-Fish Image Detected',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.spoiledRed,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result.message ??
                          'No valid fish detected in this image. Please upload a clear photo of a fish.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Try Another Image'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final sp = result.species!;
    final fr = result.freshness!;
    final sh = result.shelfLife!;
    final mp = result.marketPrice;
    final isFresh = fr.isFresh;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Analysis Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail & Status Badge Header
            Row(
              children: [
                if (imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageBytes!,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sp.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      Text(
                        '${sp.localName} • ${sp.scientificName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isFresh
                                      ? AppTheme.freshGreen
                                      : AppTheme.spoiledRed)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${fr.status.toUpperCase()} (${fr.qualityGrade})',
                          style: TextStyle(
                            color: isFresh
                                ? AppTheme.freshGreen
                                : AppTheme.spoiledRed,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Low confidence warning
            if (sp.isUncertain)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.warningOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber,
                      color: AppTheme.warningOrange,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Low Confidence (<65%): Image lighting or angle is ambiguous. Results may be approximate.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warningOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. SPECIES IDENTIFICATION CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '1. Species Identification',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${sp.confidencePercent.toStringAsFixed(1)}% AI Conf.',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: sp.confidencePercent / 100,
                      backgroundColor: Colors.grey[200],
                      color: AppTheme.primaryTeal,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Top Candidates Considered:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    ...sp.topPredictions.map(
                      (top) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '• ${top.displayName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${top.confidence.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 2. SHELF-LIFE & FRESHNESS CARD WITH CIRCLE BAR GAUGE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '2. Multi-Organ Freshness & Shelf-Life',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isFresh
                                        ? AppTheme.freshGreen
                                        : AppTheme.spoiledRed)
                                    .withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fr.qualityGrade,
                            style: TextStyle(
                              color: isFresh
                                  ? AppTheme.freshGreen
                                  : AppTheme.spoiledRed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Circle Gauge + Shelf Life Dials
                    Row(
                      children: [
                        // Freshness Circular Progress Bar Gauge
                        FreshnessCircleGauge(
                          percentage: fr.confidencePercent,
                          probability: fr.freshnessProbability,
                          isFresh: isFresh,
                          statusLabel: fr.status,
                        ),

                        const SizedBox(width: 16),

                        // Shelf-Life Dials Column
                        Expanded(
                          child: Column(
                            children: [
                              _DialBox(
                                title: 'Chilled (0-4°C on Ice)',
                                value: isFresh
                                    ? '${sh.refrigeratedHours}h'
                                    : '0h',
                                subtitle: isFresh
                                    ? '~${sh.refrigeratedDays} days shelf-life'
                                    : 'Expired / Unsafe',
                                color: isFresh
                                    ? AppTheme.freshGreen
                                    : AppTheme.spoiledRed,
                              ),
                              const SizedBox(height: 8),
                              _DialBox(
                                title: 'Ambient (20-25°C Room Temp)',
                                value: isFresh ? '${sh.ambientHours}h' : '0h',
                                subtitle: isFresh
                                    ? 'Cook today'
                                    : 'Do not consume',
                                color: isFresh
                                    ? AppTheme.accentCyan
                                    : AppTheme.spoiledRed,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Text(
                      sh.recommendation,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. MODULE 6.4 LIVE MARKET PRICE CHECK
            if (mp != null)
              Card(
                color: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '3. Market Fair Price Cross-Check',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.freshGreen,
                            ),
                          ),
                          Text(
                            mp.fairPriceRangePkr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.freshGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mp.advice,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 4. ASK CHATBOT BUTTON (Module 6.5)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('Ask AI Fishery Assistant about ${sp.displayName}'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatbotView(
                        initialQuery:
                            'How to cook fresh ${sp.displayName} and what are the best storage tips?',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialBox extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _DialBox({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class FreshnessCircleGauge extends StatelessWidget {
  final double percentage;
  final double probability;
  final bool isFresh;
  final String statusLabel;

  const FreshnessCircleGauge({
    super.key,
    required this.percentage,
    required this.probability,
    required this.isFresh,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final Color mainColor = isFresh ? AppTheme.freshGreen : AppTheme.spoiledRed;

    return Container(
      width: 125,
      height: 125,
      decoration: BoxDecoration(
        color: mainColor.withAlpha(15),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular Progress Indicator Ring
          SizedBox(
            width: 115,
            height: 115,
            child: CircularProgressIndicator(
              value: (probability.clamp(0.0, 1.0)),
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(mainColor),
              backgroundColor: mainColor.withAlpha(35),
            ),
          ),

          // Percentage Text & Status Label inside Circle
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFresh ? Icons.check_circle : Icons.cancel,
                color: mainColor,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: mainColor,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                statusLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
