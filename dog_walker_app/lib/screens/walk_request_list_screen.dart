import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../models/dog_model.dart';
import '../models/dog_traits.dart';
import '../models/user_model.dart';
import '../services/walk_request_service.dart';
import '../services/dog_service.dart';
import '../services/relevance_scoring_service.dart';
import '../services/auth_provider.dart';
import 'walk_request_form_screen.dart';
import 'walk_request_detail_screen.dart';
import '../l10n/app_localizations.dart';

/// Walk-request list screen.
/// - Adapts tabs/lists to optimize UX for walkers versus owners.
class WalkRequestListScreen extends StatefulWidget {
  final bool isWalker;
  const WalkRequestListScreen({Key? key, required this.isWalker})
    : super(key: key);

  @override
  State<WalkRequestListScreen> createState() => _WalkRequestListScreenState();
}

class _WalkRequestListScreenState extends State<WalkRequestListScreen>
    with SingleTickerProviderStateMixin {
  final WalkRequestService _service = WalkRequestService();
  final DogService _dogService = DogService();
  List<WalkRequestModel> _availableRequests = [];
  List<WalkRequestModel> _filteredAvailableRequests = [];
  List<WalkRequestModel> _acceptedRequests = [];
  bool _loading = true;
  late TabController _tabController;
  
  // Filter state for walkers
  String? _selectedBreed;
  List<DogSize> _selectedSizes = [];
  List<DogTemperament> _selectedTemperaments = [];
  List<EnergyLevel> _selectedEnergyLevels = [];
  List<SpecialNeeds> _selectedSpecialNeeds = [];
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    if (widget.isWalker) {
      _tabController = TabController(length: 2, vsync: this);
    }
    _fetchRequests();
  }

  @override
  void dispose() {
    if (widget.isWalker) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    if (currentUserId == null) return;

    try {
      if (widget.isWalker) {
        // For walkers, fetch both available and accepted requests
        final available = await _service.getAvailableRequests();
        final accepted = await _service.getRequestsByWalker(currentUserId);

        setState(() {
          _availableRequests = available;
          _filteredAvailableRequests = available;
          _acceptedRequests = accepted
              .where(
                (req) =>
                    req.status == WalkRequestStatus.accepted ||
                    req.status == WalkRequestStatus.completed,
              )
              .toList();
          _loading = false;
        });
        // Apply filters and sort by relevance
        await _applyFilters();
      } else {
        // For owners, fetch their own requests
        final reqs = await _service.getRequestsByOwner(currentUserId);
        setState(() {
          _availableRequests = reqs;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.t('err_loading_requests')}: $e')),
      );
    }
  }

  void _onAddRequest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ownerId = auth.currentUserId;
    if (ownerId == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkRequestFormScreen(ownerId: ownerId),
      ),
    );
    if (result == true) _fetchRequests();
  }

  void _onTapRequest(WalkRequestModel req) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WalkRequestDetailScreen(request: req, isWalker: widget.isWalker),
      ),
    );
    if (result == true) _fetchRequests();
  }

  Future<void> _applyFilters() async {
    if (!widget.isWalker) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final walker = auth.userModel;
    if (walker == null || walker.userType != UserType.dogWalker) return;
    
    // If no filters are active, sort by relevance score
    if (_selectedBreed == null &&
        _selectedSizes.isEmpty &&
        _selectedTemperaments.isEmpty &&
        _selectedEnergyLevels.isEmpty &&
        _selectedSpecialNeeds.isEmpty) {
      // Sort by relevance score instead of simple list
      await _sortByRelevance(walker);
      return;
    }
    
    List<({WalkRequestModel request, double relevanceScore})> scoredRequests = [];
    final dogs = <String, DogModel>{};
    
    // Filter by dog attributes and calculate relevance scores
    for (final request in _availableRequests) {
      try {
        final dog = await _dogService.getDogById(request.dogId);
        if (dog == null) continue;
        dogs[request.dogId] = dog;
        
        bool matches = true;
        
        // Filter by breed
        if (_selectedBreed != null && _selectedBreed!.isNotEmpty) {
          if (!dog.breed.toLowerCase().contains(_selectedBreed!.toLowerCase())) {
            matches = false;
          }
        }
        
        // Filter by size
        if (matches && _selectedSizes.isNotEmpty) {
          if (!_selectedSizes.contains(dog.size)) {
            matches = false;
          }
        }
        
        // Filter by temperament
        if (matches && _selectedTemperaments.isNotEmpty) {
          if (!_selectedTemperaments.contains(dog.temperament)) {
            matches = false;
          }
        }
        
        // Filter by energy level
        if (matches && _selectedEnergyLevels.isNotEmpty) {
          if (!_selectedEnergyLevels.contains(dog.energyLevel)) {
            matches = false;
          }
        }
        
        // Filter by special needs
        if (matches && _selectedSpecialNeeds.isNotEmpty) {
          final hasMatchingNeed = _selectedSpecialNeeds.any(
            (need) => dog.specialNeeds.contains(need),
          );
          if (!hasMatchingNeed) {
            matches = false;
          }
        }
        
        if (matches) {
          // Calculate relevance score for ranking
          final relevanceScore = RelevanceScoringService.calculateRelevanceScore(
            walkRequest: request,
            dog: dog,
            walker: walker,
          );
          scoredRequests.add((request: request, relevanceScore: relevanceScore));
        }
      } catch (e) {
        // If dog fetch fails, skip this request
        continue;
      }
    }
    
    // Sort by relevance score (highest first)
    scoredRequests.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    
    setState(() {
      _filteredAvailableRequests = scoredRequests.map((item) => item.request).toList();
    });
  }

  Future<void> _sortByRelevance(UserModel walker) async {
    final dogs = <String, DogModel>{};
    
    // Load all dogs for the requests
    for (final request in _availableRequests) {
      try {
        final dog = await _dogService.getDogById(request.dogId);
        if (dog != null) {
          dogs[request.dogId] = dog;
        }
      } catch (e) {
        continue;
      }
    }
    
    // Sort by relevance score
    final sorted = RelevanceScoringService.sortByRelevance(
      requests: _availableRequests,
      dogs: dogs,
      walker: walker,
    );
    
    setState(() {
      _filteredAvailableRequests = sorted;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Walks'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breed filter
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Breed (optional)',
                    hintText: 'e.g., Golden Retriever',
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedBreed = value.isEmpty ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Size filter
                const Text('Dog Size:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: DogSize.values.map((size) {
                    final isSelected = _selectedSizes.contains(size);
                    return FilterChip(
                      label: Text(size.toString().split('.').last),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedSizes.add(size);
                          } else {
                            _selectedSizes.remove(size);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                // Temperament filter
                const Text('Temperament:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: DogTemperament.values.map((temp) {
                    final isSelected = _selectedTemperaments.contains(temp);
                    return FilterChip(
                      label: Text(temp.toString().split('.').last),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedTemperaments.add(temp);
                          } else {
                            _selectedTemperaments.remove(temp);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                // Energy level filter
                const Text('Energy Level:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: EnergyLevel.values.map((level) {
                    final isSelected = _selectedEnergyLevels.contains(level);
                    return FilterChip(
                      label: Text(level.toString().split('.').last),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedEnergyLevels.add(level);
                          } else {
                            _selectedEnergyLevels.remove(level);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                // Special needs filter
                const Text('Special Needs:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: SpecialNeeds.values.where((n) => n != SpecialNeeds.none).map((need) {
                    final isSelected = _selectedSpecialNeeds.contains(need);
                    return FilterChip(
                      label: Text(need.toString().split('.').last),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _selectedSpecialNeeds.add(need);
                          } else {
                            _selectedSpecialNeeds.remove(need);
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
                  _selectedBreed = null;
                  _selectedSizes.clear();
                  _selectedTemperaments.clear();
                  _selectedEnergyLevels.clear();
                  _selectedSpecialNeeds.clear();
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

  Widget _buildRequestCard(WalkRequestModel req) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          Icons.directions_walk,
          color: _getStatusColor(req.status!),
          size: 32,
        ),
        title: Text(
          req.location,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${req.startTime.day}/${req.startTime.month}/${req.startTime.year} ${AppLocalizations.of(context).t('at')} ${req.startTime.hour}:${req.startTime.minute.toString().padLeft(2, '0')} - ${req.endTime.hour}:${req.endTime.minute.toString().padLeft(2, '0')}',
            ),
            Text(
              '${AppLocalizations.of(context).t('status')}: ${req.status.toString().split(".").last.toUpperCase()}',
              style: TextStyle(
                color: _getStatusColor(req.status!),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: () => _onTapRequest(req),
      ),
    );
  }

  Color _getStatusColor(WalkRequestStatus status) {
    switch (status) {
      case WalkRequestStatus.pending:
        return Colors.orange;
      case WalkRequestStatus.accepted:
        return Colors.green;
      case WalkRequestStatus.completed:
        return Colors.blue;
      case WalkRequestStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (widget.isWalker) {
      return Scaffold(
        appBar: AppBar(
          title: Text(t.t('walk_requests')),
          backgroundColor: Colors.green[600],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: t.t('available_walks')),
              Tab(text: t.t('my_accepted_walks')),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter walks',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchRequests,
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Available Walks Tab
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAvailableRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_alt_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _availableRequests.isEmpty
                              ? t.t('no_available_walks')
                              : 'No walks match your filters',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        if (_availableRequests.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedBreed = null;
                                _selectedSizes.clear();
                                _selectedTemperaments.clear();
                                _selectedEnergyLevels.clear();
                                _selectedSpecialNeeds.clear();
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
                      if (_selectedBreed != null ||
                          _selectedSizes.isNotEmpty ||
                          _selectedTemperaments.isNotEmpty ||
                          _selectedEnergyLevels.isNotEmpty ||
                          _selectedSpecialNeeds.isNotEmpty)
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
                                  '${_filteredAvailableRequests.length} of ${_availableRequests.length} walks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedBreed = null;
                                    _selectedSizes.clear();
                                    _selectedTemperaments.clear();
                                    _selectedEnergyLevels.clear();
                                    _selectedSpecialNeeds.clear();
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
                          itemCount: _filteredAvailableRequests.length,
                          itemBuilder: (context, index) =>
                              _buildRequestCard(_filteredAvailableRequests[index]),
                        ),
                      ),
                    ],
                  ),

            // Accepted Walks Tab
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _acceptedRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.t('no_accepted_walks'),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t('accept_walks_hint'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _acceptedRequests.length,
                    itemBuilder: (context, index) =>
                        _buildRequestCard(_acceptedRequests[index]),
                  ),
          ],
        ),
      );
    } else {
      // Owner view (unchanged)
      return Scaffold(
        appBar: AppBar(
          title: Text(t.t('my_walk_requests')),
          backgroundColor: Colors.green[600],
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchRequests,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _onAddRequest,
          backgroundColor: Colors.green[600],
          child: const Icon(Icons.add, color: Colors.white),
          tooltip: t.t('post_walk_request'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _availableRequests.isEmpty
            ? Center(
                child: Text(
                  t.t('no_walk_requests_yet'),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _availableRequests.length,
                itemBuilder: (context, index) =>
                    _buildRequestCard(_availableRequests[index]),
              ),
      );
    }
  }
}
