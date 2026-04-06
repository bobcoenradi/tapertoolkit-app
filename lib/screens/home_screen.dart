import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/auth_service.dart';
import '../models/user_profile_model.dart';
import 'dashboard_screen.dart';
import 'journey_screen.dart';
import 'tools_screen.dart';
import 'social_screen.dart';
import 'menu_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _RootObserver extends NavigatorObserver {
  final ValueNotifier<bool> atRoot = ValueNotifier(true);
  int _depth = 0;

  @override
  void didPush(Route route, Route? previousRoute) {
    _depth++;
    atRoot.value = _depth <= 1;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _depth = (_depth - 1).clamp(0, 999);
    atRoot.value = _depth <= 1;
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _depth = (_depth - 1).clamp(0, 999);
    atRoot.value = _depth <= 1;
  }
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  UserProfile? _profile;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final List<_RootObserver> _observers = List.generate(5, (_) => _RootObserver());

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.fetchProfile();
    if (mounted) setState(() => _profile = profile);
  }

  // Called by any tab that returns from ProfileScreen
  void onProfileUpdated() => _loadProfile();

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [_observers[index]],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }

  void _onNavTap(int index) {
    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    if (index != _currentNavIndex) {
      setState(() => _currentNavIndex = index);
      // Reload profile whenever switching to dashboard tab
      if (index == 0) _loadProfile();
    }
  }

  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_currentNavIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    if (_currentNavIndex != 0) {
      setState(() => _currentNavIndex = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentNavIndex,
                    children: [
                      _buildTabNavigator(0, DashboardScreen(profile: _profile)),
                      _buildTabNavigator(1, const JourneyScreen()),
                      _buildTabNavigator(2, const ToolsScreen()),
                      _buildTabNavigator(3, const SocialScreen()),
                      _buildTabNavigator(4, MenuScreen(profile: _profile)),
                    ],
                  ),
                ),
                BottomNavBar(
                  currentIndex: _currentNavIndex,
                  onTap: _onNavTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
