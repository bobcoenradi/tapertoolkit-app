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

/// Paints the three soft radial blobs over the base #f5ece0 background.
class _GradientBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlobPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // blob 1 — top-right
    _drawBlob(canvas, Offset(size.width * 0.88, size.height * 0.06), size.width * 0.52);
    // blob 2 — mid-left
    _drawBlob(canvas, Offset(size.width * 0.0, size.height * 0.44), size.width * 0.46);
    // blob 3 — bottom-center-right
    _drawBlob(canvas, Offset(size.width * 0.6, size.height * 0.84), size.width * 0.48);
  }

  void _drawBlob(Canvas canvas, Offset center, double radius) {
    // Use the same peach hue at 0 alpha for the outer stop so Flutter
    // interpolates smoothly (avoids the muddy grey you get with Colors.transparent)
    const innerColor  = Color(0xE6FFEBD2); // rgba(255,235,210, 0.9)
    const midColor    = Color(0x7FFAE1C3); // rgba(250,225,195, 0.5)
    const outerColor  = Color(0x00FFEBD2); // rgba(255,235,210, 0.0)

    final paint = Paint()
      ..shader = RadialGradient(
        colors: const [innerColor, midColor, outerColor],
        stops: const [0.0, 0.40, 0.68],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Draw only up to the 68% point where it's fully transparent — beyond
    // that is already 0 alpha so clipping at radius keeps the canvas clean.
    canvas.drawCircle(center, radius * 0.68, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  final _journeyReloadTrigger = ValueNotifier<int>(0);

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
      if (index == 0) _loadProfile();
      // Reload journey data when switching to the Journey tab
      if (index == 1) _journeyReloadTrigger.value++;
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
            // Radial gradient blobs — always behind everything
            Positioned.fill(child: _GradientBackground()),
            Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentNavIndex,
                    children: [
                      _buildTabNavigator(0, DashboardScreen(profile: _profile)),
                      _buildTabNavigator(1, JourneyScreen(reloadTrigger: _journeyReloadTrigger)),
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
