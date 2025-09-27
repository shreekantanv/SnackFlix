import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:snackflix/models/video_item.dart';

class YouTubeService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  YouTubeService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  // Generates a deterministic SHA-1 hash for a given query map.
  String _getCacheKey(Map<String, dynamic> params) {
    final normalized = json.encode(Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ));
    return sha1.convert(utf8.encode(normalized)).toString();
  }

  // Generic function to fetch data from Firestore cache or Cloud Function
  Future<List<VideoItem>> _fetchData({
    required String cacheCollection,
    required String cacheKey,
    required Map<String, dynamic> functionParams,
  }) async {
    final docRef = _firestore.collection(cacheCollection).doc(cacheKey);

    // 1. Attempt to read from Firestore cache
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final data = snapshot.data()!;
      final updatedAt = (data['updatedAt'] as Timestamp).toDate();
      final ttl = Duration(seconds: data['ttlSec'] as int);

      // 2. Check if cache is fresh
      if (DateTime.now().isBefore(updatedAt.add(ttl))) {
        final List<dynamic> videoData = data['data'];
        return videoData
            .map((item) => VideoItem.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    }

    // 3. On cache miss or stale, call the Cloud Function
    final callable = _functions.httpsCallable('fetchYouTubeData');
    final result = await callable.call(functionParams);

    final List<dynamic> videoData = result.data;
    return videoData
        .map((item) => VideoItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VideoItem>> searchVideos(String query) {
    final params = {'type': 'search', 'query': query, 'maxResults': 10};
    return _fetchData(
      cacheCollection: 'ytCache/search',
      cacheKey: _getCacheKey(params),
      functionParams: params,
    );
  }

  Future<List<VideoItem>> getFeaturedVideos() {
    final params = {'type': 'featured'};
    return _fetchData(
      cacheCollection: 'ytCache/playlist',
      cacheKey: 'featured_videos', // Fixed key for featured content
      functionParams: params,
    );
  }
}