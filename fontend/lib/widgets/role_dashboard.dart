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
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTheme.heading3.copyWith(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: widget.appBarActions,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          if (widget.customActions != null) ...widget.customActions!,

          if (widget.tasks != null && widget.tasks!.isNotEmpty) ...[
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Operational Tasks",
                style: AppTheme.heading3.copyWith(fontSize: 18, color: Colors.blueGrey.shade900),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 24, thickness: 1),
            ),
            ...widget.tasks!
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        onTap: () {},
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.arrow_right_alt_rounded,
                              color: widget.color, size: 18),
                        ),
                        title: Text(
                          entry.value,
                          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.blueGrey.shade300),
                      ),
                    ),
                  )
                      .animate(delay: (entry.key * 100).ms)
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: 0.1, end: 0),
                ),
          ],
          const SizedBox(height: 100), // Space for FAB
        ],
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

