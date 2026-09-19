import 'package:animestream/core/anime/providers/rinova_api.dart';
import 'package:animestream/core/anime/providers/animeProvider.dart';
import 'package:animestream/core/anime/providers/providerDetails.dart';
import 'package:animestream/core/anime/providers/types.dart';
import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:flutter/material.dart';

/// Singleton — hanya mengelola sumber/provider
class SourceManager {
  SourceManager._();

  static final SourceManager instance = SourceManager._();

  final List<ProviderDetails> inbuiltSources = [
    "Rinova",
  ].map((e) => ProviderDetails(
        name: e,
        identifier: e.toLowerCase() + "_inbuilt",
        version: "0.0.0.0",
        supportDownloads: false,
      )).toList();

  bool _useInbuiltProviders = true;
  bool get useInbuiltProviders => _useInbuiltProviders;
  set useInbuiltProviders(bool val) => _useInbuiltProviders = val;

  final List<ProviderDetails> _sources = [];
  final _plugin = _EmptyPlugin();

  List<ProviderDetails> get sources => _sources;

  void addSource(ProviderDetails source) => _sources.add(source);
  void addSources(List<ProviderDetails> sources) => _sources.addAll(sources);
  void removeSource(String identifier) => _sources.removeWhere((e) => e.identifier == identifier);

  Future<void> loadProviders({bool clearBeforeLoading = true}) async {
    if (clearBeforeLoading) _sources.clear();
    _sources.addAll(inbuiltSources);
  }

  Future<List<Map<String, String?>>> searchInSource(String source, String query) async {
    final provider = getClass(source);
    return provider.search(query);
  }

  Future<List<EpisodeDetails>> getAnimeEpisodes(String source, String link, {bool dub = false}) async {
    final info = await getClass(source).getAnimeEpisodeLink(link, dub: dub);
    return info.map((e) => EpisodeDetails.fromMap(e)).toList();
  }

  Future<void> getDownloadSources(String source, String episodeUrl, Function(List<VideoStream>, bool) updateFunction,
      {bool dub = false, String? metadata}) async {
    await getClass(source).getDownloadSources(episodeUrl, updateFunction, dub: dub, metadata: metadata);
  }

  Future<void> getStreams(String source, String episodeId, void Function(List<VideoStream>, bool) updateFunction,
      {bool dub = false, String? metadata}) async {
    await getClass(source).getStreams(episodeId, updateFunction, dub: dub, metadata: metadata);
  }

  Future<AnimeProvider> _getProvider(String identifier) async {
    final provider = getClass(identifier);
    if (provider == null) throw Exception("$identifier Provider doesnt exist!");
    return provider;
  }

  AnimeProvider getClass(String source) {
    final match = sources.map((s) => s.identifier).contains(source)
        ? sources.firstWhere((s) => s.identifier == source)
        : null;
    if (match != null) return RinovaApiProvider();
    throw Exception("Invalid Source!");
  }
}

class _EmptyPlugin {
  Future<AnimeProvider?> getProvider(String provider, {String? testCode}) async => null;
}

final Map<String, AnimeProvider> sources = {
  "rinova": RinovaApiProvider(),
};

AnimeProvider getClass(String source) {
  final match = sources[source.replaceAll("_inbuilt", "")];
  if (match == null) throw Exception("Invalid Source!");
  return match;
}

List<DropdownMenuEntry> getSourceDropdownList() {
  List<DropdownMenuEntry> widget = [];
  final sources = SourceManager.instance.sources;
  for (final source in sources) {
    widget.add(
      DropdownMenuEntry(
        value: source,
        label: "${source.name}${source.version == "0.0.0.0" ? "" : " [Plugin]"}",
        trailingIcon:
            source.identifier == currentUserSettings?.preferredProvider ? Icon(Icons.star_border_rounded) : null,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(appTheme.textMainColor),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              color: appTheme.textMainColor,
              fontFamily: "Rubik",
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
  return widget;
}