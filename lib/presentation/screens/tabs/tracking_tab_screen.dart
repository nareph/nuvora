// lib/presentation/screens/tabs/tracking_tab_screen.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/presentation/viewmodels/tracking_viewmodel.dart';
import 'package:gymgenius/presentation/widgets/common/error_state_view.dart';
import 'package:gymgenius/presentation/widgets/tracking/day_log_details_view.dart';
import 'package:gymgenius/presentation/widgets/tracking/progress_summary_section.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

class TrackingTabScreen extends StatelessWidget {
  const TrackingTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<TrackingViewModel>(),
      child: const TrackingView(),
    );
  }
}

class TrackingView extends StatelessWidget {
  const TrackingView({super.key});

  Widget _buildEventsMarker(
    List<String> events,
    ColorScheme colorScheme,
  ) {
    final isCompleted = events.contains('Completed');
    final isPlanned = events.contains('Planned');

    if (isCompleted) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.shade600,
        ),
      );
    }

    if (isPlanned) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.secondary,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TrackingViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ================================================================
          // Header
          // ================================================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                20,
                16,
                12,
              ),
              child: Text(
                "Track Your Progress",
                style: textTheme.headlineSmall,
              ),
            ),
          ),

          // ================================================================
          // Progress summary
          // ================================================================
          SliverToBoxAdapter(
            child: ProgressSummarySection(
              snapshot: viewModel.progressSnapshot,
              isLoading: viewModel.isLoadingProgress,
            ),
          ),

          // ================================================================
          // Workout calendar
          // ================================================================
          SliverToBoxAdapter(
            child: TableCalendar<String>(
              locale: 'en_US',
              firstDay: DateTime.utc(
                DateTime.now().year - 2,
              ),
              lastDay: DateTime.utc(
                DateTime.now().year + 2,
              ),
              focusedDay: viewModel.focusedDay,
              selectedDayPredicate: (day) => isSameDay(
                viewModel.selectedDay,
                day,
              ),
              onDaySelected: (
                selected,
                focused,
              ) =>
                  viewModel.selectDay(
                selected,
                focusedDay: focused,
              ),
              onPageChanged: viewModel.changeFocusedDay,
              eventLoader: viewModel.getEventsForDay,
              calendarFormat: CalendarFormat.month,
              calendarBuilders: CalendarBuilders(
                markerBuilder: (
                  context,
                  day,
                  events,
                ) {
                  if (events.isEmpty) {
                    return null;
                  }

                  return Positioned(
                    right: 2,
                    bottom: 2,
                    child: _buildEventsMarker(
                      events,
                      colorScheme,
                    ),
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                todayDecoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(178),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: colorScheme.onSurface.withAlpha(178),
                ),
                defaultTextStyle: TextStyle(
                  color: colorScheme.onSurface,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: textTheme.titleMedium ??
                    const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(height: 1),
          ),

          // ================================================================
          // Selected day details
          // ================================================================
          SliverToBoxAdapter(
            child: _buildBodyContent(
              context,
              viewModel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(
    BuildContext context,
    TrackingViewModel viewModel,
  ) {
    switch (viewModel.state) {
      case TrackingState.loading:
      case TrackingState.initial:
        return const Center(
          child: CircularProgressIndicator(),
        );

      case TrackingState.error:
        return ErrorStateView(
          title: "Failed to Load Data",
          message: viewModel.errorMessage ?? "Please try again later.",
          onRetry: () => context.read<TrackingViewModel>().refresh(),
        );

      case TrackingState.loaded:
        final dateOnly = DateTime(
          viewModel.selectedDay.year,
          viewModel.selectedDay.month,
          viewModel.selectedDay.day,
        );

        return DayLogDetailsView(
          key: ValueKey(
            viewModel.selectedDay,
          ),
          selectedDay: viewModel.selectedDay,
          isLoading: viewModel.isLoadingDayDetails,
          isCompleted: viewModel.completedWorkoutDates.contains(
            dateOnly,
          ),
          isPlanned: viewModel.plannedEvents[dateOnly]?.isNotEmpty ?? false,
          logs: viewModel.selectedDayLogs,
        );
    }
  }
}
