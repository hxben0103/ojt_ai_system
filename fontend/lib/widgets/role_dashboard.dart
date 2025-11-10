import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chatbot_screen.dart';

class RoleDashboard extends StatefulWidget {
  final String title;
  final Color color;
  final List<String>? tasks;
  final List<Widget>? customActions;

  const RoleDashboard({
    super.key,
    required this.title,
    required this.color,
    this.tasks,
    this.customActions,
  });

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Simulate initial dashboard loading delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isLoading = false);
    });

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
    // ✅ Loading Screen (white background)
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.gif', height: 200)
                  .animate()
                  .fadeIn(duration: 900.ms)
                  .scale(duration: 900.ms),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }

    // ✅ Main Dashboard
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body: AnimatedOpacity(
        opacity: _isLoading ? 0 : 1,
        duration: const Duration(milliseconds: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              if (widget.customActions != null) ...widget.customActions!,

              if (widget.tasks != null && widget.tasks!.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  "Available Tasks",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.2, end: 0),
                const Divider(),
                ...widget.tasks!
                    .asMap()
                    .entries
                    .map(
                      (entry) => ListTile(
                        leading: const Icon(Icons.check_circle_outline,
                            color: Colors.indigo),
                        title: Text(entry.value),
                      )
                          .animate(delay: (entry.key * 100).ms)
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: 0.2, end: 0),
                    )
                    .toList(),
              ],
            ],
          ),
        ),
      ),

      // 💬 Animated Floating AI Chat Button with Loading Animation
      floatingActionButton: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.1)
            .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
        child: GestureDetector(
          onTap: () async {
            // ✅ Show loading animation (white background)
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.gif', // your loading logo
                        height: 200,
                      )
                          .animate()
                          .fadeIn(duration: 900.ms)
                          .scale(duration: 900.ms),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );

            // Simulate a short delay before opening chatbot
            await Future.delayed(const Duration(seconds: 2));

            if (context.mounted) {
              Navigator.pop(context); // close loading screen
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 600),
                  pageBuilder: (_, __, ___) => const ChatBotScreen(),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(
                      opacity: animation,
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
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0078FF), Color(0xFF00C6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      "https://cdn-icons-png.flaticon.com/512/4712/4712035.png",
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "JRMSU AI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
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
