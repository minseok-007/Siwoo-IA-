import 'package:flutter/material.dart';
import '../models/dog_model.dart';
import '../models/user_model.dart';
import '../services/dog_service.dart';
import '../l10n/app_localizations.dart';

/// Screen for adding or editing a dog profile.
/// - Accepts an optional `dog` so creation and edits share the same UI.
/// - Uses form validation to preserve data integrity.
class EditDogScreen extends StatefulWidget {
  final String ownerId;
  final DogModel? dog;
  const EditDogScreen({Key? key, required this.ownerId, this.dog})
    : super(key: key);

  @override
  State<EditDogScreen> createState() => _EditDogScreenState();
}

class _EditDogScreenState extends State<EditDogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _vetContactController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _trainingCommandsController = TextEditingController();

  // Form state variables
  DogSize _selectedSize = DogSize.medium;
  DogTemperament _selectedTemperament = DogTemperament.friendly;
  EnergyLevel _selectedEnergyLevel = EnergyLevel.medium;
  List<SpecialNeeds> _selectedSpecialNeeds = [];
  bool _isNeutered = false;
  bool _isGoodWithOtherDogs = true;
  bool _isGoodWithChildren = true;
  bool _isGoodWithStrangers = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.dog != null) {
      final dog = widget.dog!;
      _nameController.text = dog.name;
      _breedController.text = dog.breed;
      _ageController.text = dog.age.toString();
      _photoUrlController.text = dog.profileImageUrl ?? '';
      _descriptionController.text = dog.description ?? '';
      _weightController.text = dog.weight.toString();
      _vetContactController.text = dog.vetContact ?? '';
      _emergencyContactController.text = dog.emergencyContact ?? '';
      _medicalConditionsController.text = dog.medicalConditions.join(', ');
      _trainingCommandsController.text = dog.trainingCommands.join(', ');

      _selectedSize = dog.size;
      _selectedTemperament = dog.temperament;
      _selectedEnergyLevel = dog.energyLevel;
      _selectedSpecialNeeds = List.from(dog.specialNeeds);
      _isNeutered = dog.isNeutered;
      _isGoodWithOtherDogs = dog.isGoodWithOtherDogs;
      _isGoodWithChildren = dog.isGoodWithChildren;
      _isGoodWithStrangers = dog.isGoodWithStrangers;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _photoUrlController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _vetContactController.dispose();
    _emergencyContactController.dispose();
    _medicalConditionsController.dispose();
    _trainingCommandsController.dispose();
    super.dispose();
  }

  /// Validates the input and saves it to Firestore.
  /// - Chooses between add vs update depending on whether a dog already exists.
  Future<void> _saveDog() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Parse comma-separated lists
    final medicalConditions = _medicalConditionsController.text
        .trim()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final trainingCommands = _trainingCommandsController.text
        .trim()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final dog = DogModel(
      id: widget.dog?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      name: _nameController.text.trim(),
      breed: _breedController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      profileImageUrl: _photoUrlController.text.trim().isEmpty
          ? null
          : _photoUrlController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      size: _selectedSize,
      temperament: _selectedTemperament,
      energyLevel: _selectedEnergyLevel,
      specialNeeds: _selectedSpecialNeeds,
      weight: double.tryParse(_weightController.text.trim()) ?? 0.0,
      isNeutered: _isNeutered,
      medicalConditions: medicalConditions,
      trainingCommands: trainingCommands,
      isGoodWithOtherDogs: _isGoodWithOtherDogs,
      isGoodWithChildren: _isGoodWithChildren,
      isGoodWithStrangers: _isGoodWithStrangers,
      vetContact: _vetContactController.text.trim().isEmpty
          ? null
          : _vetContactController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim().isEmpty
          ? null
          : _emergencyContactController.text.trim(),
      createdAt: widget.dog?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final dogService = DogService();
    if (widget.dog == null) {
      await dogService.addDog(dog);
    } else {
      await dogService.updateDog(dog);
    }
    setState(() => _saving = false);
    if (mounted) {
      Navigator.pop(context, dog.id);
    }
  }

  /// Helper method to create section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.dog != null;
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? t.t('edit_dog') : t.t('add_dog')),
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: t.t('dog_name'),
                  prefixIcon: const Icon(Icons.pets),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? t.t('name_required') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: InputDecoration(
                  labelText: t.t('breed'),
                  prefixIcon: const Icon(Icons.category),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? t.t('breed_required')
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      decoration: InputDecoration(
                        labelText: t.t('age'),
                        prefixIcon: const Icon(Icons.cake),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final age = int.tryParse(v ?? '');
                        if (age == null || age < 0)
                          return t.t('enter_valid_age');
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        prefixIcon: const Icon(Icons.fitness_center),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final weight = double.tryParse(v ?? '');
                        if (weight == null || weight <= 0)
                          return 'Enter valid weight';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: const Icon(Icons.description),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Physical Characteristics Section
              _buildSectionHeader('Physical Characteristics'),
              DropdownButtonFormField<DogSize>(
                value: _selectedSize,
                decoration: const InputDecoration(
                  labelText: 'Size',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                ),
                items: DogSize.values.map((size) {
                  return DropdownMenuItem<DogSize>(
                    value: size,
                    child: Text(size.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedSize = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DogTemperament>(
                value: _selectedTemperament,
                decoration: const InputDecoration(
                  labelText: 'Temperament',
                  prefixIcon: Icon(Icons.psychology),
                  border: OutlineInputBorder(),
                ),
                items: DogTemperament.values.map((temperament) {
                  return DropdownMenuItem<DogTemperament>(
                    value: temperament,
                    child: Text(temperament.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedTemperament = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EnergyLevel>(
                value: _selectedEnergyLevel,
                decoration: const InputDecoration(
                  labelText: 'Energy Level',
                  prefixIcon: Icon(Icons.battery_charging_full),
                  border: OutlineInputBorder(),
                ),
                items: EnergyLevel.values.map((level) {
                  return DropdownMenuItem<EnergyLevel>(
                    value: level,
                    child: Text(level.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedEnergyLevel = value!),
              ),
              const SizedBox(height: 24),

              // Special Needs Section
              _buildSectionHeader('Special Needs'),
              Wrap(
                spacing: 8,
                children: SpecialNeeds.values.map((need) {
                  return FilterChip(
                    label: Text(need.name.toUpperCase()),
                    selected: _selectedSpecialNeeds.contains(need),
                    onSelected: (selected) {
                      setState(() {
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
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Neutered/Spayed'),
                subtitle: const Text('Is this dog neutered or spayed?'),
                value: _isNeutered,
                onChanged: (value) => setState(() => _isNeutered = value),
              ),
              const SizedBox(height: 24),

              // Social Behavior Section
              _buildSectionHeader('Social Behavior'),
              SwitchListTile(
                title: const Text('Good with other dogs'),
                subtitle: const Text(
                  'Does this dog get along with other dogs?',
                ),
                value: _isGoodWithOtherDogs,
                onChanged: (value) =>
                    setState(() => _isGoodWithOtherDogs = value),
              ),
              SwitchListTile(
                title: const Text('Good with children'),
                subtitle: const Text('Does this dog get along with children?'),
                value: _isGoodWithChildren,
                onChanged: (value) =>
                    setState(() => _isGoodWithChildren = value),
              ),
              SwitchListTile(
                title: const Text('Good with strangers'),
                subtitle: const Text('Does this dog get along with strangers?'),
                value: _isGoodWithStrangers,
                onChanged: (value) =>
                    setState(() => _isGoodWithStrangers = value),
              ),
              const SizedBox(height: 24),

              // Health & Training Section
              _buildSectionHeader('Health & Training'),
              TextFormField(
                controller: _medicalConditionsController,
                decoration: InputDecoration(
                  labelText: 'Medical Conditions (comma-separated)',
                  prefixIcon: const Icon(Icons.medical_services),
                  border: const OutlineInputBorder(),
                  helperText: 'e.g., diabetes, arthritis, allergies',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trainingCommandsController,
                decoration: InputDecoration(
                  labelText: 'Training Commands (comma-separated)',
                  prefixIcon: const Icon(Icons.school),
                  border: const OutlineInputBorder(),
                  helperText: 'e.g., sit, stay, come, down',
                ),
              ),
              const SizedBox(height: 24),

              // Contact Information Section
              _buildSectionHeader('Contact Information'),
              TextFormField(
                controller: _vetContactController,
                decoration: InputDecoration(
                  labelText: 'Veterinarian Contact (optional)',
                  prefixIcon: const Icon(Icons.local_hospital),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyContactController,
                decoration: InputDecoration(
                  labelText: 'Emergency Contact (optional)',
                  prefixIcon: const Icon(Icons.emergency),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _photoUrlController,
                decoration: InputDecoration(
                  labelText: t.t('photo_url_optional'),
                  prefixIcon: const Icon(Icons.image),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveDog,
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
                label: Text(isEdit ? t.t('save_changes') : t.t('add_dog')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
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
            ],
          ),
        ),
      ),
    );
  }
}
