import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/walk_request_model.dart';
import '../models/walk_application_model.dart';
import '../models/user_model.dart';
import '../models/dog_traits.dart';
import '../services/walk_application_service.dart';
import '../services/user_service.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import '../services/schedule_conflict_service.dart';
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

  List<WalkApplicationModel> _applications = [];
  List<WalkApplicationModel> _filteredApplications = [];
  Map<String, UserModel> _walkerProfiles = {};
  bool _loading = true;
  bool _processing = false;
  
  // Filter state for owners
  ExperienceLevel? _selectedExperienceLevel;
  double _minRating = 0.0;
  List<DogSize> _selectedPreferredSizes = [];

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
        _filteredApplications = applications;
        _walkerProfiles = profiles;
        _loading = false;
      });
      _applyFilters();
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

    // Check for schedule conflicts
    bool hasConflict = false;
    List<({WalkRequestModel walk, double severity})> conflicts = [];
    List<DateTime> alternativeTimes = [];

    try {
      final existingWalks = await _walkRequestService.getRequestsByWalker(application.walkerId);
      final tempRequest = widget.walkRequest.copyWith(walkerId: application.walkerId);
      
      hasConflict = ScheduleConflictService.hasConflict(
        newWalk: tempRequest,
        existingWalks: existingWalks,
        walkerId: application.walkerId,
      );

      if (hasConflict) {
        conflicts = ScheduleConflictService.findConflicts(
          newWalk: tempRequest,
          existingWalks: existingWalks,
          walkerId: application.walkerId,
        );

        alternativeTimes = ScheduleConflictService.suggestAlternativeTimes(
          requestedWalk: tempRequest,
          existingWalks: existingWalks,
          walkerId: application.walkerId,
          durationMinutes: widget.walkRequest.duration,
          maxSuggestions: 3,
        );
      }
    } catch (e) {
      print('Error checking schedule conflicts: $e');
    }

    // Show confirmation dialog with conflict info if needed
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (hasConflict)
              Icon(Icons.warning, color: Colors.orange[700])
            else
              Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            Text(hasConflict ? 'Schedule Conflict' : 'Select Walker'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasConflict
                    ? '${walker.fullName} has a schedule conflict with this walk time.'
                    : 'Are you sure you want to select ${walker.fullName} for this walk?',
              ),
              if (hasConflict) ...[
                const SizedBox(height: 16),
                const Text(
                  'Conflicting walks:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...conflicts.map((conflict) {
                  final walk = conflict.walk;
                  final severity = conflict.severity;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: severity > 0.7 ? Colors.red : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_formatDateTime(walk.startTime)} - ${_formatDateTime(walk.endTime)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: severity > 0.7 ? Colors.red : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (alternativeTimes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Suggested alternative times:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...alternativeTimes.map((time) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(time),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                const Text(
                  'You can still select this walker, but they may need to reschedule.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasConflict ? Colors.orange[700] : Colors.green[600],
            ),
            child: Text(hasConflict ? 'Select Anyway' : 'Select'),
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

      // Notification removed

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasConflict
                ? 'Walker selected. Please note: schedule conflict detected.'
                : 'Walker selected successfully!',
          ),
          backgroundColor: hasConflict ? Colors.orange : Colors.green,
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

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y • h:mm a').format(dateTime);
  }


  void _applyFilters() {
    List<WalkApplicationModel> filtered = List.from(_applications);
    
    for (final application in _applications) {
      final walker = _walkerProfiles[application.walkerId];
      if (walker == null) {
        filtered.remove(application);
        continue;
      }
      
      // Filter by experience level
      if (_selectedExperienceLevel != null) {
        if (walker.experienceLevel != _selectedExperienceLevel) {
          filtered.remove(application);
          continue;
        }
      }
      
      // Filter by minimum rating
      if (walker.rating < _minRating) {
        filtered.remove(application);
        continue;
      }
      
      // Filter by preferred dog sizes (if walker prefers specific sizes)
      if (_selectedPreferredSizes.isNotEmpty && walker.preferredDogSizes.isNotEmpty) {
        final hasMatchingSize = _selectedPreferredSizes.any(
          (size) => walker.preferredDogSizes.contains(size),
        );
        if (!hasMatchingSize) {
          filtered.remove(application);
          continue;
        }
      }
    }
    
    setState(() {
      _filteredApplications = filtered;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Walkers'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Experience level filter
                const Text('Experience Level:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<ExperienceLevel?>(
                  value: _selectedExperienceLevel,
                  decoration: const InputDecoration(
                    hintText: 'Any experience level',
                  ),
                  items: [
                    const DropdownMenuItem<ExperienceLevel?>(
                      value: null,
                      child: Text('Any'),
                    ),
                    ...ExperienceLevel.values.map((level) {
                      return DropdownMenuItem<ExperienceLevel?>(
                        value: level,
                        child: Text(level.toString().split('.').last),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedExperienceLevel = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Minimum rating filter
                Text('Minimum Rating: ${_minRating.toStringAsFixed(1)}'),
                Slider(
                  value: _minRating,
                  min: 0.0,
                  max: 5.0,
                  divisions: 10,
                  label: _minRating.toStringAsFixed(1),
                  onChanged: (value) {
                    setDialogState(() {
                      _minRating = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Preferred dog sizes filter
                const Text('Preferred Dog Sizes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: DogSize.values.map((size) {
                    final isSelected = _selectedPreferredSizes.contains(size);
                    return FilterChip(
                      label: Text(size.toString().split('.').last),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedPreferredSizes.add(size);
                          } else {
                            _selectedPreferredSizes.remove(size);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _selectedExperienceLevel = null;
                  _minRating = 0.0;
                  _selectedPreferredSizes.clear();
                });
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter walkers',
          ),
        ],
      ),
      body: _processing
          ? const Center(child: CircularProgressIndicator())
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredApplications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _applications.isEmpty
                                ? Icons.people_outline
                                : Icons.filter_alt_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _applications.isEmpty
                                ? 'No applications yet'
                                : 'No walkers match your filters',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_applications.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedExperienceLevel = null;
                                  _minRating = 0.0;
                                  _selectedPreferredSizes.clear();
                                });
                                _applyFilters();
                              },
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        if (_selectedExperienceLevel != null ||
                            _minRating > 0.0 ||
                            _selectedPreferredSizes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            color: Colors.blue[50],
                            child: Row(
                              children: [
                                const Icon(Icons.filter_alt, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_filteredApplications.length} of ${_applications.length} walkers',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedExperienceLevel = null;
                                      _minRating = 0.0;
                                      _selectedPreferredSizes.clear();
                                    });
                                    _applyFilters();
                                  },
                                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredApplications.length,
                            itemBuilder: (context, index) {
                              final application = _filteredApplications[index];
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
                        ),
                      ],
                    ),
    );
  }
}

