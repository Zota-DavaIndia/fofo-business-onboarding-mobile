import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/permissions.dart';
import '../core/auth/user.dart';
import '../core/icons/app_icon.dart';
import '../features/home/home_screen.dart';
import '../features/leads/lead_detail_screen.dart';
import '../features/leads/leads_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/visits/visits_screen.dart';

/// A top-level area of the app. A module shows up only when the user has
/// its [permission]; modules without one are open to every signed-in user.
class AppModule {
  const AppModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
    required this.builder,
    this.permission,
    this.routes = const [],
  });

  final String id;
  final String label;
  final AppIconData icon;
  final String path;
  final String? permission;
  final WidgetBuilder builder;

  /// Screens opened from this tab that keep the tab bar visible.
  final List<RouteBase> routes;

  bool allows(AppUser user) => permission == null || user.can(permission!);
}

/// Bottom tabs, in display order. Home sits in the middle and opens first.
/// New field modules (day plan, expenses...) are added here.
final tabModules = <AppModule>[
  AppModule(
    id: 'leads',
    label: 'Leads',
    icon: AppIcons.leads,
    path: '/leads',
    permission: Perm.leadsView,
    builder: (_) => const LeadsScreen(),
    routes: [
      GoRoute(
        path: ':id',
        builder: (_, state) => LeadDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
    ],
  ),
  AppModule(
    id: 'visits',
    label: 'Visits',
    icon: AppIcons.visit,
    path: '/visits',
    permission: Perm.visitsManage,
    builder: (_) => const VisitsScreen(),
  ),
  AppModule(id: 'home', label: 'Home', icon: AppIcons.home, path: '/home', builder: (_) => const HomeScreen()),
  AppModule(
    id: 'onboarding',
    label: 'Onboard',
    icon: AppIcons.store,
    path: '/onboarding',
    permission: Perm.onboardingView,
    builder: (_) => const OnboardingScreen(),
  ),
  AppModule(
    id: 'profile',
    label: 'Profile',
    icon: AppIcons.user,
    path: '/profile',
    builder: (_) => const ProfileScreen(),
  ),
];
