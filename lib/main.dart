// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/core/navigation/route_observer.dart';
import 'package:gymgenius/data/datasources/local/hive/boxes/hive_datasource.dart';
import 'package:gymgenius/di/injection.dart';
import 'package:gymgenius/domain/repositories/workout_repository.dart';
import 'package:gymgenius/presentation/blocs/auth/auth_bloc.dart';
import 'package:gymgenius/presentation/blocs/login/login_bloc.dart';
import 'package:gymgenius/presentation/blocs/signup/signup_bloc.dart';
import 'package:gymgenius/presentation/providers/workout_session_manager.dart';
import 'package:gymgenius/presentation/providers/workout_session_settings_controller.dart';
import 'package:gymgenius/presentation/theme/app_theme.dart';
import 'package:gymgenius/presentation/viewmodels/home_viewmodel.dart';
import 'package:gymgenius/presentation/viewmodels/profile_viewmodel.dart';
import 'package:gymgenius/presentation/viewmodels/tracking_viewmodel.dart';
import 'package:gymgenius/auth_wrapper.dart';
import 'package:gymgenius/presentation/widgets/workout/workout_app_lifecycle_bridge.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveDatasource.initialize();
  setupDependencies();
  await getIt<WorkoutSessionManager>().initialize();
  await getIt<WorkoutSessionSettingsController>().load();

  Log.info('--- Nuvora Started (Local Database Mode) ---');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => getIt<AuthBloc>(),
        ),
        BlocProvider<LoginBloc>(
          create: (context) => getIt<LoginBloc>(),
        ),
        BlocProvider<SignUpBloc>(
          create: (context) => getIt<SignUpBloc>(),
        ),

        // Registered in GetIt, but also exposed through Provider because
        // some screens access WorkoutRepository using context.read<>().
        Provider<WorkoutRepository>(
          create: (context) => getIt<WorkoutRepository>(),
        ),

        ChangeNotifierProvider(
          create: (context) => getIt<WorkoutSessionManager>(),
        ),
        ChangeNotifierProvider(
          create: (context) => getIt<WorkoutSessionSettingsController>(),
        ),
        ChangeNotifierProvider<HomeViewModel>(
          create: (context) => getIt<HomeViewModel>(),
        ),
        ChangeNotifierProvider<TrackingViewModel>(
          create: (context) => getIt<TrackingViewModel>(),
        ),
        ChangeNotifierProvider<ProfileViewModel>(
          create: (context) => getIt<ProfileViewModel>(),
        ),
      ],
      child: const AppView(),
    );
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkoutAppLifecycleBridge(
      child: MaterialApp(
        title: 'Nuvora',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,

        // ✅ ADDED: registers the global observer for RouteAware
        // (used by HomeTabScreen.didPopNext() to resync the
        // DailyPlan when returning from a pushed route — e.g. HealthDashboard).
        navigatorObservers: [appRouteObserver],

        home: const AuthWrapper(),
      ),
    );
  }
}
