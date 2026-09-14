// lib/presentation/screens/main_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/user.dart';
import 'package:gymgenius/presentation/blocs/auth/auth_bloc.dart';
import 'package:gymgenius/presentation/screens/exercise_library/exercise_library_screen.dart';
import 'package:gymgenius/presentation/screens/tabs/home_tab_screen.dart';
import 'package:gymgenius/presentation/screens/tabs/profile_tab_screen.dart';
import 'package:gymgenius/presentation/screens/tabs/tracking_tab_screen.dart';
import 'package:gymgenius/presentation/viewmodels/home_viewmodel.dart';
import 'package:gymgenius/presentation/viewmodels/tracking_viewmodel.dart';
import 'package:gymgenius/presentation/widgets/regeneration/regenerate_button.dart';
import 'package:gymgenius/presentation/widgets/regeneration/regeneration_options_sheet.dart';
import 'package:provider/provider.dart';

const int kHomeTabIndex = 0;
const int kExerciseLibraryTabIndex = 1;
const int kTrackingTabIndex = 2;
const int kProfileTabIndex = 3;

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const MainDashboardScreen(),
    );
  }

  @override
  State<MainDashboardScreen> createState() => MainDashboardScreenState();
}

class MainDashboardScreenState extends State<MainDashboardScreen> {
  int _selectedIndex = kHomeTabIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: _selectedIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void selectTab(int index) {
    _onItemTapped(index);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToTab(int index) {
    if (index >= kHomeTabIndex && index <= kProfileTabIndex) {
      _onItemTapped(index);
    }
  }

  String _getAppBarTitle(
    int index,
    User? user,
  ) {
    final displayName =
        user?.displayName ?? user?.email.split('@').first ?? 'User';

    switch (index) {
      case kHomeTabIndex:
        return 'Welcome, $displayName!';
      case kExerciseLibraryTabIndex:
        return 'Exercise Library';
      case kTrackingTabIndex:
        return 'Your Progress';
      case kProfileTabIndex:
        return 'My Profile';
      default:
        return 'GymGenius';
    }
  }

  Widget _buildAppLogo() {
    return Image.asset(
      'assets/launcher_icon/launcher_icon.png',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        Log.error(
          'App logo load failed',
          error: error,
          stackTrace: stackTrace,
        );

        return const Icon(
          Icons.fitness_center,
          size: 32,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Authenticating...",
          ),
        ),
      );
    }

    final List<Widget> widgetOptions = <Widget>[
      HomeTabScreen(
        onNavigateToTab: _navigateToTab,
      ),
      const ExerciseLibraryScreen(),
      const TrackingTabScreen(),
      const ProfileTabScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAppLogo(),
            const SizedBox(width: 12),
            Text(
              _getAppBarTitle(
                _selectedIndex,
                user,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_selectedIndex == kHomeTabIndex)
            Consumer<HomeViewModel>(
              builder: (
                context,
                viewModel,
                child,
              ) {
                return RegenerateButton(
                  healthProfile: viewModel.healthProfile,
                  currentProgram: viewModel.currentProgram,
                  onRegenerate: (options) {
                    _handleRegeneration(
                      context,
                      viewModel,
                      options,
                    );
                  },
                  isGenerating: viewModel.isGeneratingProgram,
                  tooltip: 'Edit Program',
                );
              },
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Tracking is kept alive by the PageView.
          // Refresh its health/progress data every time
          // the tab becomes active again.
          if (index == kTrackingTabIndex) {
            context.read<TrackingViewModel>().refresh();
          }
        },
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
            ),
            activeIcon: Icon(
              Icons.home_filled,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.library_books_outlined,
            ),
            activeIcon: Icon(
              Icons.library_books,
            ),
            label: 'Exercises',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.show_chart_outlined,
            ),
            activeIcon: Icon(
              Icons.show_chart,
            ),
            label: 'Tracking',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            activeIcon: Icon(
              Icons.person_rounded,
            ),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Future<void> _handleRegeneration(
    BuildContext context,
    HomeViewModel viewModel,
    RegenerationOptions options,
  ) async {
    try {
      await viewModel.regenerateProgram(options);
    } catch (e) {
      // Error is already handled in the ViewModel.
    }
  }
}
