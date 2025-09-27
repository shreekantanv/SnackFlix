import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:snackflix/models/video_item.dart';

// IMPORTANT: Replace with your actual YouTube Data API key
const _apiKey = 'YOUR_YOUTUBE_API_KEY';

class YouTubeService {
  final http.Client _client;
  final String _apiKey;

  YouTubeService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ??
            const String.fromEnvironment(
              'YOUTUBE_API_KEY',
              defaultValue: _apiKey,
            );

  Future<List<VideoItem>> searchVideos(String query) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_YOUTUBE_API_KEY') {
      throw Exception('YouTube API key is missing or is a placeholder.');
    }

    final url = Uri.https('www.googleapis.com', '/youtube/v3/search', {
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': '10',
      'key': _apiKey,
    });

    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List;
      return items.map((item) {
        final snippet = item['snippet'];
        return VideoItem(
          id: item['id']['videoId'],
          title: snippet['title'],
          thumbnailUrl: snippet['thumbnails']['high']['url'],
        );
      }).toList();
    } else {
      throw Exception('Failed to search videos');
    }
  }
}