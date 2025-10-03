import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:snackflix/models/video_item.dart';

class YouTubeService {
  final FirebaseFirestore _fs;
  final FirebaseFunctions _fns;

  YouTubeService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _fns = functions ?? FirebaseFunctions.instance;

  // Deterministic SHA-1 for sorted params (matches server)
  String _cacheKey(Map<String, dynamic> params) {
    final sorted = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final jsonStr = json.encode(sorted);
    return sha1.convert(utf8.encode(jsonStr)).toString();
  }

  static const _fieldData = 'data';
  static const _fieldUpdatedAt = 'updatedAt';
  static const _fieldTtlFresh = 'ttlSecFresh';
  static const _fieldTtlSoft = 'ttlSecSoft';

  Future<_CacheHit?> _tryReadCache(String collection, String key) async {
    final snap = await _fs.collection(collection).doc(key).get();
    if (!snap.exists) return null;
    final m = snap.data()!;
    final updatedAt = (m[_fieldUpdatedAt] as Timestamp?)?.toDate();
    if (updatedAt == null) return null;

    final freshSec = (m[_fieldTtlFresh] as num?)?.toInt() ?? 0;
    final softSec = (m[_fieldTtlSoft] as num?)?.toInt() ?? freshSec;
    final now = DateTime.now();
    final freshUntil = updatedAt.add(Duration(seconds: freshSec));
    final softUntil = updatedAt.add(Duration(seconds: softSec));

    final state = now.isBefore(freshUntil)
        ? _Freshness.fresh
        : now.isBefore(softUntil)
        ? _Freshness.softStale
        : _Freshness.stale;

    final List<dynamic> raw = (m[_fieldData] as List?) ?? const [];
    return _CacheHit(_toVideoItemsFromAny(raw), state);
  }

  // Normalizes both Firestore docs and callable results
  List<VideoItem> _toVideoItemsFromAny(List<dynamic> raw) {
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);

      // Callable returns publishedAtMillis (int). Convert to Timestamp -> DateTime inside fromMap.
      if (m.containsKey('publishedAtMillis')) {
        final millis = (m['publishedAtMillis'] as num).toInt();
        m['publishedAt'] = Timestamp.fromMillisecondsSinceEpoch(millis);
        m.remove('publishedAtMillis');
      }

      // Expected keys: id, title, channel, thumbnailUrl, publishedAt(Timestamp)
      return VideoItem.fromMap(m);
    }).toList();
  }

  Future<List<VideoItem>> _fetch({
    required String cacheCollection,
    required String cacheKey,
    required Map<String, dynamic> paramsForFn,
  }) async {
    // 1) Try Firestore first
    final hit = await _tryReadCache(cacheCollection, cacheKey);
    if (hit != null) {
      if (hit.state == _Freshness.fresh) {
        return hit.items;
      }
      if (hit.state == _Freshness.softStale) {
        // Serve now; background refresh without blocking UX
        Future.microtask(() async {
          try {
            await _fns.httpsCallable('fetchYouTubeData').call(paramsForFn);
          } catch (_) {/* ignore background errors */}
        });
        return hit.items;
      }
      // else stale → fall through to function
    }

    // 2) Cache miss/hard-stale → callable
    final res = await _fns.httpsCallable('fetchYouTubeData').call(paramsForFn);
    final List<dynamic> raw = (res.data as List?) ?? const [];
    return _toVideoItemsFromAny(raw);
  }

  Future<List<VideoItem>> searchVideos(String query, {int maxResults = 10}) {
    final params = {'type': 'search', 'maxResults': maxResults, 'query': query};
    final key = _cacheKey(params);
    return _fetch(
      cacheCollection: 'ytCache/search',
      cacheKey: key,
      paramsForFn: params,
    );
  }

  Future<List<VideoItem>> getFeaturedVideos() {
    // Fixed doc id for featured cache
    const key = 'featured_videos';
    final params = {'type': 'featured'};
    return _fetch(
      cacheCollection: 'ytCache/playlist',
      cacheKey: key,
      paramsForFn: params,
    );
  }
}

enum _Freshness { fresh, softStale, stale }

class _CacheHit {
  final List<VideoItem> items;
  final _Freshness state;
  _CacheHit(this.items, this.state);
}
