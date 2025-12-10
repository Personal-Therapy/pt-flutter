import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class YoutubeService {
  final String apiKey = dotenv.env['YOUTUBE_API_KEY'] ?? '';
  static final Map<String, List<Map<String, String>>> _cache = {};
  //확장 static const Duration cacheDuration = Duration(hours: 1);

  Future<List<Map<String, String>>> fetchByKeyword(
      String query,
      {String regionCode = 'KR', String? categoryId}
      ) async {
    if (apiKey.isEmpty) {
      if (kDebugMode) {
        print('YOUTUBE_API_KEY is not set in .env file');
      }
      throw Exception('YOUTUBE_API_KEY is not set');
    }
    
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'youtube_cache_$query';
    //final timeKey = '${cacheKey}_timestamp';

    if (_cache.containsKey(query)) {
      if (kDebugMode) print('[MEM CACHE] $query');
      return _cache[query]!;
    }

    final local = prefs.getString(cacheKey);
    //final lastSaved = prefs.getInt(timeKey);

    if (local != null) {
      try {
        if (kDebugMode) print('[DISK CACHE] $query');
        final decoded = jsonDecode(local) as List;
        final parsed = decoded.map((item) {
          final map = item as Map<String, dynamic>;
          return map.map((key, value) => MapEntry(key, value.toString()));
        }).toList();
        _cache[query] = parsed;
        return parsed;
      } catch (e) {
        if (kDebugMode) print('[CACHE PARSE ERROR] $e - clearing cache');
        await prefs.remove(cacheKey);
      }
    }
    //if (local != null && lastSaved != null) {
    //       final elapsed = DateTime.now().millisecondsSinceEpoch - lastSaved;
    //       if (elapsed < cacheDuration.inMilliseconds) {
    //         // 캐시가 아직 유효함
    //         if (kDebugMode) print('[DISK CACHE - VALID] $query');
    //         final parsed = List<Map<String, String>>.from(jsonDecode(local));
    //         _cache[query] = parsed;
    //         return parsed;
    //       } else {
    //         // 캐시 만료됨
    //         if (kDebugMode) print('[DISK CACHE - EXPIRED] $query (fetch new data)');
    //       }
    //     }


    if (kDebugMode) print('[API CALL] $query');
    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
          '?part=snippet&type=video&maxResults=10&regionCode=KR'
          '&q=$query&key=$apiKey',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode != 200) {
        if (kDebugMode) {
          print('YouTube API Error:');
          print('Status Code: ${res.statusCode}');
          print('Response Body: ${res.body}');
        }
        throw Exception('YouTube API returned status ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body);
      final items = data['items'] as List;
      final result = items
          .where((item) => item['id']['videoId'] != null)
          .map((item) {
        final id = item['id']['videoId']?.toString() ?? '';
        final snippet = item['snippet'];
        return {
          'id': id,
          'title': snippet['title']?.toString() ?? '',
          'desc': snippet['description']?.toString() ?? '',
          'thumb': snippet['thumbnails']?['high']?['url']?.toString() ?? '',
        };
      }).toList();


      _cache[query] = result;
      await prefs.setString(cacheKey, jsonEncode(result));
      //await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);

      // if (kDebugMode) print('[CACHE UPDATED] $query at ${DateTime.now()}');
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error during youtube fetch: $e');
      }
      rethrow;
    }
  }
}