// lib/presentation/screens/home/home_tab_screen.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/core/navigation/route_observer.dart';
import 'package:gymgenius/presentation/screens/profile_setup/profile_setup_screen.dart';
import 'package:gymgenius/presentation/viewmodels/home_viewmodel.dart';
import 'package:gymgenius/presentation/widgets/home/complete_profile_view.dart';
import 'package:gymgenius/presentation/widgets/home/expired_program_view.dart';
import 'package:gymgenius/presentation/widgets/home/no_program_view.dart';
import 'package:gymgenius/presentation/widgets/home/program_dashboard_view.dart';
import 'package:provider/provider.dart';

class HomeTabScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const HomeTabScreen({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen>
    with WidgetsBindingObserver, RouteAware {
  HomeViewModel? _viewModel;

  /// Prevents multiple DailyCheckIn screens from being opened
  /// at the same time.
  ///
  /// IMPORTANT:
  /// This is NOT a "check-in already shown" flag.
  /// It only protects against concurrent calls.
  bool _checkInPromptInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = context.read<HomeViewModel>();
      _viewModel = viewModel;
      viewModel.addListener(_onHomeViewModelChanged);
      _maybeTriggerCheckIn();
    });
  }

  // ===========================================================================
  // RouteAware — resync when returning from a pushed screen
  // ===========================================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  /// Called automatically when a route pushed ON TOP of Home
  /// is popped (e.g. return from HealthDashboardScreen, ProfileSetupScreen,
  /// ProgramDetailScreen, etc.).
  ///
  /// This is the right place to resync the DailyPlan with the latest
  /// Hive data (hydration, blood pressure, glucose, habits, wellness).
  @override
  void didPopNext() {
    super.didPopNext();
    _viewModel?.refresh();
  }

  // ===========================================================================
  // HomeViewModel listener
  // ===========================================================================

  void _onHomeViewModelChanged() {
    if (!mounted) return;
    _maybeTriggerCheckIn();
  }

  // ===========================================================================
  // Daily Check-in
  // ===========================================================================

  Future<void> _maybeTriggerCheckIn() async {
    if (!mounted) return;
    if (_checkInPromptInProgress) return;

    final viewModel = _viewModel;
    if (viewModel == null) return;

    // Only try to open the check-in once Home has finished loading.
    if (viewModel.state != HomeState.loaded) return;

    _checkInPromptInProgress = true;
    try {
      await viewModel.triggerCheckInIfNeeded(context);
    } catch (error) {
      debugPrint('HomeTabScreen: Failed to trigger DailyCheckIn: $error');
    } finally {
      _checkInPromptInProgress = false;
    }
  }

  // ===========================================================================
  // Application lifecycle
  // ===========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    /*
     * HomeTabScreen can remain mounted inside the application's PageView.
     *
     * Therefore initState() is NOT enough:
     *
     *   App opened
     *      ↓
     *   DailyCheckIn
     *      ↓
     *   "Plus tard"
     *      ↓
     *   user closes/minimizes app
     *      ↓
     *   user comes back later
     *      ↓
     *   Flutter resumes the app
     *      ↓
     *   check again
     *
     * Since "Plus tard" does not persist anything, the ViewModel
     * will see that today's check-in is still missing and reopen it.
     *
     * We ALSO refresh the DailyPlan here, because the user may have
     * logged health data from another app/device state, or simply
     * because a day boundary has been crossed.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel?.refresh();
      _maybeTriggerCheckIn();
    });
  }

  // ===========================================================================
  // Cleanup
  // ===========================================================================

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _viewModel?.removeListener(_onHomeViewModelChanged);
    _viewModel = null;
    super.dispose();
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, viewModel, child) {
        return _buildContent(context, viewModel);
      },
    );
  }

  Widget _buildContent(BuildContext context, HomeViewModel viewModel) {
    switch (viewModel.state) {
      case HomeState.initial:
      case HomeState.loading:
        return const Center(child: CircularProgressIndicator());

      case HomeState.loaded:
        return _buildLoadedContent(context, viewModel);

      case HomeState.error:
        return _buildErrorContent(context, viewModel);
    }
  }

  Widget _buildLoadedContent(BuildContext context, HomeViewModel viewModel) {
    final healthProfile = viewModel.healthProfile;

    // Case 1: No profile exists at all → user must create one.
    if (healthProfile == null) {
      return wrapInScrollable(CompleteProfileView(
        key: const ValueKey('no_profile'),
        onNavigate: () => _completeProfile(context, viewModel),
        isInsufficient: true,
      ));
    }

    // Case 2: Profile exists but is incomplete.
    if (!healthProfile.isComplete) {
      return wrapInScrollable(CompleteProfileView(
        key: const ValueKey('incomplete_profile'),
        onNavigate: () => _completeProfile(context, viewModel),
        isInsufficient: true,
      ));
    }

    // Case 3: No program yet.
    if (viewModel.currentProgram == null) {
      return wrapInScrollable(NoProgramView(
        key: const ValueKey('no_program'),
        onGenerate: viewModel.generateNewProgram,
      ));
    }

    // Case 4: Program expired.
    if (viewModel.currentProgram!.isExpired) {
      return wrapInScrollable(ExpiredProgramView(
        key: const ValueKey('expired_program'),
        programName: viewModel.currentProgram!.name,
        onGenerate: viewModel.generateNewProgram,
        onDismiss: viewModel.dismissExpiredProgram,
      ));
    }

    // Case 5: Everything ready → dashboard.
    return ProgramDashboardView(
      key: const ValueKey('dashboard'),
      program: viewModel.currentProgram!,
      healthProfile: healthProfile,
      dailyPlan: viewModel.dailyPlan!,
    );
  }

  Widget _buildErrorContent(BuildContext context, HomeViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              viewModel.errorMessage ??
                  'Something went wrong while loading your home screen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: viewModel.refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeProfile(
      BuildContext context, HomeViewModel viewModel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(
          isPostLogin: true,
          missingFieldIds: viewModel.healthProfile?.missingFieldIds,
        ),
      ),
    );
    if (context.mounted) {
      await viewModel.refresh();
    }
  }

  Widget wrapInScrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
