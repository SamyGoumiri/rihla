import 'package:supabase_flutter/supabase_flutter.dart';

abstract class RemoteDatabase {
  Future<List<Map<String, dynamic>>> fetchSites();

  Future<List<Map<String, dynamic>>> fetchReviewRatings();

  Future<List<Map<String, dynamic>>> fetchCategories();

  Future<Map<String, dynamic>?> fetchProfile(String userId);

  Future<void> upsertProfile(Map<String, dynamic> profile);

  Future<UserDataSnapshot> fetchUserData(String userId);

  Future<void> upsertFavorites(List<Map<String, dynamic>> rows);

  Future<void> deleteFavorites(List<Map<String, dynamic>> rows);

  Future<void> upsertViewHistory(List<Map<String, dynamic>> rows);

  Future<void> deleteViewHistory(List<String> ids);

  Future<void> deleteAllViewHistoryForUser(String userId);

  Future<void> upsertRatings(List<Map<String, dynamic>> rows);

  Future<void> deleteRatings(List<Map<String, dynamic>> rows);

  Future<void> upsertReviews(List<Map<String, dynamic>> rows);

  Future<void> deleteReviews(List<Map<String, dynamic>> rows);
}

class UserDataSnapshot {
  const UserDataSnapshot({
    required this.profile,
    required this.favorites,
    required this.viewHistory,
    required this.ratings,
    required this.reviews,
  });

  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> favorites;
  final List<Map<String, dynamic>> viewHistory;
  final List<Map<String, dynamic>> ratings;
  final List<Map<String, dynamic>> reviews;
}

class SupabaseRemoteDatabase implements RemoteDatabase {
  SupabaseRemoteDatabase({SupabaseClient? client}) : _injectedClient = client;

  final SupabaseClient? _injectedClient;

  SupabaseClient get _client {
    final injected = _injectedClient;
    if (injected != null) return injected;
    try {
      return Supabase.instance.client;
    } on Object catch (e) {
      throw StateError(
        'Supabase non configuré : impossible d\'effectuer la requête '
        'distante. Relancez avec --dart-define=SUPABASE_URL=... '
        '--dart-define=SUPABASE_ANON_KEY=... ($e)',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSites() async {
    final response = await _client
        .from('sites')
        .select('*, site_categories(category_slug)')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReviewRatings() async {
    final response = await _client.from('reviews').select('site_id, rating');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await _client
        .from('categories')
        .select()
        .order('display_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  @override
  Future<void> upsertProfile(Map<String, dynamic> profile) async {
    await _client.from('profiles').upsert(profile);
  }

  @override
  Future<UserDataSnapshot> fetchUserData(String userId) async {
    final results = await Future.wait<dynamic>([
      _client.from('profiles').select().eq('id', userId).maybeSingle(),
      _client.from('favorites').select().eq('user_id', userId),

      _client
          .from('view_history')
          .select()
          .eq('user_id', userId)
          .order('viewed_at', ascending: false)
          .limit(1000),
      _client.from('ratings').select().eq('user_id', userId),
      _client.from('reviews').select().eq('user_id', userId),
    ]);
    return UserDataSnapshot(
      profile: results[0] as Map<String, dynamic>?,
      favorites: List<Map<String, dynamic>>.from(results[1] as List),
      viewHistory: List<Map<String, dynamic>>.from(results[2] as List),
      ratings: List<Map<String, dynamic>>.from(results[3] as List),
      reviews: List<Map<String, dynamic>>.from(results[4] as List),
    );
  }

  @override
  Future<void> upsertFavorites(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('favorites').upsert(rows);
  }

  @override
  Future<void> deleteFavorites(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      await _client.from('favorites').delete().match({
        'user_id': row['user_id'],
        'site_id': row['site_id'],
      });
    }
  }

  @override
  Future<void> upsertViewHistory(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('view_history').insert(rows);
  }

  @override
  Future<void> deleteViewHistory(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('view_history').delete().inFilter('id', ids);
  }

  @override
  Future<void> deleteAllViewHistoryForUser(String userId) async {
    await _client.from('view_history').delete().eq('user_id', userId);
  }

  @override
  Future<void> upsertRatings(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('ratings').upsert(rows);
  }

  @override
  Future<void> deleteRatings(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      await _client.from('ratings').delete().match({
        'user_id': row['user_id'],
        'site_id': row['site_id'],
      });
    }
  }

  @override
  Future<void> upsertReviews(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('reviews').upsert(rows);
  }

  @override
  Future<void> deleteReviews(List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      await _client.from('reviews').delete().match({
        'user_id': row['user_id'],
        'site_id': row['site_id'],
      });
    }
  }
}
