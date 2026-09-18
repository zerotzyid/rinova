import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:animestream/core/anime/providers/animeProvider.dart';
import 'package:animestream/core/anime/providers/types.dart';

class RinovaApiProvider extends AnimeProvider {
  static const String baseUrl = "https://anime-web-azure.vercel.app/api";

  @override
  final String providerName = "rinova";

  @override
  Future<List<Map<String, String>>> search(String query) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/search?q=$query'));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      final List<dynamic> results = json['data'] ?? [];
      return results.map((item) => {
        'name': item['title'] as String,
        'alias': item['slug'] as String,
        'imageUrl': item['thumbnail'] as String,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAnimeEpisodeLink(String aliasId, {bool dub = false}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/anime/$aliasId'));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      final List<dynamic> eps = json['data']['episodes'] ?? [];
      return eps.map((ep) => {
        'episodeLink': aliasId,
        'episodeNumber': ep as int,
        'episodeTitle': 'Episode $ep',
        'isFiller': false,
        'metadata': ep.toString(),
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> getStreams(String epLink, Function(List<VideoStream> list, bool isFinished) update, {bool dub = false, String? metadata}) async {
    try {
      final epNum = int.parse(metadata ?? '1');
      final res = await http.get(Uri.parse('$baseUrl/anime/$epLink/streams?episode=$epNum'));
      if (res.statusCode != 200) return update([], true);
      final json = jsonDecode(res.body);
      final List<dynamic> servers = json['data']['servers'] ?? [];
      final streams = servers.map((s) => VideoStream(
        quality: "Auto",
        url: s['url'],
        server: s['server'],
        backup: false,
      )).toList();
      update(streams, true);
    } catch (e) {
      update([], true);
    }
  }

  @override
  Future<void> getDownloadSources(String episodeUrl, Function(List<VideoStream> p1, bool p2) update, {bool dub = false, String? metadata}) {
    throw UnimplementedError();
  }
}