class MarketPriceItem {
  final String speciesId;
  final String displayName;
  final String scientificName;
  final String category;
  final int karachiPkr;
  final int lahorePkr;
  final int islamabadPkr;
  final int retailAvgPkr;
  final int wholesaleAvgPkr;
  final int fairMin;
  final int fairMax;
  final String trend;
  final String supplyStatus;

  MarketPriceItem({
    required this.speciesId,
    required this.displayName,
    required this.scientificName,
    required this.category,
    required this.karachiPkr,
    required this.lahorePkr,
    required this.islamabadPkr,
    required this.retailAvgPkr,
    required this.wholesaleAvgPkr,
    required this.fairMin,
    required this.fairMax,
    required this.trend,
    required this.supplyStatus,
  });

  factory MarketPriceItem.fromJson(Map<String, dynamic> json) {
    return MarketPriceItem(
      speciesId: json['species_id'] ?? '',
      displayName: json['display_name'] ?? '',
      scientificName: json['scientific_name'] ?? '',
      category: json['category'] ?? '',
      karachiPkr: json['karachi_harbour_pkr'] ?? 0,
      lahorePkr: json['lahore_market_pkr'] ?? 0,
      islamabadPkr: json['islamabad_market_pkr'] ?? 0,
      retailAvgPkr: json['retail_avg_pkr'] ?? 0,
      wholesaleAvgPkr: json['wholesale_avg_pkr'] ?? 0,
      fairMin: json['fair_price_min'] ?? 0,
      fairMax: json['fair_price_max'] ?? 0,
      trend: json['trend'] ?? '0.0%',
      supplyStatus: json['supply_status'] ?? 'Normal',
    );
  }
}
