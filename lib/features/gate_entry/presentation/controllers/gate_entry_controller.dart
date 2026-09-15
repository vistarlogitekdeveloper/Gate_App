import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/gate_entry.dart';
import '../../domain/models/gate_entry_summary.dart';
import '../../domain/models/gate_entry_query.dart';
import '../../domain/usecases/get_gate_entries_usecase.dart';
import '../../domain/usecases/create_gate_entry_usecase.dart';
import '../../domain/usecases/gate_entry_actions_usecase.dart';
import '../../domain/usecases/gate_out_usecase.dart';
import '../../data/dto/create_gate_entry_request.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/pagination_model.dart';

const _queryNotProvided = Object();

class GateEntryState {
  final bool isLoading;
  final String? error;
  final List<GateEntry> entries;
  final GateEntrySummary summary;
  final PaginationModel? pagination;
  final GateEntryQuery? activeQuery;

  GateEntryState({
    this.isLoading = false,
    this.error,
    this.entries = const [],
    this.summary = const GateEntrySummary(),
    this.pagination,
    this.activeQuery,
  });

  GateEntryState copyWith({
    bool? isLoading,
    String? error,
    List<GateEntry>? entries,
    GateEntrySummary? summary,
    Object? pagination = _queryNotProvided,
    Object? activeQuery = _queryNotProvided,
  }) {
    return GateEntryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      entries: entries ?? this.entries,
      summary: summary ?? this.summary,
      pagination: identical(pagination, _queryNotProvided)
          ? this.pagination
          : pagination as PaginationModel?,
      activeQuery: identical(activeQuery, _queryNotProvided)
          ? this.activeQuery
          : activeQuery as GateEntryQuery?,
    );
  }
}

final gateEntryControllerProvider =
    StateNotifierProvider<GateEntryController, GateEntryState>((ref) {
  return GateEntryController(
    ref: ref,
    getGateEntriesUseCase: ref.read(getGateEntriesUseCaseProvider),
    createGateEntryUseCase: ref.read(createGateEntryUseCaseProvider),
    verifyGateEntryUseCase: ref.read(verifyGateEntryUseCaseProvider),
    approveGateEntryUseCase: ref.read(approveGateEntryUseCaseProvider),
    closeGateEntryUseCase: ref.read(closeGateEntryUseCaseProvider),
    gateOutUseCase: ref.read(gateOutUseCaseProvider),
  );
});

class GateEntryController extends StateNotifier<GateEntryState> {
  final GetGateEntriesUseCase _getGateEntriesUseCase;
  final CreateGateEntryUseCase _createGateEntryUseCase;
  final VerifyGateEntryUseCase _verifyGateEntryUseCase;
  final ApproveGateEntryUseCase _approveGateEntryUseCase;
  final CloseGateEntryUseCase _closeGateEntryUseCase;
  final GateOutUseCase _gateOutUseCase;

  GateEntryController({
    required Ref ref,
    required GetGateEntriesUseCase getGateEntriesUseCase,
    required CreateGateEntryUseCase createGateEntryUseCase,
    required VerifyGateEntryUseCase verifyGateEntryUseCase,
    required ApproveGateEntryUseCase approveGateEntryUseCase,
    required CloseGateEntryUseCase closeGateEntryUseCase,
    required GateOutUseCase gateOutUseCase,
  })  : _getGateEntriesUseCase = getGateEntriesUseCase,
        _createGateEntryUseCase = createGateEntryUseCase,
        _verifyGateEntryUseCase = verifyGateEntryUseCase,
        _approveGateEntryUseCase = approveGateEntryUseCase,
        _closeGateEntryUseCase = closeGateEntryUseCase,
        _gateOutUseCase = gateOutUseCase,
        super(GateEntryState());

  /// Per-request page size when a search is fanned across `q` + `vendor`.
  /// The server caps `limit` at 100, so pages beyond page 1 are pulled in a
  /// loop by [searchEntries] to collect every match — this constant is now
  /// only the per-request batch size, not a cap on total results returned.
  static const int searchResultLimit = 100;

  /// Cap search fan-out to a handful of pages per fan (q + vendor). Previously
  /// this was 200 (20k rows/term), which pinned the main isolate on
  /// `.fromJson` for many seconds on slow gate WiFi and was reported as
  /// day-to-day slowness. Five pages × two fans × 100 rows = up to 1000 rows
  /// per search — enough for any realistic dispatch/vendor query. Users who
  /// need more should filter by date or add more terms.
  static const int _searchMaxPages = 5;

  /// Monotonic token so a slow in-flight request can't clobber a newer one.
  int _requestSeq = 0;

  Future<void> fetchEntries(
      {Object? query = _queryNotProvided,
      int? page,
      int? limit,
      bool? usePagination,
      bool refresh = false}) async {
    final baseQuery = identical(query, _queryNotProvided)
        ? state.activeQuery
        : query as GateEntryQuery?;
    final shouldPaginate = usePagination ?? true;
    final effectiveQuery = shouldPaginate
        ? (baseQuery ?? const GateEntryQuery()).copyWith(
            page: refresh ? 1 : (page ?? baseQuery?.page ?? state.pagination?.page ?? 1),
            limit: _normalizeLimit(limit ?? baseQuery?.limit ?? state.pagination?.limit ?? 20),
          )
        : (baseQuery ?? const GateEntryQuery()).copyWith(
            page: null,
            limit: null,
          );

    final seq = ++_requestSeq;
    state = state.copyWith(isLoading: true, error: null);

    final response = await _getGateEntriesUseCase.execute(query: effectiveQuery);

    // Discard if a newer request superseded this one while it was in flight.
    if (seq != _requestSeq) return;

    if (response.success && response.data != null) {
      state = state.copyWith(
        isLoading: false,
        entries: response.data!.items,
        summary: response.data!.summary,
        pagination: response.data!.pagination,
        activeQuery: effectiveQuery,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.message,
      );
    }
  }

  /// Searches gate entries by a free-text [term].
  ///
  /// The backend's `q` parameter matches challan / LR / vehicle but NOT the
  /// vendor, so a single `q` request silently drops vendor matches. To make
  /// "search by vendor" work without loading the entire (paginated) dataset
  /// client-side, this fans the term out to two parallel requests — one using
  /// `q`, one using the dedicated `vendor` filter the API already supports —
  /// and merges the results, de-duplicating by entry id. Passing them as a
  /// single request is unsafe because the server ANDs the two filters.
  Future<void> searchEntries(String term, {String? period}) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) {
      // Nothing to search — restore the normal paginated list for the filter.
      await fetchEntries(
        query: period != null
            ? GateEntryQuery(period: period)
            : const GateEntryQuery(),
        page: 1,
      );
      return;
    }

    final seq = ++_requestSeq;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Walk *every* page of both q-search and vendor-search so a user
      // searching for e.g. a vendor with 300 entries actually sees all 300,
      // not just the first 100. The two fans still run in parallel; each
      // fan pages internally.
      final results = await Future.wait([
        _fetchAllPages(
          (page) => GateEntryQuery(
            q: trimmed,
            period: period,
            page: page,
            limit: searchResultLimit,
          ),
          seq: seq,
        ),
        _fetchAllPages(
          (page) => GateEntryQuery(
            vendor: trimmed,
            period: period,
            page: page,
            limit: searchResultLimit,
          ),
          seq: seq,
        ),
      ]);

      // A newer request was dispatched while these were in flight — discard
      // this stale result so it can't clobber the newer state / null pagination.
      if (seq != _requestSeq) return;

      final qResult = results[0];
      final vendorResult = results[1];

      if (qResult.error != null && vendorResult.error != null) {
        state = state.copyWith(
          isLoading: false,
          error: qResult.error!.isNotEmpty
              ? qResult.error
              : (vendorResult.error!.isNotEmpty
                  ? vendorResult.error
                  : 'Search failed'),
        );
        return;
      }

      final merged = <String, GateEntry>{};

      // `q` results matched challan / LR / vehicle server-side — keep all,
      // preserving server order (inserted first; putIfAbsent keeps the first).
      for (final entry in qResult.items) {
        merged.putIfAbsent(_entryKey(entry), () => entry);
      }

      // `vendor` results: guard against a backend that exact-matches or ignores
      // an unrecognized value (and returns unfiltered rows) by keeping only
      // genuine vendor matches. If the backend already filtered, this is a
      // no-op.
      final lowerTerm = trimmed.toLowerCase();
      for (final entry in vendorResult.items) {
        if (entry.vendorName.toLowerCase().contains(lowerTerm) ||
            entry.vendorCode.toLowerCase().contains(lowerTerm)) {
          merged.putIfAbsent(_entryKey(entry), () => entry);
        }
      }

      state = state.copyWith(
        isLoading: false,
        entries: merged.values.toList(),
        // Results span multiple requests, so server pagination no longer applies.
        pagination: null,
        activeQuery: GateEntryQuery(q: trimmed, period: period),
        error: null,
      );
    } catch (_) {
      if (seq != _requestSeq) return;
      state = state.copyWith(isLoading: false, error: 'Search failed');
    }
  }

  Future<_SearchFanResult> _fetchAllPages(
    GateEntryQuery Function(int page) queryFor, {
    required int seq,
  }) async {
    final collected = <GateEntry>[];
    String? lastError;
    var page = 1;

    while (page <= _searchMaxPages) {
      // Abort early if a newer search superseded us — don't waste requests.
      if (seq != _requestSeq) break;

      final response =
          await _getGateEntriesUseCase.execute(query: queryFor(page));

      if (!response.success || response.data == null) {
        // Remember the failure but stop paging so we don't hammer a broken
        // endpoint. Partial results (from earlier successful pages) are
        // still returned.
        lastError = response.message;
        break;
      }

      final items = response.data!.items;
      collected.addAll(items);

      final pagination = response.data!.pagination;
      if (pagination == null) {
        // Server returned everything in one shot.
        break;
      }
      if (!pagination.hasNext || page >= pagination.totalPages) {
        break;
      }
      if (items.isEmpty) {
        // Defensive: paginator says "more" but page is empty — bail out.
        break;
      }
      page += 1;
    }

    return _SearchFanResult(items: collected, error: lastError);
  }

  String _entryKey(GateEntry entry) => entry.id.isNotEmpty
      ? entry.id
      : '${entry.gateEntryNo}|${entry.challanNo}';

  void showAllEntries() {
    fetchEntries(query: null, usePagination: false);
  }

  Future<GateEntry?> createEntry(CreateGateEntryRequest request) async {
    state = state.copyWith(isLoading: true, error: null);

    final response = await _createGateEntryUseCase.execute(request);

    if (response.success && response.data != null) {
      _scheduleBackgroundRefresh();
      return response.data!;
    } else {
      state = state.copyWith(isLoading: false, error: response.message);
      return null;
    }
  }

  Future<bool> verifyEntry(String id) async {
    return _handleActionVoid(
        _verifyGateEntryUseCase.execute(id), id);
  }

  Future<bool> approveEntry(String id) async {
    return _handleActionVoid(
        _approveGateEntryUseCase.execute(id), id);
  }

  Future<bool> closeEntry(String id) async {
    return _handleActionVoid(_closeGateEntryUseCase.execute(id), id);
  }

  Future<bool> gateOutEntry(String id, {String? remarks}) async {
    state = state.copyWith(isLoading: true, error: null);
    final response = await _gateOutUseCase.execute(id, remarks: remarks);

    if (response.success) {
      _scheduleBackgroundRefresh();
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: response.message);
      return false;
    }
  }

  Future<bool> _handleActionVoid(
      Future<ApiResponse<void>> action, String id) async {
    state = state.copyWith(isLoading: true, error: null);
    final response = await action;

    if (response.success) {
      _scheduleBackgroundRefresh();
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: response.message);
      return false;
    }
  }

  void _scheduleBackgroundRefresh() {
    state = state.copyWith(isLoading: false, error: null);
    Future.microtask(() async {
      try {
        await fetchEntries(refresh: true);
      } catch (_) {
        // background refresh is best-effort
      }
    });
  }

  int _normalizeLimit(int value) {
    if (value < 1) return 20;
    if (value > 100) return 100;
    return value;
  }
}

class _SearchFanResult {
  final List<GateEntry> items;
  final String? error;

  const _SearchFanResult({required this.items, this.error});
}
