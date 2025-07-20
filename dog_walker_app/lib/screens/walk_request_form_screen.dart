import 'package:flutter/material.dart';
import '../models/walk_request_model.dart';
import '../services/walk_request_service.dart';

class WalkRequestFormScreen extends StatefulWidget {
  final String ownerId;
  final WalkRequestModel? request;
  const WalkRequestFormScreen({Key? key, required this.ownerId, this.request}) : super(key: key);

  @override
  State<WalkRequestFormScreen> createState() => _WalkRequestFormScreenState();
}

class _WalkRequestFormScreenState extends State<WalkRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.request != null) {
      _locationController.text = widget.request!.location;
      _notesController.text = widget.request!.notes ?? '';
      _selectedTime = widget.request!.time;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveRequest() async {
    if (!_formKey.currentState!.validate() || _selectedTime == null) return;
    setState(() => _saving = true);
    final req = WalkRequestModel(
      id: widget.request?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      walkerId: widget.request?.walkerId,
      dogId: widget.request?.dogId ?? '', // TODO: Add dog selection
      time: _selectedTime!,
      location: _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      status: widget.request?.status ?? WalkRequestStatus.pending,
    );
    final service = WalkRequestService();
    if (widget.request == null) {
      await service.addWalkRequest(req);
    } else {
      await service.updateWalkRequest(req);
    }
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTime ?? now),
      );
      if (time != null) {
        setState(() {
          _selectedTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.request != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Walk Request' : 'Post Walk Request'),
        backgroundColor: Colors.green[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Location required' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_selectedTime == null
                    ? 'Select Date & Time'
                    : _selectedTime.toString()),
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
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(isEdit ? 'Save Changes' : 'Post Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 