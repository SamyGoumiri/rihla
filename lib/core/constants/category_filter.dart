import 'package:rihla/core/constants/categories.dart';
import 'package:rihla/data/models/tourist_site.dart';

class CategoryFilter {
  const CategoryFilter({
    required this.key,
    required this.label,
    required this.category,
  });

  final String key;
  final String label;

  final SiteCategory category;

  bool matches(TouristSite site) => site.hasCategorySlug(category.name);
}

class CategoryFilters {
  const CategoryFilters._();

  static const CategoryFilter nature = CategoryFilter(
    key: 'nature',
    label: 'Nature',
    category: SiteCategory.nature,
  );

  static const CategoryFilter histoire = CategoryFilter(
    key: 'histoire',
    label: 'Histoire',
    category: SiteCategory.histoire,
  );

  static const CategoryFilter culture = CategoryFilter(
    key: 'culture',
    label: 'Culture',
    category: SiteCategory.culture,
  );

  static const CategoryFilter loisirs = CategoryFilter(
    key: 'loisirs',
    label: 'Loisirs',
    category: SiteCategory.loisirs,
  );

  static const List<CategoryFilter> explorer = <CategoryFilter>[
    nature,
    histoire,
    culture,
    loisirs,
  ];

  static const List<CategoryFilter> map = <CategoryFilter>[
    nature,
    histoire,
    culture,
    loisirs,
  ];

  static CategoryFilter? byKey(String? key) {
    if (key == null) return null;
    for (final f in explorer) {
      if (f.key == key) return f;
    }
    return null;
  }

  static bool matchesKey(TouristSite site, String? key) {
    if (key == null) return true;
    final filter = byKey(key);
    if (filter == null) return true;
    return filter.matches(site);
  }
}
