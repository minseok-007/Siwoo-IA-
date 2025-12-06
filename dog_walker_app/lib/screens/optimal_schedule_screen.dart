import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/walk_request_model.dart';
import '../models/user_model.dart';
import '../models/dog_model.dart';
import '../models/dog_traits.dart';
import '../services/optimal_scheduling_service.dart';
import '../services/walk_request_service.dart';
import '../services/user_service.dart';
import '../services/dog_service.dart';
import '../services/auth_provider.dart';
import 'walk_request_detail_screen.dart';

/// Screen for walkers to view optimal schedule suggestions.
/// Uses Dynamic Programming to find the best combination of walks.
class OptimalScheduleScreen extends StatefulWidget {
  const OptimalScheduleScreen({Key? key}) : super(key: key);

  @override
  State<OptimalScheduleScreen> createState() => _OptimalScheduleScreenState();
}

class _OptimalScheduleScreenState extends State<OptimalScheduleScreen> {
  final WalkRequestService _walkRequestService = WalkRequestService();
  final UserService _userService = UserService();
  final DogService _dogService = DogService();

  List<WalkRequestModel> _availableWalks = [];
  List<WalkRequestModel> _filteredWalks = [];
  OptimalScheduleResult? _optimalSchedule;
  Map<String, UserModel> _owners = {};
  Map<String, DogModel> _dogs = {};
  bool _loading = true;
  UserModel? _currentWalker;
  
  // Dog characteristic filters
  List<DogSize> _selectedSizes = [];
  List<DogTemperament> _selectedTemperaments = [];
  List<EnergyLevel> _selectedEnergyLevels = [];
  List<SpecialNeeds> _selectedSpecialNeeds = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.currentUserId;
      if (currentUserId == null) return;

      final walker = await _userService.getUserById(currentUserId);
      if (walker == null || walker.userType != UserType.dogWalker) return;

      _currentWalker = walker;

      // Load available walk requests
      final availableWalks = await _walkRequestService.getAvailableRequests();

      // Load owner and dog information
      final owners = <String, UserModel>{};
      final dogs = <String, DogModel>{};

      for (final walk in availableWalks) {
        if (!owners.containsKey(walk.ownerId)) {
          final owner = await _userService.getUserById(walk.ownerId);
          if (owner != null) owners[walk.ownerId] = owner;
        }
        if (!dogs.containsKey(walk.dogId)) {
          final dog = await _dogService.getDogById(walk.dogId);
          if (dog != null) dogs[walk.dogId] = dog;
        }
      }

      if (!mounted) return;
      setState(() {
        _availableWalks = availableWalks;
        _owners = owners;
        _dogs = dogs;
        _loading = false;
      });

      _applyFilters();
      _calculateOptimalSchedule();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
        ),
      );
    }
  }

  void _applyFilters() {
    List<WalkRequestModel> filtered = List.from(_availableWalks);

    if (_selectedSizes.isNotEmpty ||
        _selectedTemperaments.isNotEmpty ||
        _selectedEnergyLevels.isNotEmpty ||
        _selectedSpecialNeeds.isNotEmpty) {
      filtered = filtered.where((walk) {
        final dog = _dogs[walk.dogId];
        if (dog == null) return false;

        // Filter by size
        if (_selectedSizes.isNotEmpty && !_selectedSizes.contains(dog.size)) {
          return false;
        }

        // Filter by temperament
        if (_selectedTemperaments.isNotEmpty &&
            !_selectedTemperaments.contains(dog.temperament)) {
          return false;
        }

        // Filter by energy level
        if (_selectedEnergyLevels.isNotEmpty &&
            !_selectedEnergyLevels.contains(dog.energyLevel)) {
          return false;
        }

        // Filter by special needs
        if (_selectedSpecialNeeds.isNotEmpty) {
          final hasMatchingNeed = _selectedSpecialNeeds.any(
            (need) => dog.specialNeeds.contains(need),
          );
          if (!hasMatchingNeed) return false;
        }

        return true;
      }).toList();
    }

    setState(() {
      _filteredWalks = filtered;
    });
  }

  void _calculateOptimalSchedule() {
    if (_currentWalker == null) {
      print('❌ No walker found');
      return;
    }

    print('🧮 Calculating optimal schedule for ${_filteredWalks.length} walks...');
    
    final result = OptimalSchedulingService.findOptimalSchedule(
      availableWalks: _filteredWalks,
      walker: _currentWalker!,
      startDate: null,
      endDate: null,
    );

    print('✅ Optimal schedule: ${result.totalWalks} walks, value: ${result.totalValue}');

    setState(() {
      _optimalSchedule = result;
    });
  }

  Future<void> _viewWalkDetails(WalkRequestModel walk) async {
    final owner = _owners[walk.ownerId];
    if (owner == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkRequestDetailScreen(
          request: walk,
          isWalker: true,
        ),
      ),
    );
    _loadData(); // Refresh after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimal Schedule'),
        backgroundColor: Colors.indigo[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterButton(),
                _buildStatsCard(),
                Expanded(
                  child: _optimalSchedule == null ||
                          _optimalSchedule!.selectedWalks.isEmpty
                      ? _buildEmptyState()
                      : _buildScheduleList(),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterButton() {
    final hasActiveFilters = _selectedSizes.isNotEmpty ||
        _selectedTemperaments.isNotEmpty ||
        _selectedEnergyLevels.isNotEmpty ||
        _selectedSpecialNeeds.isNotEmpty;

    final filterCount = _selectedSizes.length +
        _selectedTemperaments.length +
        _selectedEnergyLevels.length +
        _selectedSpecialNeeds.length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: _showFilterBottomSheet,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.filter_list,
                color: hasActiveFilters ? Colors.blue[700] : Colors.grey[600],
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
                          color: Colors.blue[700],
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

  void _showFilterBottomSheet() {
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
                    if (_selectedSizes.isNotEmpty ||
                        _selectedTemperaments.isNotEmpty ||
                        _selectedEnergyLevels.isNotEmpty ||
                        _selectedSpecialNeeds.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setModalState(() {
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
                        SpecialNeeds.values
                            .where((n) => n != SpecialNeeds.none)
                            .toList(),
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
                        _calculateOptimalSchedule();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
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
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[700],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    if (_optimalSchedule == null) {
      return const SizedBox.shrink();
    }

    final result = _optimalSchedule!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Selected Walks',
                '${result.totalWalks}',
                Icons.directions_walk,
                Colors.blue,
              ),
            ),
            Expanded(
              child: Tooltip(
                message: 'Total value score of selected walks\n(calculated from duration, rating, and urgency)',
                child: _buildStatItem(
                  'Total Value',
                  result.totalValue.toStringAsFixed(0),
                  Icons.star,
                  Colors.amber,
                ),
              ),
            ),
            Expanded(
              child: _buildStatItem(
                'Available',
                '${_filteredWalks.length}',
                Icons.list,
                Colors.green,
              ),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _availableWalks.isEmpty
                ? 'No available walks'
                : _filteredWalks.isEmpty
                    ? 'No walks match your filters'
                    : 'No optimal schedule found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _availableWalks.isEmpty
                ? 'Check back later for new walk requests'
                : _filteredWalks.isEmpty
                    ? 'Try adjusting your filters'
                    : 'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_optimalSchedule == null) return const SizedBox.shrink();

    final selectedWalks = _optimalSchedule!.selectedWalks;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: selectedWalks.length,
      itemBuilder: (context, index) {
        final walk = selectedWalks[index];
        final owner = _owners[walk.ownerId];
        final dog = _dogs[walk.dogId];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _viewWalkDetails(walk),
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
                              owner?.fullName ?? 'Unknown Owner',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (dog != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${dog.name} • ${dog.size.toString().split('.').last}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Optimal',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('MMM d, y • h:mm a').format(walk.startTime)} - ${DateFormat('h:mm a').format(walk.endTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          walk.location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _viewWalkDetails(walk),
                        child: const Text('View Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
