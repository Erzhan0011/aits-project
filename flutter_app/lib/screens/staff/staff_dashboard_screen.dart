import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_router.dart';
import '../../providers/auth_provider.dart';

import '../../widgets/tilt_widget.dart';

class StaffDashboardScreen extends StatelessWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Professional Admin Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(48),
                bottomRight: Radius.circular(48),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ЦУП', // Center of User/Flight Operations
                      style: TextStyle(
                        color: const Color(0xFF38BDF8).withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                      ),
                    ),
                    const Text(
                      'Управление',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      Provider.of<AuthProvider>(context, listen: false).logout();
                      Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(24),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildDashboardCard(
                  context,
                  'РЕЙСЫ',
                  Icons.flight_takeoff_rounded,
                  const Color(0xFF6366F1),
                  () => Navigator.pushNamed(context, AppRouter.manageFlights),
                ),
                _buildDashboardCard(
                  context,
                  'ПОРТЫ',
                  Icons.location_city_rounded,
                  const Color(0xFF38BDF8),
                  () => Navigator.pushNamed(context, AppRouter.manageAirports),
                ),
                _buildDashboardCard(
                  context,
                  'БРОНИ',
                  Icons.confirmation_num_rounded,
                  const Color(0xFF10B981),
                  () => Navigator.pushNamed(context, AppRouter.manageBookings),
                ),
                _buildDashboardCard(
                  context,
                  'ФЛОТ',
                  Icons.airplanemode_active_rounded,
                  const Color(0xFFF59E0B),
                  () => Navigator.pushNamed(context, AppRouter.manageAircrafts),
                ),
                _buildDashboardCard(
                  context,
                  'ШТАТ',
                  Icons.badge_rounded,
                  const Color(0xFFEF4444),
                  () => Navigator.pushNamed(context, AppRouter.manageUsers),
                ),
                _buildDashboardCard(
                  context,
                  'ИНФО',
                  Icons.campaign_rounded,
                  const Color(0xFF8B5CF6),
                  () => Navigator.pushNamed(context, AppRouter.manageAnnouncements),
                ),
                _buildDashboardCard(
                  context,
                  'ПЛАТЕЖИ',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFFEC4899),
                  () => Navigator.pushNamed(context, AppRouter.managePayments),
                ),
                _buildDashboardCard(
                  context,
                  'ШАБЛОНЫ',
                  Icons.grid_view_rounded,
                  const Color(0xFF64748B),
                  () => Navigator.pushNamed(context, AppRouter.manageSeatTemplates),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return TiltWidget(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: color.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



