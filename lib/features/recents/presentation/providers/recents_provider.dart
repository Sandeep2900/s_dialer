import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/call_log_item.dart';
import '../../../../data/repositories/call_log_repository.dart';

class RecentsState {
  final List<CallLogItem> allLogs;
  final List<CallLogItem> filteredLogs;
  final Set<String> selectedIds;
  final bool isMultiSelectMode;
  final int filterIndex; // 0 = All, 1 = Missed
  final String searchQuery;
  final bool isLoading;

  const RecentsState({
    this.allLogs = const [],
    this.filteredLogs = const [],
    this.selectedIds = const {},
    this.isMultiSelectMode = false,
    this.filterIndex = 0,
    this.searchQuery = '',
    this.isLoading = false,
  });

  RecentsState copyWith({
    List<CallLogItem>? allLogs,
    List<CallLogItem>? filteredLogs,
    Set<String>? selectedIds,
    bool? isMultiSelectMode,
    int? filterIndex,
    String? searchQuery,
    bool? isLoading,
  }) {
    return RecentsState(
      allLogs: allLogs ?? this.allLogs,
      filteredLogs: filteredLogs ?? this.filteredLogs,
      selectedIds: selectedIds ?? this.selectedIds,
      isMultiSelectMode: isMultiSelectMode ?? this.isMultiSelectMode,
      filterIndex: filterIndex ?? this.filterIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RecentsNotifier extends StateNotifier<RecentsState> {
  final Ref _ref;

  RecentsNotifier(this._ref) : super(const RecentsState()) {
    Future.microtask(() => loadLogs());
  }

  Future<void> loadLogs({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true);
    final repo = _ref.read(callLogRepositoryProvider);
    final logs = await repo.fetchCallLogs(forceRefresh: forceRefresh);
    _applyFilters(logs, state.filterIndex, state.searchQuery);
  }

  void setFilter(int index) {
    _applyFilters(state.allLogs, index, state.searchQuery);
  }

  void search(String query) {
    _applyFilters(state.allLogs, state.filterIndex, query);
  }

  void enterMultiSelect(String id) {
    state = state.copyWith(
      isMultiSelectMode: true,
      selectedIds: {id},
    );
  }

  void toggleSelect(String id) {
    final updated = Set<String>.from(state.selectedIds);
    if (updated.contains(id)) {
      updated.remove(id);
      if (updated.isEmpty) {
        state = state.copyWith(isMultiSelectMode: false, selectedIds: {});
        return;
      }
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedIds: updated);
  }

  void selectAll() {
    final allIds = state.filteredLogs.map((l) => l.id).toSet();
    state = state.copyWith(selectedIds: allIds);
  }

  void exitMultiSelect() {
    state = state.copyWith(isMultiSelectMode: false, selectedIds: {});
  }

  void deleteSelected() {
    _ref.read(callLogRepositoryProvider).deleteCalls(state.selectedIds);
    final remaining = state.allLogs.where((l) => !state.selectedIds.contains(l.id)).toList();
    state = state.copyWith(isMultiSelectMode: false, selectedIds: {});
    _applyFilters(remaining, state.filterIndex, state.searchQuery);
  }

  void deleteLog(String id) {
    _ref.read(callLogRepositoryProvider).deleteCall(id);
    final remaining = state.allLogs.where((l) => l.id != id).toList();
    _applyFilters(remaining, state.filterIndex, state.searchQuery);
  }

  void _applyFilters(List<CallLogItem> logs, int filterIndex, String query) {
    var result = List<CallLogItem>.from(logs);

    // Filter All vs Missed
    if (filterIndex == 1) {
      result = result.where((l) => l.type == CallType.missed).toList();
    }

    // Filter by search query
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      result = result.where((l) {
        final matchesName = l.name?.toLowerCase().contains(q) ?? false;
        final matchesNumber = l.number.contains(q);
        return matchesName || matchesNumber;
      }).toList();
    }

    state = state.copyWith(
      allLogs: logs,
      filteredLogs: result,
      filterIndex: filterIndex,
      searchQuery: query,
      isLoading: false,
    );
  }
}

final recentsProvider = StateNotifierProvider<RecentsNotifier, RecentsState>((ref) {
  return RecentsNotifier(ref);
});
