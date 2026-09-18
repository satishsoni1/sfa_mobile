import 'package:flutter/foundation.dart';
import 'package:zforce/features/pod/models/secondary_sales_dashboard_models.dart';
import 'package:zforce/features/pod/services/api_client.dart';
import 'package:zforce/features/pod/services/secondary_sales_stockist_service.dart';

/// Paginates GET /api/secondary-sales/stockists for every logged-in user.
/// Flutter never invents stockists; it only appends Laravel pages.
class SecondarySalesStockistListController extends ChangeNotifier {
  SecondarySalesStockistListController({
    required SecondarySalesStockistService service,
    this.perPage = kSecondarySalesStockistsPerPage,
  }) : _service = service;

  final SecondarySalesStockistService _service;
  final int perPage;

  List<SecondarySalesStockistInfo> stockists = const [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreError;
  int currentPage = 0;
  int lastPage = 1;
  int? nextPage;
  int? total;
  String currentSearch = '';
  int _generation = 0;
  bool _lastFetchWasFullPage = false;

  bool get hasNextPage {
    if (currentPage <= 0) return false;
    if (total != null && stockists.length >= total!) return false;
    if (nextPage != null) return nextPage! > currentPage;
    if (currentPage < lastPage) return true;
    if (_lastFetchWasFullPage && total == null && lastPage <= currentPage) {
      return true;
    }
    return false;
  }

  bool get isInitialLoading =>
      isLoading && stockists.isEmpty && currentSearch.isEmpty;

  void reset() {
    _generation++;
    stockists = const [];
    isLoading = false;
    isLoadingMore = false;
    errorMessage = null;
    loadMoreError = null;
    currentPage = 0;
    lastPage = 1;
    nextPage = null;
    total = null;
    currentSearch = '';
    _lastFetchWasFullPage = false;
    notifyListeners();
  }

  Future<void> refresh({String? authToken, String? search}) {
    if (search != null) {
      currentSearch = search.trim();
    }
    return _fetch(page: 1, replace: true, authToken: authToken);
  }

  Future<void> applySearch(String query, {String? authToken}) {
    currentSearch = query.trim();
    return _fetch(page: 1, replace: true, authToken: authToken);
  }

  Future<void> loadMore({String? authToken}) {
    if (isLoading || isLoadingMore || !hasNextPage) {
      return Future.value();
    }
    return _fetch(page: currentPage + 1, replace: false, authToken: authToken);
  }

  Future<void> retryLoadMore({String? authToken}) {
    loadMoreError = null;
    return loadMore(authToken: authToken);
  }

  Future<void> _fetch({
    required int page,
    required bool replace,
    String? authToken,
  }) async {
    final generation = replace ? ++_generation : _generation;
    final search = currentSearch;

    if (replace) {
      isLoading = true;
      isLoadingMore = false;
      errorMessage = null;
      loadMoreError = null;
      stockists = const [];
      currentPage = 0;
      notifyListeners();
    } else {
      isLoadingMore = true;
      loadMoreError = null;
      notifyListeners();
    }

    try {
      final parsed = await _service.fetchAuthorizedStockistsPage(
        page: page,
        perPage: perPage,
        search: search,
        authToken: authToken,
      );
      if (generation != _generation) return;

      stockists = replace
          ? List<SecondarySalesStockistInfo>.from(parsed.stockists)
          : mergeAuthorizedStockists(stockists, parsed.stockists);
      currentPage = parsed.currentPage;
      lastPage = parsed.lastPage;
      nextPage = parsed.nextPage;
      total = parsed.total;
      _lastFetchWasFullPage = parsed.stockists.length >= perPage;
      errorMessage = null;
      loadMoreError = null;
    } on UnauthorizedException {
      if (generation != _generation) return;
      if (replace) {
        stockists = const [];
        currentPage = 0;
        errorMessage = null;
      }
      rethrow;
    } on SecondarySalesStockistException catch (e) {
      if (generation != _generation) return;
      if (replace) {
        stockists = const [];
        currentPage = 0;
        errorMessage = e.message;
      } else {
        loadMoreError = e.message;
      }
    } finally {
      if (generation == _generation) {
        isLoading = false;
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }
}
