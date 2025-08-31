import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/dog_model.dart';
import '../models/walk_request_model.dart';
import '../services/matching_service.dart';
import '../services/auth_provider.dart';
import '../services/user_service.dart';
import '../services/dog_service.dart';
import '../services/walk_request_service.dart';
import '../l10n/app_localizations.dart';

/// 스마트 매칭 결과 화면.
/// - MatchingService의 점수 결과를 시각화하고 필터를 제공합니다.
class SmartMatchingScreen extends StatefulWidget {
  const SmartMatchingScreen({Key? key}) : super(key: key);

  @override
  State<SmartMatchingScreen> createState() => _SmartMatchingScreenState();
}

class _SmartMatchingScreenState extends State<SmartMatchingScreen> {
  final UserService _userService = UserService();
  final DogService _dogService = DogService();
  final WalkRequestService _walkService = WalkRequestService();
  
  List<MatchResult> _matches = [];
  bool _loading = true;
  String? _error;
  
  // Filter options
  double _minScore = 0.5;
  double _maxDistance = 20.0;
  List<DogSize> _preferredDogSizes = [];
  List<ExperienceLevel> _experienceLevels = [];
  double _maxPrice = 100.0;
  
  // Current user data
  UserModel? _currentUser;
  List<DogModel> _userDogs = [];
  WalkRequestModel? _currentWalkRequest;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _loading = true);
      
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user == null) {
        setState(() => _error = AppLocalizations.of(context).t('user_not_authenticated'));
        return;
      }
      
      _currentUser = user;
      
      // Load user's dogs
      if (user.userType == UserType.dogOwner) {
        _userDogs = await _dogService.getDogsByOwner(user.id);
        
        // Load current walk request if exists
        final requests = await _walkService.getRequestsByOwner(user.id);
        _currentWalkRequest = requests.where((r) => 
          r.status == WalkRequestStatus.pending || 
          r.status == WalkRequestStatus.accepted
        ).firstOrNull;
      }
      
      await _findMatches();
    } catch (e) {
      setState(() => _error = '${AppLocalizations.of(context).t('err_loading_data')}: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _findMatches() async {
    try {
      if (_currentUser == null || _currentUser!.userType != UserType.dogOwner) return;
      if (_userDogs.isEmpty) return;
      
      // Get all available walkers
      final walkers = await _userService.getAllWalkers();
      
      // Find matches for each dog
      final allMatches = <MatchResult>[];
      
      for (final dog in _userDogs) {
        if (_currentWalkRequest != null) {
          // Use existing walk request
          final matches = MatchingService.findCompatibleMatches(
            walkers,
            _currentWalkRequest!,
            _currentUser!,
            dog,
            maxResults: 20,
          );
          allMatches.addAll(matches);
        } else {
          // Create a sample walk request for matching
          final sampleRequest = WalkRequestModel(
            id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
            ownerId: _currentUser!.id,
            dogId: dog.id,
            location: AppLocalizations.of(context).t('sample_location'),
            time: DateTime.now().add(const Duration(days: 1)),
            duration: 30,
            notes: AppLocalizations.of(context).t('sample_walk_request_note'),
            status: WalkRequestStatus.pending,
            budget: 50.0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          final matches = MatchingService.findCompatibleMatches(
            walkers,
            sampleRequest,
            _currentUser!,
            dog,
            maxResults: 20,
          );
          allMatches.addAll(matches);
        }
      }
      
      // Remove duplicates and sort by score
      final uniqueMatches = <String, MatchResult>{};
      for (final match in allMatches) {
        uniqueMatches[match.walker.id] = match;
      }
      
      final sortedMatches = uniqueMatches.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      
      setState(() => _matches = sortedMatches);
    } catch (e) {
      setState(() => _error = '${AppLocalizations.of(context).t('err_finding_matches')}: $e');
    }
  }

  List<MatchResult> _getFilteredMatches() {
    return _matches.where((match) {
      // Score filter
      if (match.score < _minScore) return false;
      
      // Distance filter
      if (_currentUser?.location != null && match.walker.location != null) {
        final distance = MatchingService.calculateDistance(
          _currentUser!.location!,
          match.walker.location!,
        );
        if (distance > _maxDistance) return false;
      }
      
      // Dog size filter
      if (_preferredDogSizes.isNotEmpty) {
        final hasPreferredSize = _userDogs.any((dog) => 
          _preferredDogSizes.contains(dog.size)
        );
        if (!hasPreferredSize) return false;
      }
      
      // Experience level filter
      if (_experienceLevels.isNotEmpty) {
        if (!_experienceLevels.contains(match.walker.experienceLevel)) return false;
      }
      
      // Price filter
      if (match.walker.hourlyRate > _maxPrice) return false;
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _getFilteredMatches();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('smart_matching')),
        backgroundColor: Colors.indigo[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _findMatches,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.red[600])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: Text(AppLocalizations.of(context).t('retry')),
                      ),
                    ],
                  ),
                )
      : Column(
                  children: [
                    _buildStatsCard(filteredMatches),
                    Expanded(
                      child: filteredMatches.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredMatches.length,
                              itemBuilder: (context, index) {
                                return _buildMatchCard(filteredMatches[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatsCard(List<MatchResult> matches) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).t('matching_results'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    AppLocalizations.of(context).t('total_matches'),
                    '${matches.length}',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    AppLocalizations.of(context).t('high_score'),
                    '${matches.where((m) => m.score > 0.8).length}',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    AppLocalizations.of(context).t('nearby'),
                    '${matches.where((m) {
                    if (_currentUser?.location == null || m.walker.location == null) return false;
                    final distance = MatchingService.calculateDistance(
                      _currentUser!.location!,
                      m.walker.location!,
                    );
                    return distance < 5.0;
                  }).length}',
                    Icons.location_on,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMatchCard(MatchResult match) {
    final distance = _currentUser?.location != null && match.walker.location != null
        ? MatchingService.calculateDistance(
            _currentUser!.location!,
            match.walker.location!,
          )
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.indigo[100],
                  child: Text(
                    match.walker.fullName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo[600],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.walker.fullName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${match.walker.experienceLevel.toString().split('.').last} Walker',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      if (distance != null)
                        Text(
                          '${distance.toStringAsFixed(1)} km away',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getScoreColor(match.score),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(match.score * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${match.walker.hourlyRate}/hr',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildScoreBreakdown(match.breakdown),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewWalkerProfile(match.walker),
                    icon: const Icon(Icons.person),
                    label: Text(AppLocalizations.of(context).t('view_profile')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo[600],
                      side: BorderSide(color: Colors.indigo[600]!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _requestWalk(match),
                    icon: const Icon(Icons.directions_walk),
                    label: Text(AppLocalizations.of(context).t('request_walk')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBreakdown(Map<String, double> breakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).t('match_breakdown'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: breakdown.entries.map((entry) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.key}: ${(entry.value * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).t('no_matches_found'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).t('try_adjusting_filters'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('filter_matches')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterSlider(AppLocalizations.of(context).t('minimum_score'), _minScore, 0.0, 1.0, (value) {
                setState(() => _minScore = value);
              }),
              _buildFilterSlider(AppLocalizations.of(context).t('max_distance_km'), _maxDistance, 1.0, 50.0, (value) {
                setState(() => _maxDistance = value);
              }),
              _buildFilterSlider(AppLocalizations.of(context).t('max_price'), _maxPrice, 10.0, 200.0, (value) {
                setState(() => _maxPrice = value);
              }),
              const SizedBox(height: 16),
              _buildFilterChips(AppLocalizations.of(context).t('dog_sizes'), DogSize.values, _preferredDogSizes, (sizes) {
                setState(() => _preferredDogSizes = sizes);
              }),
              const SizedBox(height: 16),
              _buildFilterChips(AppLocalizations.of(context).t('experience_levels'), ExperienceLevel.values, _experienceLevels, (levels) {
                setState(() => _experienceLevels = levels);
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {}); // Refresh the filtered results
            },
            child: Text(AppLocalizations.of(context).t('apply')),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 10).round(),
          onChanged: onChanged,
        ),
        Text('${value.toStringAsFixed(1)}'),
      ],
    );
  }

  Widget _buildFilterChips<T>(String label, List<T> options, List<T> selected, ValueChanged<List<T>> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option.toString().split('.').last),
              selected: isSelected,
              onSelected: (isSelected) {
                final newSelection = List<T>.from(selected);
                if (isSelected) {
                  newSelection.add(option);
                } else {
                  newSelection.remove(option);
                }
                onChanged(newSelection);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _viewWalkerProfile(UserModel walker) {
    // TODO: Navigate to walker profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppLocalizations.of(context).t('viewing_profile_of')} ${walker.fullName}')),
    );
  }

  void _requestWalk(MatchResult match) {
    // TODO: Navigate to walk request form with pre-filled walker
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppLocalizations.of(context).t('requesting_walk_with')} ${match.walker.fullName}')),
    );
  }
}
