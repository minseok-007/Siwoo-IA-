import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  DateTime? _startTime;
  DateTime? _endTime;
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
      _startTime = widget.request!.startTime;
      _endTime = widget.request!.endTime;
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
        _selectedDogId == null ||
        _startTime == null ||
        _endTime == null) {
      if (_selectedDogId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a dog for this walk request'),
          ),
        );
      }
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose both start and end times'),
          ),
        );
      }
      return;
    }

    if (!_endTime!.isAfter(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final durationMinutes = _endTime!.difference(_startTime!).inMinutes;
    if (durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duration must be greater than zero')),
      );
      return;
    }

    setState(() => _saving = true);
    final req = WalkRequestModel(
      id:
          widget.request?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      walkerId: widget.request?.walkerId,
      dogId: _selectedDogId!,
      startTime: _startTime!,
      endTime: _endTime!,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      status: widget.request?.status ?? WalkRequestStatus.pending,
      duration: durationMinutes,
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

  Future<void> _pickStartDateTime() async {
    final now = DateTime.now();
    final initial = _startTime ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    DateTime newEnd = _endTime ?? newStart.add(const Duration(minutes: 30));
    if (!newEnd.isAfter(newStart)) {
      newEnd = newStart.add(const Duration(minutes: 30));
    }

    setState(() {
      _startTime = newStart;
      _endTime = newEnd;
    });
  }

  Future<void> _pickEndDateTime() async {
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a start time first')),
      );
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _endTime ?? _startTime!.add(const Duration(minutes: 30)),
      ),
    );
    if (pickedTime == null || !mounted) return;

    final end = DateTime(
      _startTime!.year,
      _startTime!.month,
      _startTime!.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!end.isAfter(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() {
      _endTime = end;
    });
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
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Choose a dog for this walk'),
              items: _userDogs
                  .map(
                    (dog) => DropdownMenuItem<String>(
                      value: dog.id,
                      child: Row(
                        children: [
                          Icon(Icons.pets, color: Colors.blue[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dog.name} (${dog.breed}, ${dog.age}y)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  leading: const Icon(Icons.play_arrow),
                  title: Text(
                    _startTime == null
                        ? 'Select start time'
                        : DateFormat(
                            'MMM d, yyyy • h:mm a',
                          ).format(_startTime!),
                  ),
                  onTap: _pickStartDateTime,
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  leading: const Icon(Icons.stop),
                  title: Text(
                    _endTime == null
                        ? 'Select end time'
                        : DateFormat('MMM d, yyyy • h:mm a').format(_endTime!),
                  ),
                  onTap: _pickEndDateTime,
                ),
                if (_startTime != null && _endTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text(
                      'Duration: ${_endTime!.difference(_startTime!).inMinutes} minutes',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  )
                else
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
                const SizedBox(height: 16),
                const SizedBox(height: 16),
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
