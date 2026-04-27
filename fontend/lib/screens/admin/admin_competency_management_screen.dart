import 'package:flutter/material.dart';
import '../../models/competency.dart';
import '../../services/daily_task_service.dart';
import '../../core/app_theme.dart';
import '../../widgets/section_header.dart';
import '../../widgets/modern_table_card.dart';
import '../../widgets/loading_skeleton.dart';

class AdminCompetencyManagementScreen extends StatefulWidget {
  const AdminCompetencyManagementScreen({super.key});

  @override
  State<AdminCompetencyManagementScreen> createState() => _AdminCompetencyManagementScreenState();
}

class _AdminCompetencyManagementScreenState extends State<AdminCompetencyManagementScreen> {
  List<Competency> _competencies = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _updatingIds = {};

  @override
  void initState() {
    super.initState();
    _loadCompetencies();
  }

  Future<void> _loadCompetencies() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final results = await DailyTaskService.getCompetencies();
      setState(() {
        _competencies = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePointValue(Competency competency, int newValue) async {
    if (newValue < 0 || newValue > 100) return;
    
    setState(() {
      _updatingIds.add(competency.competencyId);
    });

    try {
      await DailyTaskService.updateCompetencyPointValue(competency.competencyId, newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${competency.title} to $newValue points')),
        );
      }
      await _loadCompetencies();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingIds.remove(competency.competencyId);
        });
      }
    }
  }

  void _showEditDialog(Competency competency) {
    int tempValue = competency.pointValue;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Points: ${competency.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set the point value for this competency (0-100). This affects AI performance predictions.'),
            const SizedBox(height: 20),
            StatefulBuilder(
              builder: (context, setDialogState) => Column(
                children: [
                  Slider(
                    value: tempValue.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: tempValue.toString(),
                    activeColor: AppTheme.adminPrimary,
                    onChanged: (value) {
                      setDialogState(() {
                        tempValue = value.toInt();
                      });
                    },
                  ),
                  Text(
                    tempValue.toString(),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.adminPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.primaryButtonStyle(AppTheme.adminPrimary),
            onPressed: () {
              Navigator.pop(context);
              _updatePointValue(competency, tempValue);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Competency Management'),
        backgroundColor: AppTheme.adminPrimary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCompetencies,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          children: [
            const SectionHeader(
              title: 'Point-Based Scoring System',
              icon: Icons.settings_suggest_rounded,
              subtitle: 'Manage how skill categories contribute to student performance scores.',
            ),
            const SizedBox(height: AppTheme.spacing16),
            if (_isLoading)
              const Column(
                children: [
                  LoadingSkeleton(height: 100),
                  SizedBox(height: 12),
                  LoadingSkeleton(height: 100),
                  SizedBox(height: 12),
                  LoadingSkeleton(height: 100),
                ],
              )
            else if (_errorMessage != null)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_errorMessage'),
                    ElevatedButton(onPressed: _loadCompetencies, child: const Text('Retry')),
                  ],
                ),
              )
            else
              ModernTableCard(
                title: 'Available Competencies',
                icon: Icons.list_alt_rounded,
                table: Column(
                  children: _competencies.map((c) => _buildCompetencyRow(c)).toList(),
                ),
              ),
            const SizedBox(height: AppTheme.spacing32),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyRow(Competency competency) {
    final bool isUpdating = _updatingIds.contains(competency.competencyId);
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.adminPrimary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.auto_awesome, size: 20, color: AppTheme.adminPrimary),
      ),
      title: Text(competency.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('ID: ${competency.competencyId}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.adminPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${competency.pointValue} pts',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.adminPrimary),
            ),
          ),
          const SizedBox(width: 8),
          isUpdating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.grey),
                  onPressed: () => _showEditDialog(competency),
                ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Defense Tip:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Explain to the panel that these point values represent the "Skill Multiplier." '
            'Higher points are assigned to technical competencies (Software Development, AI, Research) '
            'compared to administrative tasks. This ensures the prediction engine values quality over quantity.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

