import 'dart:async';
import 'dart:developer' as developer;

import 'package:rihla/core/database/local_database.dart';
import 'package:rihla/core/services/auth_uid_resolver.dart';
import 'package:rihla/core/services/guest_session_service.dart';
import 'package:rihla/data/models/site_review.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicReview {
  const PublicReview({
    required this.authorUserId,
    required this.siteId,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.rating,
    required this.comment,
    required this.updatedAt,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.repliesCount = 0,
    this.userReaction,
  });

  final String authorUserId;
  final String siteId;
  final String authorName;
  final String authorPhotoUrl;
  final double rating;
  final String comment;
  final DateTime updatedAt;
  final int likesCount;
  final int dislikesCount;
  final int repliesCount;
  final String? userReaction;
}

class PublicReviewReply {
  const PublicReviewReply({
    required this.id,
    required this.reviewUserId,
    required this.siteId,
    required this.authorUserId,
    required this.authorName,
    required this.comment,
    required this.updatedAt,
  });

  final String id;
  final String reviewUserId;
  final String siteId;
  final String authorUserId;
  final String authorName;
  final String comment;
  final DateTime updatedAt;
}

class RatingService {
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

  static void notifyChanged() => _changesController.add(null);

  RatingService({String? userIdOverride}) : _userIdOverride = userIdOverride;

  final String? _userIdOverride;

  String get _userId {
    if (_userIdOverride?.isNotEmpty == true) return _userIdOverride!;
    return resolveCurrentUid() ??
        GuestSessionService.currentGuestIdOrNull() ??
        'guest_uninitialized';
  }

  Future<Database> get _db => LocalDatabase.instance.open();

  Future<Map<String, double>> getRatings() async {
    final db = await _db;
    final rows = await db.query(
      'ratings',
      columns: ['site_id', 'rating'],
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [_userId],
    );
    return {
      for (final r in rows)
        r['site_id'] as String: (r['rating'] as num).toDouble(),
    };
  }

  Future<double?> getUserRating(String siteId) async {
    final db = await _db;
    final rows = await db.query(
      'ratings',
      columns: ['rating'],
      where: 'user_id = ? AND site_id = ? AND deleted = 0',
      whereArgs: [_userId, siteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['rating'] as num).toDouble();
  }

  Future<void> setUserRating({
    required String siteId,
    required double rating,
  }) async {
    final db = await _db;
    await db.insert('ratings', {
      'user_id': _userId,
      'site_id': siteId,
      'rating': rating,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'dirty': 1,
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changesController.add(null);
  }

  Future<void> setRatings(Map<String, double> ratings) async {
    final db = await _db;
    final batch = db.batch();
    batch.update(
      'ratings',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in ratings.entries) {
      batch.insert('ratings', {
        'user_id': _userId,
        'site_id': entry.key,
        'rating': entry.value,
        'updated_at': now,
        'dirty': 0,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _changesController.add(null);
  }

  Future<SiteReview?> getReview(String siteId) async {
    final db = await _db;
    final rows = await db.query(
      'reviews',
      where: 'user_id = ? AND site_id = ? AND deleted = 0',
      whereArgs: [_userId, siteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _reviewFromRow(rows.first);
  }

  Future<Map<String, SiteReview>> getReviews() async {
    final db = await _db;
    final rows = await db.query(
      'reviews',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [_userId],
    );
    return {for (final r in rows) r['site_id'] as String: _reviewFromRow(r)};
  }

  Future<void> setReview(SiteReview review) async {
    final db = await _db;
    final trimmedComment = review.comment.trim();
    final boundedComment = trimmedComment.length > SiteReview.maxCommentLength
        ? trimmedComment.substring(0, SiteReview.maxCommentLength)
        : trimmedComment;
    final ts = review.updatedAt.millisecondsSinceEpoch;
    final batch = db.batch();
    batch.insert('reviews', {
      'user_id': _userId,
      'site_id': review.siteId,
      'rating': review.rating,
      'comment': boundedComment,
      'updated_at': ts,
      'dirty': 1,
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('ratings', {
      'user_id': _userId,
      'site_id': review.siteId,
      'rating': review.rating,
      'updated_at': ts,
      'dirty': 1,
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
    _changesController.add(null);
  }

  Future<void> removeReview(String siteId) async {
    final db = await _db;
    await db.update(
      'reviews',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ? AND site_id = ?',
      whereArgs: [_userId, siteId],
    );
    _changesController.add(null);
  }

  Future<void> setReviews(Map<String, SiteReview> reviews) async {
    final db = await _db;
    final batch = db.batch();
    batch.update(
      'reviews',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in reviews.entries) {
      batch.insert('reviews', {
        'user_id': _userId,
        'site_id': entry.key,
        'rating': entry.value.rating,
        'comment': entry.value.comment,
        'updated_at': now,
        'dirty': 0,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _changesController.add(null);
  }

  Future<List<PublicReview>> fetchPublicReviewsForSite(
    String siteId, {
    int limit = 50,
  }) async {
    if (siteId.isEmpty) return const <PublicReview>[];
    try {
      final SupabaseClient client = Supabase.instance.client;
      final response = await _selectPublicReviews(client, siteId, limit);
      final rows = List<Map<String, dynamic>>.from(response as List);
      final reactions = await _fetchReviewReactions(client, siteId);
      final replyCounts = await _fetchReplyCounts(client, siteId);
      final currentUid = resolveCurrentUid();
      final reviews =
          rows.map((r) {
            final authorUserId = ((r['user_id'] as String?) ?? '').trim();
            final reviewReactions = reactions.where(
              (reaction) => reaction.reviewUserId == authorUserId,
            );
            final likesCount = reviewReactions
                .where((reaction) => reaction.reaction == 'like')
                .length;
            final dislikesCount = reviewReactions
                .where((reaction) => reaction.reaction == 'dislike')
                .length;
            final userReaction = currentUid == null
                ? null
                : reviewReactions
                      .where((reaction) => reaction.userId == currentUid)
                      .map((reaction) => reaction.reaction)
                      .firstOrNull;
            return PublicReview(
              authorUserId: authorUserId,
              siteId: r['site_id'] as String,
              authorName: ((r['author_name'] as String?) ?? '').trim(),
              authorPhotoUrl: ((r['author_photo_url'] as String?) ?? '').trim(),
              rating: (r['rating'] as num).toDouble(),
              comment: ((r['comment'] as String?) ?? '').trim(),
              updatedAt: _parseTimestamp(r['updated_at']),
              likesCount: likesCount,
              dislikesCount: dislikesCount,
              repliesCount: replyCounts[authorUserId] ?? 0,
              userReaction: userReaction,
            );
          }).toList()..sort((a, b) {
            final byBalance = (b.likesCount - b.dislikesCount).compareTo(
              a.likesCount - a.dislikesCount,
            );
            if (byBalance != 0) return byBalance;
            final byLikes = b.likesCount.compareTo(a.likesCount);
            if (byLikes != 0) return byLikes;
            final byDate = b.updatedAt.compareTo(a.updatedAt);
            if (byDate != 0) return byDate;
            return b.rating.compareTo(a.rating);
          });
      return reviews;
    } catch (e) {
      developer.log('fetchPublicReviewsForSite failed: $e', level: 800);
      return const <PublicReview>[];
    }
  }

  Future<void> setReviewReaction({
    required PublicReview review,
    required String reaction,
  }) async {
    final uid = resolveCurrentUid();
    if (uid == null || uid == review.authorUserId) return;
    if (reaction != 'like' && reaction != 'dislike') return;
    try {
      await Supabase.instance.client.from('review_reactions').upsert({
        'user_id': uid,
        'review_user_id': review.authorUserId,
        'site_id': review.siteId,
        'reaction': reaction,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      developer.log('setReviewReaction failed: $e', level: 800);
    }
  }

  Future<void> removeReviewReaction(PublicReview review) async {
    final uid = resolveCurrentUid();
    if (uid == null) return;
    try {
      await Supabase.instance.client.from('review_reactions').delete().match({
        'user_id': uid,
        'review_user_id': review.authorUserId,
        'site_id': review.siteId,
      });
    } catch (e) {
      developer.log('removeReviewReaction failed: $e', level: 800);
    }
  }

  Future<Map<String, int>> _fetchReplyCounts(
    SupabaseClient client,
    String siteId,
  ) async {
    try {
      final response = await client
          .from('review_replies')
          .select('review_user_id')
          .eq('site_id', siteId);
      final rows = List<Map<String, dynamic>>.from(response as List);
      final counts = <String, int>{};
      for (final row in rows) {
        final reviewUserId = ((row['review_user_id'] as String?) ?? '').trim();
        if (reviewUserId.isEmpty) continue;
        counts[reviewUserId] = (counts[reviewUserId] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      developer.log('_fetchReplyCounts failed: $e', level: 800);
      return const <String, int>{};
    }
  }

  Future<List<PublicReviewReply>> fetchRepliesForReview(
    PublicReview review,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('review_replies')
          .select(
            'id, review_user_id, site_id, user_id, author_name, '
            'comment, updated_at',
          )
          .eq('site_id', review.siteId)
          .eq('review_user_id', review.authorUserId)
          .order('updated_at', ascending: true);
      final rows = List<Map<String, dynamic>>.from(response as List);
      return rows
          .map(
            (r) => PublicReviewReply(
              id: ((r['id'] as String?) ?? '').trim(),
              reviewUserId: ((r['review_user_id'] as String?) ?? '').trim(),
              siteId: ((r['site_id'] as String?) ?? '').trim(),
              authorUserId: ((r['user_id'] as String?) ?? '').trim(),
              authorName: ((r['author_name'] as String?) ?? '').trim(),
              comment: ((r['comment'] as String?) ?? '').trim(),
              updatedAt: _parseTimestamp(r['updated_at']),
            ),
          )
          .toList();
    } catch (e) {
      developer.log('fetchRepliesForReview failed: $e', level: 800);
      return const <PublicReviewReply>[];
    }
  }

  Future<void> addReplyToReview({
    required PublicReview review,
    required String comment,
  }) async {
    final uid = resolveCurrentUid();
    final trimmed = comment.trim();
    if (uid == null || trimmed.isEmpty) return;
    try {
      await Supabase.instance.client.from('review_replies').insert({
        'review_user_id': review.authorUserId,
        'site_id': review.siteId,
        'user_id': uid,
        'comment': trimmed.length > SiteReview.maxCommentLength
            ? trimmed.substring(0, SiteReview.maxCommentLength)
            : trimmed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      developer.log('addReplyToReview failed: $e', level: 800);
    }
  }

  Future<bool> updateReplyComment({
    required String replyId,
    required String comment,
  }) async {
    final uid = resolveCurrentUid();
    final trimmed = comment.trim();
    if (uid == null || replyId.isEmpty || trimmed.isEmpty) return false;
    try {
      await Supabase.instance.client
          .from('review_replies')
          .update({
            'comment': trimmed.length > SiteReview.maxCommentLength
                ? trimmed.substring(0, SiteReview.maxCommentLength)
                : trimmed,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', replyId)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      developer.log('updateReplyComment failed: $e', level: 800);
      return false;
    }
  }

  Future<bool> deleteReply(String replyId) async {
    final uid = resolveCurrentUid();
    if (uid == null || replyId.isEmpty) return false;
    try {
      await Supabase.instance.client
          .from('review_replies')
          .delete()
          .eq('id', replyId)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      developer.log('deleteReply failed: $e', level: 800);
      return false;
    }
  }

  Future<List<_ReviewReactionRow>> _fetchReviewReactions(
    SupabaseClient client,
    String siteId,
  ) async {
    final response = await client
        .from('review_reactions')
        .select('user_id, review_user_id, reaction')
        .eq('site_id', siteId);
    final rows = List<Map<String, dynamic>>.from(response as List);
    return rows
        .map(
          (row) => _ReviewReactionRow(
            userId: ((row['user_id'] as String?) ?? '').trim(),
            reviewUserId: ((row['review_user_id'] as String?) ?? '').trim(),
            reaction: ((row['reaction'] as String?) ?? '').trim(),
          ),
        )
        .toList();
  }

  Future<Object> _selectPublicReviews(
    SupabaseClient client,
    String siteId,
    int limit,
  ) async {
    try {
      return await client
          .from('reviews')
          .select(
            'user_id, site_id, author_name, author_photo_url, rating, comment, updated_at',
          )
          .eq('site_id', siteId)
          .order('updated_at', ascending: false)
          .limit(limit);
    } catch (e) {
      developer.log(
        'fetchPublicReviewsForSite without author_photo_url fallback: $e',
        level: 800,
      );
      return client
          .from('reviews')
          .select('user_id, site_id, author_name, rating, comment, updated_at')
          .eq('site_id', siteId)
          .order('updated_at', ascending: false)
          .limit(limit);
    }
  }

  static DateTime _parseTimestamp(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    return DateTime.now().toUtc();
  }

  SiteReview _reviewFromRow(Map<String, dynamic> row) {
    return SiteReview(
      siteId: row['site_id'] as String,
      rating: (row['rating'] as num).toDouble(),
      comment: (row['comment'] as String?) ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int,
        isUtc: true,
      ),
    );
  }
}

class _ReviewReactionRow {
  const _ReviewReactionRow({
    required this.userId,
    required this.reviewUserId,
    required this.reaction,
  });

  final String userId;
  final String reviewUserId;
  final String reaction;
}
