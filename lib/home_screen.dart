import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/signin_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'profile_screen.dart';
import 'report/photo_upload_screen.dart';
import 'report/my_reports_screen.dart';
import 'report/explore_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const navy = Color(0xFF16233D);
  static const orange = Color(0xFFE8622C);
  static const bg = Color(0xFFF5F2EA);

  int currentIndex = 1;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    _checkUser();
  }

  void _checkUser() {
    final user = supabase.auth.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SigninScreen()),
          (route) => false,
        );
      });
    }
  }

  void _openReportPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhotoUploadScreen()),
    );
  }

  void _onNavigationTap(int index) {
    if (index == 2) {
      _openReportPage();
      return;
    }

    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      body: SafeArea(child: _buildCurrentPage()),

      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCurrentPage() {
    switch (currentIndex) {
      case 0:
        return const DashboardScreen();

      case 1:
        return const ExploreScreen();

      case 3:
        return const MyReportsScreen();

      case 4:
        return const ProfileScreen();

      default:
        return const ExploreScreen();
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onNavigationTap,

        backgroundColor: Colors.white,
        elevation: 0,

        type: BottomNavigationBarType.fixed,

        selectedItemColor: orange,
        unselectedItemColor: Colors.grey,

        selectedFontSize: 11,
        unselectedFontSize: 11,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: "Dashboard",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore_rounded),
            label: "Explore",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 32),
            activeIcon: Icon(Icons.add_circle, size: 32),
            label: "Report",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: "My Reports",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
