import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/walk_request_model.dart';
import '../services/recommendation_service.dart';
import '../services/user_service.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import 'walk_request_detail_screen.dart';
import 'walker_profile_view_screen.dart';

/// Screen for displaying AI-powered recommendations using Collaborative Filtering.
/// 
/// Shows recommended walkers for owners and recommended walk requests for walkers.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({Key? key}) : super(key: key);

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationService _recommendationService = RecommendationService();
  final UserService _userService = UserService();
  final WalkRequestService _walkRequestService = WalkRequestService();

  List<RecommendationResult> _walkerRecommendations = [];
  List<WalkRequestRecommendation> _requestRecommendations = [];
  bool _loading = true;
  String? _error;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.currentUserId;
      if (currentUserId == null) {
        setState(() {
          _error = 'User not authenticated';
          _loading = false;
        });
        return;
      }

      final user = await _userService.getUserById(currentUserId);
      if (user == null) {
        setState(() {
          _error = 'User not found';
          _loading = false;
        });
        return;
      }

      _currentUser = user;

      if (user.userType == UserType.dogOwner) {
        // Get all walkers for recommendation
        final allWalkers = await _userService.getAllWalkers();
        
        // Get recommendations using collaborative filtering
        final recommendations = await _recommendationService.recommendWalkersForOwner(
          ownerId: currentUserId,
          allWalkers: allWalkers,
          kNeighbors: 5,
          maxRecommendations: 10,
        );

        if (!mounted) return;
        setState(() {
          _walkerRecommendations = recommendations;
          _loading = false;
        });
      } else {
        // Get available walk requests
        final availableRequests = await _walkRequestService.getAvailableRequests();
        
        // Get recommendations using collaborative filtering
        final recommendations = await _recommendationService.recommendWalkRequestsForWalker(
          walkerId: currentUserId,
          availableRequests: availableRequests,
          kNeighbors: 5,
          maxRecommendations: 10,
        );

        if (!mounted) return;
        setState(() {
          _requestRecommendations = recommendations;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error loading recommendations: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recommendations'),
        backgroundColor: Colors.purple[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
            tooltip: 'Refresh recommendations',
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
                        onPressed: _loadRecommendations,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _currentUser?.userType == UserType.dogOwner
                  ? _buildWalkerRecommendations()
                  : _buildRequestRecommendations(),
    );
  }

  Widget _buildWalkerRecommendations() {
    if (_walkerRecommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No recommendations yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'More reviews and interactions will improve recommendations',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildInfoCard(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _walkerRecommendations.length,
            itemBuilder: (context, index) {
              return _buildWalkerRecommendationCard(_walkerRecommendations[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestRecommendations() {
    if (_requestRecommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.recommend_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No recommendations yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'More walk history will improve recommendations',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildInfoCard(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _requestRecommendations.length,
            itemBuilder: (context, index) {
              return _buildRequestRecommendationCard(_requestRecommendations[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI-Powered Recommendations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.userType == UserType.dogOwner
                        ? 'Based on similar owners\' preferences'
                        : 'Based on similar walkers\' choices',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkerRecommendationCard(RecommendationResult recommendation) {
    final walker = recommendation.user;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.purple[100],
                  child: Text(
                    walker.fullName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${(recommendation.predictedRating * 20).toInt()}%',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Match',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Why recommended:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.reason,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.trending_up, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Confidence: ${(recommendation.confidence * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewWalkerProfile(walker),
                    child: const Text('View Profile'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _viewWalkerProfile(walker),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                    ),
                    child: const Text('Contact'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestRecommendationCard(WalkRequestRecommendation recommendation) {
    final request = recommendation.walkRequest;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewWalkRequest(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.location,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${request.startTime.toString().substring(0, 16)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(recommendation.recommendationScore * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation.reason,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _viewWalkRequest(request),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewWalkerProfile(UserModel walker) async {
    // Navigate to walker profile
    // This would need to be implemented based on your profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing profile of ${walker.fullName}')),
    );
  }

  Future<void> _viewWalkRequest(WalkRequestModel request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkRequestDetailScreen(
          request: request,
          isWalker: true,
        ),
      ),
    );
    _loadRecommendations(); // Refresh after returning
  }
}
