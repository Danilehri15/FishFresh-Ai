class ScanResponse {
  final String imageFile;
  final String status;
  final bool isFish;
  final String? rejectionReason;
  final String? message;
  final SpeciesData? species;
  final FreshnessData? freshness;
  final ShelfLifeData? shelfLife;
  final MarketPriceComparison? marketPrice;
  final DateTime scannedAt;

  ScanResponse({
    required this.imageFile,
    required this.status,
    required this.isFish,
    this.rejectionReason,
    this.message,
    this.species,
    this.freshness,
    this.shelfLife,
    this.marketPrice,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();

  factory ScanResponse.fromJson(Map<String, dynamic> json) {
    final bool isFish = json['is_fish'] ?? (json['status'] == 'SUCCESS');
    if (!isFish || json['status'] == 'REJECTED') {
      return ScanResponse(
        imageFile: json['image_file'] ?? 'unknown.jpg',
        status: 'REJECTED',
        isFish: false,
        rejectionReason: json['reason'] ?? 'Non-fish image detected.',
        message: json['message'] ?? 'Please upload a clear photo of a fish (whole fish, eye, or gills).',
      );
    }

    return ScanResponse(
      imageFile: json['image_file'] ?? 'scanned.jpg',
      status: json['status'] ?? 'SUCCESS',
      isFish: true,
      species: json['species_detection'] != null ? SpeciesData.fromJson(json['species_detection']) : null,
      freshness: json['freshness_detection'] != null ? FreshnessData.fromJson(json['freshness_detection']) : null,
      shelfLife: json['shelf_life_estimation'] != null ? ShelfLifeData.fromJson(json['shelf_life_estimation']) : null,
      marketPrice: json['market_price_info'] != null ? MarketPriceComparison.fromJson(json['market_price_info']) : null,
    );
  }
}

class SpeciesData {
  final String predictedSpecies;
  final String displayName;
  final String localName;
  final String scientificName;
  final String category;
  final double confidencePercent;
  final bool isUncertain;
  final double typicalMarketPricePkr;
  final String description;
  final List<TopPrediction> topPredictions;

  SpeciesData({
    required this.predictedSpecies,
    required this.displayName,
    required this.localName,
    required this.scientificName,
    required this.category,
    required this.confidencePercent,
    required this.isUncertain,
    required this.typicalMarketPricePkr,
    required this.description,
    required this.topPredictions,
  });

  factory SpeciesData.fromJson(Map<String, dynamic> json) {
    return SpeciesData(
      predictedSpecies: json['predicted_species'] ?? '',
      displayName: json['display_name'] ?? 'Fish',
      localName: json['local_name'] ?? 'N/A',
      scientificName: json['scientific_name'] ?? 'N/A',
      category: json['category'] ?? 'N/A',
      confidencePercent: (json['confidence_percent'] as num?)?.toDouble() ?? 0.0,
      isUncertain: json['is_uncertain'] ?? false,
      typicalMarketPricePkr: (json['typical_market_price_pkr'] as num?)?.toDouble() ?? 700.0,
      description: json['description'] ?? '',
      topPredictions: (json['top_predictions'] as List<dynamic>?)
              ?.map((e) => TopPrediction.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class TopPrediction {
  final String species;
  final String displayName;
  final double confidence;

  TopPrediction({required this.species, required this.displayName, required this.confidence});

  factory TopPrediction.fromJson(Map<String, dynamic> json) {
    return TopPrediction(
      species: json['species'] ?? '',
      displayName: json['display_name'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FreshnessData {
  final String status;
  final bool isFresh;
  final double confidencePercent;
  final double freshnessProbability;
  final String qualityGrade;

  FreshnessData({
    required this.status,
    required this.isFresh,
    required this.confidencePercent,
    required this.freshnessProbability,
    required this.qualityGrade,
  });

  factory FreshnessData.fromJson(Map<String, dynamic> json) {
    return FreshnessData(
      status: json['status'] ?? 'Fresh',
      isFresh: json['is_fresh'] ?? true,
      confidencePercent: (json['confidence_percent'] as num?)?.toDouble() ?? 99.0,
      freshnessProbability: (json['freshness_probability'] as num?)?.toDouble() ?? 0.99,
      qualityGrade: json['quality_grade'] ?? 'Optimal Fresh',
    );
  }
}

class ShelfLifeData {
  final int refrigeratedHours;
  final double refrigeratedDays;
  final int ambientHours;
  final String recommendation;

  ShelfLifeData({
    required this.refrigeratedHours,
    required this.refrigeratedDays,
    required this.ambientHours,
    required this.recommendation,
  });

  factory ShelfLifeData.fromJson(Map<String, dynamic> json) {
    return ShelfLifeData(
      refrigeratedHours: json['storage_refrigerated_hours'] ?? 0,
      refrigeratedDays: (json['storage_refrigerated_days'] as num?)?.toDouble() ?? 0.0,
      ambientHours: json['storage_ambient_hours'] ?? 0,
      recommendation: json['recommendation'] ?? 'Keep refrigerated.',
    );
  }
}

class MarketPriceComparison {
  final String speciesId;
  final String displayName;
  final double askingPricePkr;
  final double standardMarketRatePkr;
  final String fairPriceRangePkr;
  final String verdict;
  final String advice;

  MarketPriceComparison({
    required this.speciesId,
    required this.displayName,
    required this.askingPricePkr,
    required this.standardMarketRatePkr,
    required this.fairPriceRangePkr,
    required this.verdict,
    required this.advice,
  });

  factory MarketPriceComparison.fromJson(Map<String, dynamic> json) {
    return MarketPriceComparison(
      speciesId: json['species_id'] ?? '',
      displayName: json['display_name'] ?? '',
      askingPricePkr: (json['asking_price_pkr'] as num?)?.toDouble() ?? 0.0,
      standardMarketRatePkr: (json['standard_market_rate_pkr'] as num?)?.toDouble() ?? 0.0,
      fairPriceRangePkr: json['fair_price_range_pkr'] ?? '',
      verdict: json['verdict'] ?? 'FAIR_PRICE',
      advice: json['advice'] ?? '',
    );
  }
}
