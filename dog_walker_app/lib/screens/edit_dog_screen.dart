import 'package:flutter/material.dart';
import '../models/dog_model.dart';
import '../services/dog_service.dart';

class EditDogScreen extends StatefulWidget {
  final String ownerId;
  final DogModel? dog;
  const EditDogScreen({Key? key, required this.ownerId, this.dog}) : super(key: key);

  @override
  State<EditDogScreen> createState() => _EditDogScreenState();
}

class _EditDogScreenState extends State<EditDogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _photoUrlController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.dog != null) {
      _nameController.text = widget.dog!.name;
      _breedController.text = widget.dog!.breed;
      _ageController.text = widget.dog!.age.toString();
      _photoUrlController.text = widget.dog!.profileImageUrl ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveDog() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final dog = DogModel(
      id: widget.dog?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      name: _nameController.text.trim(),
      breed: _breedController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      profileImageUrl: _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
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
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.dog != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Dog' : 'Add Dog'),
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Dog Name',
                  prefixIcon: Icon(Icons.pets),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: 'Breed',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Breed required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final age = int.tryParse(v ?? '');
                  if (age == null || age < 0) return 'Enter a valid age';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _photoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Photo URL (optional)',
                  prefixIcon: Icon(Icons.image),
                  border: OutlineInputBorder(),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(isEdit ? 'Save Changes' : 'Add Dog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
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