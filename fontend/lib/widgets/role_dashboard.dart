import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chatbot_screen.dart';
import '../core/app_theme.dart';

class RoleDashboard extends StatefulWidget {
  final String title;
  final Color color;
  final List<String>? tasks;
  final List<Widget>? customActions;
  final List<Widget>? appBarActions;
  final Widget? headerContent;
  final Map<String, dynamic>? dashboardData;

  const RoleDashboard({
    super.key,
    required this.title,
    required this.color,
    this.tasks,
    this.customActions,
    this.appBarActions,
    this.headerContent,
    this.dashboardData,
  });

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Floating button pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Main Dashboard
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        bottom: widget.headerContent != null 
          ? PreferredSize(
              preferredSize: const Size.fromHeight(30),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                child: widget.headerContent!,
              ),
            )
          : null,
        shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.borderRadiusLarge),
              ),
            ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            if (widget.customActions != null) ...widget.customActions!,

            if (widget.tasks != null && widget.tasks!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                child: Text(
                  "Available Tasks",
                  style: AppTheme.heading3,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: -0.2, end: 0),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                child: Divider(height: 24),
              ),
              ...widget.tasks!
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_circle_outline,
                              color: widget.color, size: 20),
                        ),
                        title: Text(
                          entry.value,
                          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                      ),
                    )
                        .animate(delay: (entry.key * 100).ms)
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: 0.2, end: 0),
                  ),
            ],
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),

      // 💬 Animated Floating AI Chat Button
      floatingActionButton: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.1)
            .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
        child: GestureDetector(
          onTap: () async {
            // ✅ Improved loading dialog (no Scaffold)
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.white,
                insetPadding: EdgeInsets.zero,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.gif',
                        height: 240,
                      )
                          .animate()
                          .fadeIn(duration: 900.ms)
                          .scale(duration: 900.ms),
                      const SizedBox(height: 20),
                      Text(
                        "Initializing JRMSU AI...",
                        style: AppTheme.heading3.copyWith(color: AppTheme.studentPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            );

            // Natural delay for "loading" feel
            await Future.delayed(const Duration(milliseconds: 1200));

            if (context.mounted) {
              Navigator.pop(context); // close loading screen
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 500),
                  pageBuilder: (_, __, ___) => ChatBotScreen(
                    dashboardData: widget.dashboardData,
                  ),
                  transitionsBuilder: (_, animation, __, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
                      child: child,
                    );
                  },
                ),
              );
            }
          },
          child: Hero(
            tag: "aiChatButton",
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [widget.color, widget.color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text(
                      "AI CHAT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
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
}
