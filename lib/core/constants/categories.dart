import 'package:flutter/material.dart';

enum SiteCategory { nature, histoire, culture, loisirs }

extension SiteCategoryLabel on SiteCategory {
  String get label {
    switch (this) {
      case SiteCategory.nature:
        return 'Nature';
      case SiteCategory.histoire:
        return 'Histoire';
      case SiteCategory.culture:
        return 'Culture';
      case SiteCategory.loisirs:
        return 'Loisirs';
    }
  }
}

extension SiteCategoryIcon on SiteCategory {
  IconData get icon {
    switch (this) {
      case SiteCategory.nature:
        return Icons.nature_outlined;
      case SiteCategory.histoire:
        return Icons.castle_outlined;
      case SiteCategory.culture:
        return Icons.museum_outlined;
      case SiteCategory.loisirs:
        return Icons.attractions_outlined;
    }
  }
}
