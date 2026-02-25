import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

typedef RoleGuardBuilder = Widget Function(
  BuildContext context,
  User user,
);

class RoleGuard extends StatefulWidget {
  final List<String> allowedRoles;
  final RoleGuardBuilder builder;
  final Widget? loading;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.builder,
    this.loading,
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _isLoading = true;
  User? _user;
  _GuardStatus _status = _GuardStatus.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _status = _GuardStatus.notLoggedIn;
          _isLoading = false;
        });
        return;
      }

      final userRole = _normalize(currentUser.role);
      final allowed =
          widget.allowedRoles.map(_normalize).contains(userRole);

      setState(() {
        if (allowed) {
          _status = _GuardStatus.authorized;
          _user = currentUser;
        } else {
          _status = _GuardStatus.unauthorized;
          _user = currentUser;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = _GuardStatus.error;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loading ??
          const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (_status) {
      case _GuardStatus.authorized:
        return widget.builder(context, _user!);
      case _GuardStatus.notLoggedIn:
        return _buildMessage(
          context,
          title: 'Login Required',
          message: 'Please login to continue.',
          primaryAction: () =>
              Navigator.pushReplacementNamed(context, '/login'),
          primaryLabel: 'Go to Login',
        );
      case _GuardStatus.unauthorized:
        return _buildMessage(
          context,
          title: 'Access Denied',
          message:
              'Your account role (${_user?.role ?? 'Unknown'}) is not allowed to view this page.',
          primaryAction: () => Navigator.pushReplacementNamed(context, '/login'),
          primaryLabel: 'Switch Account',
        );
      case _GuardStatus.error:
        return _buildMessage(
          context,
          title: 'Unexpected Error',
          message: _errorMessage ?? 'Something went wrong.',
          primaryAction: _verifyAccess,
          primaryLabel: 'Retry',
        );
      case _GuardStatus.loading:
        return widget.loading ??
            const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
    }
  }

  Widget _buildMessage(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback primaryAction,
    required String primaryLabel,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Restricted'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 60, color: Colors.indigo.shade300),
              const SizedBox(height: 16),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: primaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: Text(primaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalize(String role) => role.trim().toLowerCase();
}

enum _GuardStatus { loading, notLoggedIn, unauthorized, authorized, error }

