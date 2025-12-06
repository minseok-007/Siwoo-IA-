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
  List<WalkRequestModel> _pastRequests = []; // For owners: past walk requests
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
    } else {
      // For owners, we need 2 tabs: current and past
      _tabController = TabController(length: 2, vsync: this);
    }
    _fetchRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    if (currentUserId == null) return;

    try {
      final now = DateTime.now();
      
      if (widget.isWalker) {
        // For walkers, fetch both available and accepted requests
        final available = await _service.getAvailableRequests();
        final accepted = await _service.getRequestsByWalker(currentUserId);

        // Filter out past requests from available (only show future)
        final futureAvailable = available
            .where((req) => req.startTime.isAfter(now))
            .toList();
        
        // Filter accepted requests: only future ones
        final futureAccepted = accepted
            .where(
              (req) =>
                  (req.status == WalkRequestStatus.accepted ||
                   req.status == WalkRequestStatus.completed) &&
                  req.startTime.isAfter(now),
            )
            .toList();
        
        // Sort by start time (ascending - earliest first)
        futureAvailable.sort((a, b) => a.startTime.compareTo(b.startTime));
        futureAccepted.sort((a, b) => a.startTime.compareTo(b.startTime));

        setState(() {
          _availableRequests = futureAvailable;
          _filteredAvailableRequests = futureAvailable;
          _acceptedRequests = futureAccepted;
          _loading = false;
        });
        // Apply filters and sort by relevance
        await _applyFilters();
      } else {
        // For owners, fetch their own requests and separate past/future
        final reqs = await _service.getRequestsByOwner(currentUserId);
        
        // Separate into future and past
        final futureRequests = reqs
            .where((req) => req.startTime.isAfter(now))
            .toList();
        final pastRequests = reqs
            .where((req) => req.startTime.isBefore(now) || req.startTime.isAtSameMomentAs(now))
            .toList();
        
        // Sort by start time (ascending - earliest first for future, descending for past)
        futureRequests.sort((a, b) => a.startTime.compareTo(b.startTime));
        pastRequests.sort((a, b) => b.startTime.compareTo(a.startTime));

        setState(() {
          _availableRequests = futureRequests;
          _pastRequests = pastRequests;
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
    
    // Sort by relevance score (highest first), then by start time (earliest first)
    scoredRequests.sort((a, b) {
      final scoreCompare = b.relevanceScore.compareTo(a.relevanceScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.request.startTime.compareTo(b.request.startTime);
    });
    
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
    
    // Additional sort by start time (earliest first) for same relevance scores
    sorted.sort((a, b) {
      // First check if we have relevance scores (if sortByRelevance returns scored list)
      // Since sortByRelevance returns List<WalkRequestModel>, we need to recalculate for tie-breaking
      final aScore = RelevanceScoringService.calculateRelevanceScore(
        walkRequest: a,
        dog: dogs[a.dogId]!,
        walker: walker,
      );
      final bScore = RelevanceScoringService.calculateRelevanceScore(
        walkRequest: b,
        dog: dogs[b.dogId]!,
        walker: walker,
      );
      final scoreCompare = bScore.compareTo(aScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.startTime.compareTo(b.startTime);
    });
    
    setState(() {
      _filteredAvailableRequests = sorted;
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: const Text(
                        'Filter by Dog Characteristics',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedBreed != null ||
                        _selectedSizes.isNotEmpty ||
                        _selectedTemperaments.isNotEmpty ||
                        _selectedEnergyLevels.isNotEmpty ||
                        _selectedSpecialNeeds.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedBreed = null;
                            _selectedSizes.clear();
                            _selectedTemperaments.clear();
                            _selectedEnergyLevels.clear();
                            _selectedSpecialNeeds.clear();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear All'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Filter content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breed filter
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Breed (optional)',
                          hintText: 'e.g., Golden Retriever',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            _selectedBreed = value.isEmpty ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // Size filter
                      _buildFilterChips<DogSize>(
                        'Size',
                        DogSize.values,
                        _selectedSizes,
                        (size) => size.toString().split('.').last,
                        (size) {
                          setModalState(() {
                            if (_selectedSizes.contains(size)) {
                              _selectedSizes.remove(size);
                            } else {
                              _selectedSizes.add(size);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // Temperament filter
                      _buildFilterChips<DogTemperament>(
                        'Temperament',
                        DogTemperament.values,
                        _selectedTemperaments,
                        (temp) => temp.toString().split('.').last,
                        (temp) {
                          setModalState(() {
                            if (_selectedTemperaments.contains(temp)) {
                              _selectedTemperaments.remove(temp);
                            } else {
                              _selectedTemperaments.add(temp);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // Energy level filter
                      _buildFilterChips<EnergyLevel>(
                        'Energy Level',
                        EnergyLevel.values,
                        _selectedEnergyLevels,
                        (level) => level.toString().split('.').last,
                        (level) {
                          setModalState(() {
                            if (_selectedEnergyLevels.contains(level)) {
                              _selectedEnergyLevels.remove(level);
                            } else {
                              _selectedEnergyLevels.add(level);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // Special needs filter
                      _buildFilterChips<SpecialNeeds>(
                        'Special Needs',
                        SpecialNeeds.values.where((n) => n != SpecialNeeds.none).toList(),
                        _selectedSpecialNeeds,
                        (need) => need.toString().split('.').last,
                        (need) {
                          setModalState(() {
                            if (_selectedSpecialNeeds.contains(need)) {
                              _selectedSpecialNeeds.remove(need);
                            } else {
                              _selectedSpecialNeeds.add(need);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 100), // Space for button
                    ],
                  ),
                ),
              ),
              // Apply button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips<T>(
    String label,
    List<T> options,
    List<T> selected,
    String Function(T) labelBuilder,
    void Function(T) onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(labelBuilder(option)),
              selected: isSelected,
              onSelected: (_) => onToggle(option),
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[700],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFilterButton() {
    final hasActiveFilters = _selectedBreed != null ||
        _selectedSizes.isNotEmpty ||
        _selectedTemperaments.isNotEmpty ||
        _selectedEnergyLevels.isNotEmpty ||
        _selectedSpecialNeeds.isNotEmpty;

    final filterCount = (_selectedBreed != null ? 1 : 0) +
        _selectedSizes.length +
        _selectedTemperaments.length +
        _selectedEnergyLevels.length +
        _selectedSpecialNeeds.length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: _showFilterDialog,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.filter_list,
                color: hasActiveFilters ? Colors.green[700] : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter by Dog Characteristics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$filterCount filter${filterCount > 1 ? 's' : ''} active',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tap to filter by size, temperament, energy, and more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
            ],
          ),
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
                : Column(
                    children: [
                      _buildFilterButton(),
                      Expanded(
                        child: _filteredAvailableRequests.isEmpty
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
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredAvailableRequests.length,
                            itemBuilder: (context, index) =>
                                _buildRequestCard(_filteredAvailableRequests[index]),
                          ),
                      ),
                    ],
                  ),

            // Accepted Walks Tab (only future)
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
      // Owner view with tabs for current and past
      return Scaffold(
        appBar: AppBar(
          title: Text(t.t('my_walk_requests')),
          backgroundColor: Colors.green[600],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: 'Current'),
              const Tab(text: 'Past'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
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
        body: TabBarView(
          controller: _tabController,
          children: [
            // Current (Future) Requests Tab
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _availableRequests.isEmpty
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
                          t.t('no_walk_requests_yet'),
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableRequests.length,
                    itemBuilder: (context, index) =>
                        _buildRequestCard(_availableRequests[index]),
                  ),
            
            // Past Requests Tab
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _pastRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No past walk requests',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pastRequests.length,
                    itemBuilder: (context, index) =>
                        _buildRequestCard(_pastRequests[index]),
                  ),
          ],
        ),
      );
    }
  }
}
