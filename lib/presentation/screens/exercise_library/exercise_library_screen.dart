// lib/presentation/screens/exercise_library/exercise_library_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gymgenius/domain/enums/equipment_type.dart';
import 'package:gymgenius/domain/enums/exercise_category.dart';
import 'package:gymgenius/domain/enums/muscle_group.dart';
import 'package:gymgenius/engines/workout_engine/shared/exercise_pool_entry.dart';
import 'package:gymgenius/presentation/blocs/exercise_library/exercise_library_bloc.dart';
import 'package:gymgenius/presentation/blocs/exercise_library/exercise_library_event.dart';
import 'package:gymgenius/presentation/blocs/exercise_library/exercise_library_state.dart';
import 'package:gymgenius/presentation/screens/exercise_library/exercise_detail_screen.dart';
import 'package:gymgenius/presentation/screens/exercise_library/widgets/exercise_card.dart';
import 'package:gymgenius/presentation/screens/exercise_library/widgets/exercise_filter_chip.dart';
import 'package:gymgenius/presentation/screens/exercise_library/widgets/exercise_search_bar.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (_) => const ExerciseLibraryScreen(),
    );
  }

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

// AutomaticKeepAliveClientMixin: the only one of the 4 tabs whose state
// (search query, active filters, scroll position) lives purely in a
// local Bloc created in initState() rather than in a ViewModel injected
// from above the tab PageView — so unlike Home/Tracking/Profile, if
// this widget is ever torn down and recreated by the PageView, filters
// and scroll position would silently reset. wantKeepAlive: true tells
// the PageView to keep this page's State alive even while scrolled
// off-screen instead of disposing it.
class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen>
    with AutomaticKeepAliveClientMixin<ExerciseLibraryScreen> {
  late final ExerciseLibraryBloc _bloc;
  bool _showFilters = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _bloc = ExerciseLibraryBloc()..add(ExerciseLibraryInitialized());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin.
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: _showFilters ? colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: _showFilters ? 'Hide filters' : 'Show filters',
          ),
          if (_showFilters)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => _bloc.add(ExerciseLibraryFiltersCleared()),
              tooltip: 'Clear all filters',
            ),
        ],
      ),
      body: BlocProvider.value(
        value: _bloc,
        child: Column(
          children: [
            const ExerciseSearchBar(),
            if (_showFilters) _buildFilterChips(context),
            Expanded(
              child: BlocBuilder<ExerciseLibraryBloc, ExerciseLibraryState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.error != null) {
                    return _buildErrorView(context, state.error!);
                  }
                  if (state.filteredExercises.isEmpty) {
                    return _buildEmptyView(context);
                  }
                  return _buildExerciseList(state.filteredExercises);
                },
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // Filter chips
  // ========================================================================

  Widget _buildFilterChips(BuildContext context) {
    return BlocBuilder<ExerciseLibraryBloc, ExerciseLibraryState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ExerciseFilterChip(
                  label: state.selectedMuscle?.displayName ?? 'Muscle',
                  icon: Icons.fitness_center,
                  isActive: state.selectedMuscle != null,
                  onTap: () => _showFilterDialog<MuscleGroup?>(
                    context,
                    title: 'Filter by Muscle',
                    items: state.availableMuscles,
                    selected: state.selectedMuscle,
                    onSelected: (value) => _bloc.add(
                      ExerciseLibraryMuscleFilterChanged(value),
                    ),
                    displayName: (m) => m?.displayName ?? 'All Muscles',
                  ),
                ),
                const SizedBox(width: 8),
                ExerciseFilterChip(
                  label: state.selectedEquipment?.displayName ?? 'Equipment',
                  icon: Icons.build,
                  isActive: state.selectedEquipment != null,
                  onTap: () => _showFilterDialog<EquipmentType?>(
                    context,
                    title: 'Filter by Equipment',
                    items: state.availableEquipment,
                    selected: state.selectedEquipment,
                    onSelected: (value) => _bloc.add(
                      ExerciseLibraryEquipmentFilterChanged(value),
                    ),
                    displayName: (e) => e?.displayName ?? 'All Equipment',
                  ),
                ),
                const SizedBox(width: 8),
                ExerciseFilterChip(
                  label: state.selectedCategory?.displayName ?? 'Type',
                  icon: Icons.category,
                  isActive: state.selectedCategory != null,
                  onTap: () => _showFilterDialog<ExerciseCategory?>(
                    context,
                    title: 'Filter by Exercise Type',
                    items: ExerciseCategory.values,
                    selected: state.selectedCategory,
                    onSelected: (value) => _bloc.add(
                      ExerciseLibraryCategoryFilterChanged(value),
                    ),
                    displayName: (c) => c?.displayName ?? 'All Types',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================================================
  // Generic filter dialog using Radio + ListTile (no deprecation warnings)
  // ========================================================================

  void _showFilterDialog<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required T selected,
    required void Function(T) onSelected,
    required String Function(T) displayName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Select an option to filter the list',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(153),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    // RadioGroup<T> replaces the deprecated per-tile
                    // groupValue/onChanged (removed after Flutter
                    // 3.32.0-0.0.pre) — one ancestor now owns the
                    // selection state and change callback for every
                    // RadioListTile<T> beneath it.
                    child: RadioGroup<T>(
                      groupValue: selected,
                      onChanged: (newValue) {
                        onSelected(newValue as T);
                        Navigator.pop(context);
                      },
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: items.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return RadioListTile<T>(
                              value: null as T,
                              title: const Text('All'),
                            );
                          }
                          final item = items[index - 1];
                          return RadioListTile<T>(
                            value: item,
                            title: Text(displayName(item)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========================================================================
  // Subviews
  // ========================================================================

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading exercises',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(error, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _bloc.add(ExerciseLibraryInitialized()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurface.withAlpha(102),
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha(153),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha(102),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(List<ExercisePoolEntry> exercises) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return ExerciseCard(
          exercise: exercise,
          onTap: () {
            Navigator.push(
              context,
              ExerciseDetailScreen.route(exercise),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return BlocBuilder<ExerciseLibraryBloc, ExerciseLibraryState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${state.exerciseCount} exercises found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                ),
          ),
        );
      },
    );
  }
}
