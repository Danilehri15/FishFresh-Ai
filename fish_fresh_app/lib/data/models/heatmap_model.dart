import 'package:flutter/material.dart';

class MarketHeatmapPoint {
  final String marketName;
  final double latitude;
  final double longitude;
  final String city;
  final int totalScans;
  final int freshCount;
  final int spoiledCount;
  final double avgFreshnessScore;
  final String qualityRating;
  final String colorHex;
  final String recommendation;

  MarketHeatmapPoint({
    required this.marketName,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.totalScans,
    required this.freshCount,
    required this.spoiledCount,
    required this.avgFreshnessScore,
    required this.qualityRating,
    required this.colorHex,
    required this.recommendation,
  });

  factory MarketHeatmapPoint.fromJson(Map<String, dynamic> json) {
    return MarketHeatmapPoint(
      marketName: json['market_name'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      city: json['city'] ?? '',
      totalScans: json['total_scans'] ?? 0,
      freshCount: json['fresh_count'] ?? 0,
      spoiledCount: json['spoiled_count'] ?? 0,
      avgFreshnessScore: (json['avg_freshness_score'] ?? 0).toDouble(),
      qualityRating: json['quality_rating'] ?? 'UNKNOWN',
      colorHex: json['color_hex'] ?? '#757575',
      recommendation: json['recommendation'] ?? '',
    );
  }

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  double get freshPercentage => totalScans > 0 ? (freshCount / totalScans) * 100 : 0;
}
