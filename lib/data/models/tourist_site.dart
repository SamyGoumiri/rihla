import 'package:rihla/core/constants/categories.dart';

class TouristSite {
  TouristSite({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.city,
    required this.address,
    required this.description,
    required this.latitude,
    required this.longitude,
    Set<String>? categorySlugs,
    List<String>? galleryImageUrls,
    this.shortDescription = '',
    this.historicalInfo = '',
    this.averageRating,
    this.reviewCount = 0,
  }) : categorySlugs = <String>{category.name, ...?categorySlugs},
       galleryImageUrls = List<String>.unmodifiable(
         (galleryImageUrls ?? const <String>[]).where(
           (url) => url.trim().isNotEmpty,
         ),
       );

  final String id;
  final String name;

  final String imageUrl;

  final SiteCategory category;

  final Set<String> categorySlugs;

  final List<String> galleryImageUrls;

  final String city;
  final String address;
  final String description;

  final double latitude;
  final double longitude;
  final String shortDescription;
  final String historicalInfo;

  final double? averageRating;

  final int reviewCount;

  bool hasCategorySlug(String slug) => categorySlugs.contains(slug);

  List<String> get allImageUrls => <String>[
    if (imageUrl.trim().isNotEmpty) imageUrl,
    ...galleryImageUrls,
  ];

  TouristSite copyWithRating({double? averageRating, int? reviewCount}) {
    return TouristSite(
      id: id,
      name: name,
      imageUrl: imageUrl,
      category: category,
      categorySlugs: categorySlugs,
      galleryImageUrls: galleryImageUrls,
      city: city,
      address: address,
      description: description,
      latitude: latitude,
      longitude: longitude,
      shortDescription: shortDescription,
      historicalInfo: historicalInfo,
      averageRating: averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'category': category.name,
      'categories': categorySlugs.toList(),
      'galleryImageUrls': galleryImageUrls,
      'city': city,
      'address': address,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      if (shortDescription.isNotEmpty) 'shortDescription': shortDescription,
      if (historicalInfo.isNotEmpty) 'historicalInfo': historicalInfo,
    };
  }

  factory TouristSite.fromMap(String id, Map<String, dynamic> map) {
    final SiteCategory primary = _parseCategory(map['category']);
    final Set<String> extraSlugs = _parseCategorySlugs(map['categories']);
    final List<String> gallery = _parseStringList(map['galleryImageUrls']);
    return TouristSite(
      id: id,
      name: (map['name'] as String?)?.trim() ?? '',
      imageUrl: (map['imageUrl'] as String?)?.trim() ?? '',
      category: primary,
      categorySlugs: extraSlugs,
      galleryImageUrls: gallery,
      city: (map['city'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim() ?? '',
      description: (map['description'] as String?)?.trim() ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      shortDescription: (map['shortDescription'] as String?)?.trim() ?? '',
      historicalInfo: (map['historicalInfo'] as String?)?.trim() ?? '',
      averageRating: (map['averageRating'] as num?)?.toDouble(),
      reviewCount: (map['reviewCount'] as int?) ?? 0,
    );
  }

  static Set<String> _parseCategorySlugs(Object? raw) {
    if (raw is! List) {
      return <String>{};
    }
    final slugs = <String>{};
    for (final item in raw) {
      if (item is String) {
        final trimmed = item.trim().toLowerCase();
        if (trimmed.isNotEmpty) {
          slugs.add(trimmed);
        }
      }
    }
    return slugs;
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    final result = <String>[];
    for (final item in raw) {
      if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          result.add(trimmed);
        }
      }
    }
    return result;
  }

  String shortIntro({int maxChars = 180}) {
    if (shortDescription.isNotEmpty) {
      return shortDescription;
    }
    if (description.isEmpty) return '';
    final firstSentenceEnd = description.indexOf(RegExp(r'[.!?]\s'));
    if (firstSentenceEnd > 0 && firstSentenceEnd < maxChars) {
      return description.substring(0, firstSentenceEnd + 1).trim();
    }
    if (description.length <= maxChars) return description;
    return '${description.substring(0, maxChars).trim()}…';
  }

  static SiteCategory _parseCategory(Object? raw) {
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      for (final category in SiteCategory.values) {
        if (category.name == normalized ||
            category.label.toLowerCase() == normalized) {
          return category;
        }
      }
    }
    return SiteCategory.culture;
  }
}
