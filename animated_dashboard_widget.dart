import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'navigation_helper.dart';

class AnimatedDashboardWidget extends StatefulWidget {
  final int accessPointCount;
  final int alertCount;
  final int expiringLicenses;
  final int edgeGatewayCount;
  final List<Map<String, dynamic>> clusters;
  final String? clusterId;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback initializeTokenAndLoadData;
  final VoidCallback showClusterPopupCard;

  const AnimatedDashboardWidget({
    Key? key,
    required this.accessPointCount,
    required this.alertCount,
    required this.expiringLicenses,
    required this.edgeGatewayCount,
    required this.clusters,
    required this.clusterId,
    required this.isLoading,
    required this.errorMessage,
    required this.initializeTokenAndLoadData,
    required this.showClusterPopupCard,
  }) : super(key: key);

  @override
  State<AnimatedDashboardWidget> createState() => _AnimatedDashboardWidgetState();
}

class _AnimatedDashboardWidgetState extends State<AnimatedDashboardWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_rounded),
            onPressed: widget.showClusterPopupCard,
            tooltip: 'View Clusters',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.initializeTokenAndLoadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      drawer: AppDrawer(selectedScreen: '', onSelectScreen: (String screenName) {  },),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8E44AD),
              Color(0xFF3F51B5),
            ],
          ),
        ),
        child: widget.isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Loading Dashboard...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        )
            : widget.errorMessage != null
            ? Center(
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: widget.initializeTokenAndLoadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        )
            : FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome to Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cluster: ${widget.clusterId ?? "Not Selected"}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Metrics Grid
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildAnimatedMetricCard(
                            'Access Points',
                            widget.accessPointCount.toString(),
                            Icons.wifi,
                            const Color(0xFF4CAF50),
                            0,
                          ),
                          _buildAnimatedMetricCard(
                            'Alerts',
                            widget.alertCount.toString(),
                            Icons.warning_amber_rounded,
                            const Color(0xFFF44336),
                            1,
                          ),
                          _buildAnimatedMetricCard(
                            'Edge Gateways',
                            widget.edgeGatewayCount.toString(),
                            Icons.router,
                            const Color(0xFF2196F3),
                            2,
                          ),
                          _buildAnimatedMetricCard(
                            'Expiring Licenses',
                            widget.expiringLicenses.toString(),
                            Icons.card_membership,
                            const Color(0xFFFF9800),
                            3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMetricCard(String title, String value, IconData icon, Color color, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 200)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: animationValue,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Add navigation or action here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title tapped')),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          size: 32,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}