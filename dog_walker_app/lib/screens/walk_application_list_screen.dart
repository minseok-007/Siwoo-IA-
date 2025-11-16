import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../models/walk_application_model.dart';
import '../models/user_model.dart';
import '../services/walk_application_service.dart';
import '../services/user_service.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import '../services/notification_service.dart';
import 'walker_profile_view_screen.dart';

/// Screen for owners to view and manage walker applications for a walk request.
class WalkApplicationListScreen extends StatefulWidget {
  final WalkRequestModel walkRequest;

  const WalkApplicationListScreen({
    Key? key,
    required this.walkRequest,
  }) : super(key: key);

  @override
  State<WalkApplicationListScreen> createState() =>
      _WalkApplicationListScreenState();
}

class _WalkApplicationListScreenState
    extends State<WalkApplicationListScreen> {
  final WalkApplicationService _applicationService =
      WalkApplicationService();
  final UserService _userService = UserService();
  final WalkRequestService _walkRequestService = WalkRequestService();
  final NotificationService _notificationService = NotificationService();

  List<WalkApplicationModel> _applications = [];
  Map<String, UserModel> _walkerProfiles = {};
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _loading = true);
    try {
      final applications = await _applicationService
          .getPendingApplicationsByWalkRequest(widget.walkRequest.id);

      // Load walker profiles
      final profiles = <String, UserModel>{};
      for (final app in applications) {
        try {
          final walker = await _userService.getUserById(app.walkerId);
          if (walker != null) {
            profiles[app.walkerId] = walker;
          }
        } catch (e) {
          // Skip if user not found
        }
      }

      if (!mounted) return;
      setState(() {
        _applications = applications;
        _walkerProfiles = profiles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading applications: $e'),
        ),
      );
    }
  }

  Future<void> _selectWalker(WalkApplicationModel application) async {
    final walker = _walkerProfiles[application.walkerId];
    if (walker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Walker profile not found'),
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Walker'),
        content: Text(
          'Are you sure you want to select ${walker.fullName} for this walk?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
            ),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processing = true);

    try {
      // Accept the selected application
      await _applicationService.acceptApplication(application.id);

      // Reject all other pending applications
      for (final app in _applications) {
        if (app.id != application.id && app.status == ApplicationStatus.pending) {
          await _applicationService.rejectApplication(app.id);
        }
      }

      // Update the walk request to accepted status with the selected walker
      final updatedRequest = widget.walkRequest.copyWith(
        status: WalkRequestStatus.accepted,
        walkerId: application.walkerId,
        updatedAt: DateTime.now(),
      );
      await _walkRequestService.updateWalkRequest(updatedRequest);

      // Notify the selected walker
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ownerId = auth.currentUserId;
      if (ownerId != null) {
        await _notificationService.sendNotification(
          userId: application.walkerId,
          title: 'Application Accepted',
          body:
              'Your application for the walk at ${widget.walkRequest.location} has been accepted!',
          relatedId: widget.walkRequest.id,
          type: 'application_accepted',
          createdBy: ownerId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Walker selected successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting walker: $e'),
        ),
      );
    }
  }

  Future<void> _viewWalkerProfile(WalkApplicationModel application) async {
    final walker = _walkerProfiles[application.walkerId];
    if (walker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Walker profile not found'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkerProfileViewScreen(
          walker: walker,
          application: application,
          walkRequest: widget.walkRequest,
          onSelect: () => _selectWalker(application),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walker Applications'),
        backgroundColor: Colors.blue[600],
      ),
      body: _processing
          ? const Center(child: CircularProgressIndicator())
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _applications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No applications yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _applications.length,
                      itemBuilder: (context, index) {
                        final application = _applications[index];
                        final walker = _walkerProfiles[application.walkerId];

                        if (walker == null) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _viewWalkerProfile(application),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: walker.profileImageUrl != null
                                            ? NetworkImage(walker.profileImageUrl!)
                                            : null,
                                        child: walker.profileImageUrl == null
                                            ? Text(
                                                walker.fullName[0].toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              walker.fullName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.star,
                                                  size: 16,
                                                  color: Colors.amber[700],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${walker.rating.toStringAsFixed(1)} (${walker.totalWalks} walks)',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (application.message != null &&
                                      application.message!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        application.message!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () =>
                                            _viewWalkerProfile(application),
                                        child: const Text('View Profile'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _selectWalker(application),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[600],
                                        ),
                                        child: const Text('Select'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

