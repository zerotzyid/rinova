import 'dart:io';

import 'package:animestream/core/app/logging.dart';
import 'package:animestream/core/app/runtimeDatas.dart';
import 'package:animestream/core/commons/enums.dart';
import 'package:animestream/core/commons/enums/loadingState.dart';
import 'package:animestream/core/commons/types.dart';
import 'package:animestream/core/data/watching.dart';
import 'package:animestream/core/database/anilist/login.dart';
import 'package:animestream/core/database/anilist/queries.dart';
import 'package:animestream/core/database/anilist/types.dart';
import 'package:animestream/core/anime/providers/rinova_api.dart';
import 'package:animestream/ui/models/sources.dart';
import 'package:animestream/ui/models/snackBar.dart';
import 'package:animestream/ui/models/widgets/cards.dart';
import 'package:flutter/widgets.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class MainNavProvider extends ChangeNotifier {
  bool _isAndroid = Platform.isAndroid;
  bool get isAndroid => _isAndroid;

  bool _tv = false;
  bool get tv => _tv;
  set tv(bool value) {
    _tv = value;
    notifyListeners();
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  set loggedIn(bool value) {
    _loggedIn = value;
    notifyListeners();
  }

  UserModal? _userProfile;
  UserModal? get userProfile => _userProfile;
  set userProfile(UserModal? user) {
    _userProfile = user;
    notifyListeners();
  }

  // Home items — dari REST API
  AnimeListData<HomePageList> _currentlyAiring = AnimeListData(title: "Sedang Tayang");
  AnimeListData<HomePageList> _recentlyWatched = AnimeListData(title: "Lanjutkan Menonton");
  AnimeListData<HomePageList> _plannedList = AnimeListData(title: "Daftar Tonton");

  // Discover items — dari REST API
  List<AnimeCard> _latestList = [];
  List<AnimeCard> _recommendedList = [];
  List<AnimeCard> _recentlyUpdatedList = [];
  List<AnimeCard> _thisSeason = [];

  List<RecentlyUpdatedResult> _recentlyUpdatedListData = [];
  List<CurrentlyAiringResult> _thisSeasonData = [];

  bool _discoverDataLoaded = false;
  bool get discoverDataLoaded => _discoverDataLoaded;
  set discoverDataLoaded(bool value) {
    _discoverDataLoaded = value;
    notifyListeners();
  }

  // Home items
  AnimeListData<HomePageList> get currentlyAiring => _currentlyAiring;
  set currentlyAiring(AnimeListData<HomePageList> value) {
    _currentlyAiring = value;
    notifyListeners();
  }

  AnimeListData<HomePageList> get recentlyWatched => _recentlyWatched;
  set recentlyWatched(AnimeListData<HomePageList> value) {
    _recentlyWatched = value;
    notifyListeners();
  }

  AnimeListData<HomePageList> get plannedList => _plannedList;
  set plannedList(AnimeListData<HomePageList> value) {
    _plannedList = value;
    notifyListeners();
  }

  List<AnimeCard> get latestList => _latestList;
  set latestList(List<AnimeCard> value) {
    _latestList = value;
    notifyListeners();
  }

  List<AnimeCard> get recommendedList => _recommendedList;
  set recommendedList(List<AnimeCard> value) {
    _recommendedList = value;
    notifyListeners();
  }

  List<RecentlyUpdatedResult> get recentlyUpdatedListData => _recentlyUpdatedListData;

  List<AnimeCard> get thisSeason => _thisSeason;
  set thisSeason(List<AnimeCard> value) {
    _thisSeason = value;
    notifyListeners();
  }

  List<CurrentlyAiringResult> get thisSeasonData => _thisSeasonData;

  // Methods

  Future<void> init() async {
    if (!(await isConnectedToInternet())) {
      floatingSnackBar("Anda offline. Sambungkan internet dan coba lagi.", waitForPreviousToFinish: true);
      currentlyAiring.state = LoadingState.error;
      recentlyWatched.state = LoadingState.error;
      plannedList.state = LoadingState.error;
      return notifyListeners();
    }
    loggedIn = await AniListLogin().isAnilistLoggedIn();
    if (loggedIn) {
      AniListLogin()
          .getUserProfile()
          .then((user) {
        _userProfile = user;
        storedUserData = user;
        Logs.app.log("[AUTHENTICATION] ${storedUserData?.name} Login Successful");
        loadListsForHome(userName: user.name);
      }).catchError((err) async {
        if (err is AnilistApiException &&
            (err.isUnauthorized || err.message.toLowerCase().contains("invalid token"))) {
          floatingSnackBar("Token AniList tidak valid. Login lagi!");
          await AniListLogin().removeToken();
          loggedIn = false;
          userProfile = null;
        } else {
          floatingSnackBar("tidak bisa load profile pengguna");
        }
        loadListsForHome();
        return <void>{};
      });
    } else {
      loadListsForHome();
    }
  }

  Future<bool> isConnectedToInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Fetch latest anime dari REST API
  Future<void> getLatestList() async {
    try {
      final provider = SourceManager.instance.sources.isNotEmpty
          ? SourceManager.instance.sources.first
          : null;
      if (provider == null) return;
      final rinova = RinovaApiProvider();
      final list = await rinova.getLatest(page: 1);
      _latestList = [];
      for (final item in list) {
        _latestList.add(
          Cards.animeCard(
            0,
            item['title'] as String,
            item['thumbnail'] as String,
            rating: double.tryParse(item['rating']?.toString() ?? '0') ?? 0,
            isMobile: !tv && isAndroid,
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      Logs.app.log("Error fetching latest list: $e");
    }
  }

  void updateWatchedList(List<HomePageList> watchedList) {
    _recentlyWatched.items = watchedList;
    notifyListeners();
  }

  Future<void> loadListsForHome({String? userName}) async {
    currentlyAiring.state = LoadingState.loading;
    recentlyWatched.state = LoadingState.loading;
    plannedList.state = LoadingState.loading;

    // Fetch home data dari REST API
    final rinova = RinovaApiProvider();
    final homeData = await rinova.getHome().onError((e, st) {
      currentlyAiring.state = LoadingState.error;
      recentlyWatched.state = LoadingState.error;
      plannedList.state = LoadingState.error;
      Logs.app.log("Error fetching home data: $e");
      return <Map<String, dynamic>>[];
    });

    notifyListeners();

    if (homeData.isEmpty) return;

    currentlyAiring.items = [];
    _thisSeasonData = [];
    for (final item in homeData) {
      currentlyAiring.items.add(
        HomePageList(
          coverImage: item['thumbnail'] as String,
          id: 0,
          rating: double.tryParse(item['rating']?.toString() ?? '0') ?? 0,
          title: {
            'english': item['title'] as String,
            'romaji': item['title'] as String,
          },
          totalEpisodes: int.tryParse(item['episode']?.toString() ?? '0') ?? 0,
          watchedEpisodeCount: 0,
        ),
      );
      currentlyAiring.state = LoadingState.loaded;

      _thisSeasonData.add(CurrentlyAiringResult(
        id: 0,
        title: {'english': item['title'] as String, 'romaji': item['title'] as String},
        cover: item['thumbnail'] as String,
        rating: double.tryParse(item['rating']?.toString() ?? '0') ?? 0,
        episodes: int.tryParse(item['episode']?.toString() ?? '0') ?? 0,
        watchProgress: 0,
      ));

      thisSeason.add(
        Cards.animeCard(
          0,
          item['title'] as String,
          item['thumbnail'] as String,
          rating: double.tryParse(item['rating']?.toString() ?? '0') ?? 0,
        ),
      );
    }

    if (userName != null) {
      try {
        final planning = await AnilistQueries().getUserAnimeList(userName, status: MediaStatus.PLANNING);
        if (planning.isNotEmpty) {
          plannedList.items = [];
          List<UserAnimeListItem> itemList = planning[0].list;
          if (itemList.length > 25) itemList = itemList.sublist(0, 25);
          itemList.forEach((item) {
            plannedList.items.add(HomePageList(
              coverImage: item.coverImage,
              rating: item.rating,
              title: item.title,
              id: item.id,
              totalEpisodes: item.episodes,
              watchedEpisodeCount: item.watchProgress,
            ));
          });
          plannedList.state = LoadingState.loaded;
        }
      } catch (e) {
        Logs.app.log("Error fetching planned list: $e");
      }
    }

    if (currentlyAiring.state.isError && recentlyWatched.state.isError) {
      if (currentUserSettings?.showErrors ?? false)
        floatingSnackBar("Tidak bisa load data home.", waitForPreviousToFinish: true);
    }

    notifyListeners();
  }

  Future<void> loadDiscoverItems() async {
    try {
      await getLatestList();
      discoverDataLoaded = true;
    } catch (e) {
      Logs.app.log("Error loading discover items: $e");
      discoverDataLoaded = false;
      if (currentUserSettings!.showErrors != null && currentUserSettings!.showErrors!)
        floatingSnackBar(e.toString(), waitForPreviousToFinish: true);
    }
  }

  RefreshController homeRefreshController = RefreshController(initialRefresh: false);
  RefreshController discoverRefreshController = RefreshController(initialRefresh: false);

  void refreshTree() {
    notifyListeners();
  }

  Future<void> refresh({required int refreshPage, bool fromSettings = false}) async {
    if (refreshPage != 0 && refreshPage != 1) return;

    if (!(await isConnectedToInternet())) {
      floatingSnackBar("Anda offline. Sambungkan internet dan coba lagi.", waitForPreviousToFinish: true);
      currentlyAiring.state = LoadingState.error;
      recentlyWatched.state = LoadingState.error;
      plannedList.state = LoadingState.error;
      return refreshPage == 0 ? homeRefreshController.refreshCompleted() : discoverRefreshController.refreshCompleted();
    }

    if (refreshPage == 1) {
      await loadDiscoverItems();
      discoverRefreshController.refreshCompleted();
      notifyListeners();
      return;
    }

    loggedIn = await AniListLogin().isAnilistLoggedIn();
    if (loggedIn && userProfile == null) {
      userProfile = await AniListLogin().getUserProfile();
      storedUserData = userProfile;
      Logs.app.log("[AUTHENTICATION] ${storedUserData?.name} Login Successful");
      await loadListsForHome(userName: userProfile!.name);
    } else if (loggedIn && userProfile != null) {
      if (fromSettings) return;
      await loadListsForHome(userName: userProfile!.name);
    } else {
      await loadListsForHome();
      userProfile = null;
    }
    homeRefreshController.refreshCompleted();
    notifyListeners();
  }
}

class AnimeListData<T> {
  String? title;
  List<T> items;
  LoadingState state;

  AnimeListData({
    this.title,
    this.items = const [],
    this.state = LoadingState.loading,
  });
}