class SiteReview {
  const SiteReview({
    required this.siteId,
    required this.rating,
    required this.comment,
    required this.updatedAt,
  });

  static const int maxCommentLength = 500;

  final String siteId;
  final double rating;
  final String comment;
  final DateTime updatedAt;

  SiteReview copyWith({
    String? siteId,
    double? rating,
    String? comment,
    DateTime? updatedAt,
  }) {
    return SiteReview(
      siteId: siteId ?? this.siteId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'siteId': siteId,
      'rating': rating,
      'comment': comment,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SiteReview.fromMap(Map<String, dynamic> map) {
    final rawRating = map['rating'];
    final rawUpdatedAt = map['updatedAt'];
    return SiteReview(
      siteId: (map['siteId'] as String?)?.trim() ?? '',
      rating: rawRating is num ? rawRating.toDouble().clamp(0, 5) : 0,
      comment: (map['comment'] as String?) ?? '',
      updatedAt: rawUpdatedAt is String
          ? (DateTime.tryParse(rawUpdatedAt) ??
                DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
