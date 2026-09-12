// lib/core/navigation/route_observer.dart

import 'package:flutter/material.dart';

/// Global route observer used to notify screens when they become
/// visible again (e.g. when a pushed route is popped).
///
/// Register it in MaterialApp.navigatorObservers, then subscribe
/// to it from any RouteAware State that needs to react to navigation
/// changes (typically: refresh data when returning from a detail screen).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
