import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF1A3A5C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.blue.shade400, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withOpacity(0.5),
                        blurRadius: 24,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/betta-logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.primary.withOpacity(0.3),
                        child: const Icon(Icons.set_meal,
                            size: 50, color: Colors.white70),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text('BettaCare',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),

                const SizedBox(height: 8),

                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF67E8F9), Color(0xFF60A5FA)],
                  ).createShader(bounds),
                  child: const Text(
                    'Integrated Fish Management',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'A complete system for managing Betta fish care — automated feeding, care logging, orders and payments.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade200.withOpacity(0.8),
                      height: 1.6),
                ),

                const SizedBox(height: 48),

                // ESP32 badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt,
                          size: 14, color: Colors.amber.shade300),
                      const SizedBox(width: 6),
                      Text('ESP32 Automated Feeding System',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade300)),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Features
                ..._features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: f['color'] as Color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(f['icon'] as IconData,
                                size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(f['title'] as String,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(f['desc'] as String,
                                    style: TextStyle(
                                        color: Colors.blue.shade200
                                            .withOpacity(0.7),
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 48),

                // Buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Get Started',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Sign In',
                        style: TextStyle(fontSize: 15)),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _features = [
    {
      'icon': Icons.set_meal,
      'color': Color(0xFF3B82F6),
      'title': 'Fish Profile Management',
      'desc': 'Track species, health, age and tank assignment',
    },
    {
      'icon': Icons.bolt,
      'color': Color(0xFFF59E0B),
      'title': 'ESP32 Automated Feeding',
      'desc': 'Hardware feeder dispenses food on schedule',
    },
    {
      'icon': Icons.shopping_cart,
      'color': Color(0xFFEF4444),
      'title': 'Order Management',
      'desc': 'Manage customer orders with COD payments',
    },
    {
      'icon': Icons.water_drop,
      'color': Color(0xFF06B6D4),
      'title': 'Care Activity Logging',
      'desc': 'Record feeding, water changes and health checks',
    },
  ];
}
