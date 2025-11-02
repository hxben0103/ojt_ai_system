import 'package:flutter/material.dart';

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

class _RoleDashboardState extends State<RoleDashboard> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate loading delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Loading screen
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Center logo
              Image.asset(
                'assets/images/ojt.png',
                height: 120,
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(
                color: Colors.indigo,
                strokeWidth: 4,
              ),
              const SizedBox(height: 20),
              const Text(
                "Loading Dashboard...",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.indigo),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ After loading, show the real dashboard
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
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
                ),
                const Divider(),
                ...widget.tasks!.map(
                  (task) => ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(task),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      // ✅ Floating Back Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.color,
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Log Out"),
              content: const Text(
                  "Are you sure you want to log out and return to the login screen?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/', (route) => false);
                  },
                  child: const Text("Yes, Log Out"),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.logout),
      ),
    );
  }
}
