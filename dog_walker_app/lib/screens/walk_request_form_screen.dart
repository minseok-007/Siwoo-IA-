import 'package:flutter/material.dart';
import '../models/walk_request_model.dart';
import '../models/dog_model.dart';
import '../services/walk_request_service.dart';
import '../services/dog_service.dart';
import '../l10n/app_localizations.dart';
import 'edit_dog_screen.dart';

/// Form screen for creating or editing a walk request.
/// - Collects core details like date/time, location, and notes.
class WalkRequestFormScreen extends StatefulWidget {
  final String ownerId;
  final WalkRequestModel? request;
  const WalkRequestFormScreen({Key? key, required this.ownerId, this.request})
    : super(key: key);

  @override
  State<WalkRequestFormScreen> createState() => _WalkRequestFormScreenState();
}

class _WalkRequestFormScreenState extends State<WalkRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final DogService _dogService = DogService();

  DateTime? _selectedTime;
  String? _selectedDogId;
  List<DogModel> _userDogs = [];
  bool _saving = false;
  bool _loadingDogs = true;

  @override
  void initState() {
    super.initState();
    _loadUserDogs();
    if (widget.request != null) {
      _locationController.text = widget.request!.location;
      _notesController.text = widget.request!.notes ?? '';
      _selectedTime = widget.request!.time;
      _selectedDogId = widget.request!.dogId;
    }
  }

  /// Loads all dogs belonging to the current user
  Future<void> _loadUserDogs() async {
    try {
      final dogs = await _dogService.getDogsByOwner(widget.ownerId);
      if (!mounted) return;
      setState(() {
        _userDogs = dogs;
        final requestDogId = widget.request?.dogId;
        final currentSelection = _selectedDogId ?? requestDogId;
        if (currentSelection != null &&
            dogs.any((dog) => dog.id == currentSelection)) {
          _selectedDogId = currentSelection;
        } else if (_selectedDogId == null && dogs.length == 1) {
          _selectedDogId = dogs.first.id;
        } else if (_selectedDogId != null &&
            !dogs.any((dog) => dog.id == _selectedDogId)) {
          _selectedDogId = null;
        }
        _loadingDogs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDogs = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dogs: $e')));
      }
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate() ||
        _selectedTime == null ||
        _selectedDogId == null) {
      if (_selectedDogId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a dog for this walk request'),
          ),
        );
      }
      return;
    }
    setState(() => _saving = true);
    final req = WalkRequestModel(
      id:
          widget.request?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      walkerId: widget.request?.walkerId,
      dogId: _selectedDogId!, // Use selected dog ID
      time: _selectedTime!,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      status: widget.request?.status ?? WalkRequestStatus.pending,
      duration: 30, // Default 30 minutes
      budget: 50.0, // Default $50 budget
      createdAt: widget.request?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final service = WalkRequestService();
    if (widget.request == null) {
      await service.addWalkRequest(req);
    } else {
      await service.updateWalkRequest(req);
    }
    setState(() => _saving = false);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTime ?? now),
      );
      if (time != null && mounted) {
        setState(() {
          _selectedTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _handleAddDog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDogScreen(ownerId: widget.ownerId),
      ),
    );
    if (!mounted) return;
    if (result is String) {
      setState(() {
        _selectedDogId = result;
      });
    }
    await _loadUserDogs();
  }

  Widget _buildDogSelector() {
    if (_loadingDogs) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userDogs.isEmpty) {
      return Card(
        color: Colors.orange[50],
        margin: const EdgeInsets.only(bottom: 16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 48, color: Colors.orange[600]),
              const SizedBox(height: 8),
              Text(
                'No dogs registered',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please add a dog profile before creating a walk request.',
                style: TextStyle(color: Colors.orange[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _handleAddDog,
                icon: const Icon(Icons.add),
                label: const Text('Add Dog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Dog *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDogId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pets),
              ),
              hint: const Text('Choose a dog for this walk'),
              items: _userDogs
                  .map(
                    (dog) => DropdownMenuItem<String>(
                      value: dog.id,
                      child: Row(
                        children: [
                          Icon(Icons.pets, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dog.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${dog.breed} • ${dog.age} years old',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  _selectedDogId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a dog for this walk request';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _handleAddDog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Dog'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadUserDogs,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.request != null;
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? t.t('edit_walk_request') : t.t('post_walk_request'),
        ),
        backgroundColor: Colors.green[600],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _buildDogSelector(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: t.t('location'),
                    prefixIcon: const Icon(Icons.location_on),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? t.t('location_required')
                      : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  title: Text(
                    _selectedTime == null
                        ? t.t('select_date_time')
                        : _selectedTime.toString(),
                  ),
                  leading: const Icon(Icons.access_time),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _pickTime,
                  ),
                  onTap: _pickTime,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: t.t('notes_optional'),
                    prefixIcon: const Icon(Icons.note),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveRequest,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    isEdit ? t.t('save_changes') : t.t('post_request'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
