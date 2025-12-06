import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/dog_model.dart';
import '../models/walk_request_model.dart';
import '../services/integrated_matching_service.dart';
import '../services/auth_provider.dart';
import '../services/user_service.dart';
import '../services/dog_service.dart';
import '../services/walk_request_service.dart';
import '../l10n/app_localizations.dart';

class OptimizedMatchingScreen extends StatefulWidget {
  const OptimizedMatchingScreen({Key? key}) : super(key: key);

  @override
  State<OptimizedMatchingScreen> createState() =>
      _OptimizedMatchingScreenState();
}

class _OptimizedMatchingScreenState extends State<OptimizedMatchingScreen>
    with TickerProviderStateMixin {
  final IntegratedMatchingService _matchingService =
      IntegratedMatchingService();
  final UserService _userService = UserService();
  final DogService _dogService = DogService();
  final WalkRequestService _walkService = WalkRequestService();

  List<IntegratedMatch> _matches = [];
  bool _loading = true;
  String? _error;
  String _selectedMethod = 'integrated';

  double _minScore = 0.5;
  double _maxDistance = 20.0;
  bool _useLocationFiltering = true;
  bool _realTimeMatching = false;

  UserModel? _currentUser;
  List<DogModel> _userDogs = [];
  WalkRequestModel? _currentWalkRequest;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Timer? _realTimeTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _realTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _loading = true);

      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user == null) {
        setState(() => _error = 'User not authenticated');
        return;
      }

      _currentUser = user;

      if (user.userType == UserType.dogOwner) {
        _userDogs = await _dogService.getDogsByOwner(user.id);

        final requests = await _walkService.getRequestsByOwner(user.id);
        _currentWalkRequest = requests
            .where(
              (r) =>
                  r.status == WalkRequestStatus.pending ||
                  r.status == WalkRequestStatus.accepted,
            )
            .firstOrNull;
      }

      await _findMatches();
    } catch (e) {
      setState(() => _error = 'Error loading data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _findMatches() async {
    try {
      if (_currentUser == null || _currentUser!.userType != UserType.dogOwner)
        return;
      if (_userDogs.isEmpty) return;

      final dog = _userDogs.first;

      if (_realTimeMatching) {
        await _startRealTimeMatching();
      } else {
        await _executeOptimizedMatching(dog);
      }
    } catch (e) {
      setState(() => _error = 'Error finding matches: $e');
    }
  }

  Future<void> _executeOptimizedMatching(DogModel dog) async {
    if (_currentWalkRequest == null) {
      final start = DateTime.now().add(const Duration(days: 1, hours: 2));
      _currentWalkRequest = WalkRequestModel(
        id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
        ownerId: _currentUser!.id,
        dogId: dog.id,
        location: 'Sample Location',
        startTime: start,
        endTime: start.add(const Duration(minutes: 30)),
        duration: 30,
        notes: 'Sample walk request note',
        status: WalkRequestStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    final result = await _matchingService.findOptimalMatches(
      walkRequest: _currentWalkRequest!,
      owner: _currentUser!,
      dog: dog,
      maxResults: 20,
      useLocationFiltering: _useLocationFiltering,
    );

    setState(() {
      _matches = result.matches;
      _error = result.error;
    });

    _animationController.forward();
  }

  Future<void> _startRealTimeMatching() async {
    if (_currentUser == null) return;

    await _matchingService.locationService.startLocationTracking(
      _currentUser!.id,
    );

    final matches = await _matchingService.findRealTimeMatches(
      userId: _currentUser!.id,
      maxDistance: _maxDistance,
      preferredDogSizes: _userDogs.map((dog) => dog.size).toList(),
      maxResults: 10,
    );

    setState(() => _matches = matches);
    _animationController.forward();

    _realTimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final newMatches = await _matchingService.findRealTimeMatches(
        userId: _currentUser!.id,
        maxDistance: _maxDistance,
        preferredDogSizes: _userDogs.map((dog) => dog.size).toList(),
        maxResults: 10,
      );

      if (mounted) {
        setState(() => _matches = newMatches);
      }
    });
  }

  List<IntegratedMatch> _getFilteredMatches() {
    return _matches.where((match) {
      if (match.score < _minScore) return false;
      if (match.distance > _maxDistance) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _getFilteredMatches();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimized Matching'),
        backgroundColor: Colors.indigo[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _findMatches),
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
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildMethodSelector(),
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
            ),
    );
  }

  Widget _buildMethodSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Matching Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Weighted Scoring'),
                    subtitle: const Text('Multi-factor matching'),
                    value: 'integrated',
                    groupValue: _selectedMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedMethod = value!;
                        _realTimeMatching = false;
                        _realTimeTimer?.cancel();
                      });
                      _findMatches();
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Real-time Matching'),
                    subtitle: const Text('Location Based'),
                    value: 'realtime',
                    groupValue: _selectedMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedMethod = value!;
                        _realTimeMatching = true;
                      });
                      _findMatches();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildStatsCard(List<IntegratedMatch> matches) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Matching Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Matches',
                    '${matches.length}',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'High Score',
                    '${matches.where((m) => m.score > 0.8).length}',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Nearby',
                    '${matches.where((m) => m.distance < 5.0).length}',
                    Icons.location_on,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Real-time',
                    '${matches.where((m) => m.isRealTime).length}',
                    Icons.sync,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMatchCard(IntegratedMatch match) {
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
                      Row(
                        children: [
                          Text(
                            match.walker.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (match.isRealTime) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${match.walker.experienceLevel.toString().split('.').last} Walker',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      Text(
                        '${match.distance.toStringAsFixed(1)} km away',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMatchDetails(match),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewWalkerProfile(match.walker),
                    icon: const Icon(Icons.person),
                    label: const Text('View Profile'),
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
                    label: const Text('Request Walk'),
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

  Widget _buildMatchDetails(IntegratedMatch match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Match Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildDetailChip(
              'Distance',
              '${match.distance.toStringAsFixed(1)} km',
              Icons.location_on,
              Colors.blue,
            ),
            _buildDetailChip(
              'Rating',
              '${match.walker.rating.toStringAsFixed(1)}/5',
              Icons.star,
              Colors.amber,
            ),
            _buildDetailChip(
              'Experience',
              match.walker.experienceLevel.toString().split('.').last,
              Icons.work,
              Colors.green,
            ),
            if (match.isRealTime)
              _buildDetailChip('Real-time', 'Live', Icons.sync, Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailChip(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
            'No matches found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting filters or refresh',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
        title: const Text('Filter Matches'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterSlider(
                'Minimum Score',
                _minScore,
                0.0,
                1.0,
                (value) => setState(() => _minScore = value),
              ),
              _buildFilterSlider(
                'Max Distance (km)',
                _maxDistance,
                1.0,
                50.0,
                (value) => setState(() => _maxDistance = value),
              ),
              SwitchListTile(
                title: const Text('Use Location Filtering'),
                subtitle: const Text('Filter by location'),
                value: _useLocationFiltering,
                onChanged: (value) =>
                    setState(() => _useLocationFiltering = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _findMatches();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
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

  void _viewWalkerProfile(UserModel walker) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing profile of ${walker.fullName}')),
    );
  }

  void _requestWalk(IntegratedMatch match) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Requesting walk with ${match.walker.fullName}')),
    );
  }
}
