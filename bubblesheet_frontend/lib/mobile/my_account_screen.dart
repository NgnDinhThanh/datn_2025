import 'package:bubblesheet_frontend/services/full_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class MyAccountScreen extends StatelessWidget {
  const MyAccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // Hide default AppBar
      ),
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: const EdgeInsets.only(top: 16, bottom: 16, left: 16, right: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF2E7D32), // ZipGrade green
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MY ACCOUNT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Account settings',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Profile Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Color(0xFF2E7D32),
                                  child: Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  authProvider.currentUser ?? 'No user',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Teacher Account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Settings Options
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.sync, color: Color(0xFF2E7D32)),
                                title: const Text('Sync Now'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  _showSyncDialog(context);
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.settings, color: Color(0xFF2E7D32)),
                                title: const Text('Settings'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  // TODO: Navigate to settings
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.help, color: Color(0xFF2E7D32)),
                                title: const Text('Help & Support'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  // TODO: Navigate to help
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.info, color: Color(0xFF2E7D32)),
                                title: const Text('About'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  // TODO: Show about dialog
                                },
                              ),
                            ],
                          ),
                        ),
                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            label: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              await authProvider.logout();
                              if (context.mounted) {
                                Navigator.of(context).pushReplacementNamed('/login');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SyncDialog(),
    );
  }
}

class _SyncDialog extends StatefulWidget {
  const _SyncDialog({Key? key}) : super(key: key);

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  bool _isSyncing = true;
  FullSyncResult? _result;

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    try {
      final res = await FullSyncService.performFullSync(context);
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _result = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _result = FullSyncResult(
          examsSynced: 0,
          classesSynced: 0,
          studentsSynced: 0,
          answerSheetsSynced: 0,
          gradesSynced: 0,
          answerKeysSynced: 0,
          pendingResultsSynced: 0,
          pendingResultsFailed: 0,
          crudOperationsSynced: 0,
          crudOperationsFailed: 0,
          success: false,
          error: e.toString(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final success = _result?.success ?? false;

    return AlertDialog(
      title: Text(
        _isSyncing
            ? 'Syncing...'
            : (success ? 'Sync Completed' : 'Sync Failed'),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isSyncing
            ? const SizedBox(
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: _buildResultContent(),
              ),
      ),
      actions: [
        if (!_isSyncing)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
      ],
    );
  }

  Widget _buildResultContent() {
    if (_result == null) {
      return const Text('No result.');
    }

    if (!_result!.success) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync failed',
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _result!.error ?? 'Unknown error',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    // Thành công
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sync completed successfully!',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        const SizedBox(height: 12),
        _buildRow('Exams', _result!.examsSynced),
        _buildRow('Classes', _result!.classesSynced),
        _buildRow('Students', _result!.studentsSynced),
        _buildRow('Answer sheets', _result!.answerSheetsSynced),
        _buildRow('Grades cached', _result!.gradesSynced),
        _buildRow('Answer keys cached', _result!.answerKeysSynced),
        const Divider(),
        _buildRow('Pending results synced', _result!.pendingResultsSynced,
            failed: _result!.pendingResultsFailed),
        _buildRow('CRUD operations synced', _result!.crudOperationsSynced,
            failed: _result!.crudOperationsFailed),
      ],
    );
  }

  Widget _buildRow(String label, int ok, {int failed = 0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Text(
                '$ok',
                style: const TextStyle(color: Colors.green),
              ),
              if (failed > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '($failed failed)',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}