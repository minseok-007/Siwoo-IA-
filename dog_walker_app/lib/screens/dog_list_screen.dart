import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dog_model.dart';
import '../services/dog_service.dart';
import '../services/auth_provider.dart';
import 'edit_dog_screen.dart';

class DogListScreen extends StatefulWidget {
  const DogListScreen({Key? key}) : super(key: key);

  @override
  State<DogListScreen> createState() => _DogListScreenState();
}

class _DogListScreenState extends State<DogListScreen> {
  final DogService _dogService = DogService();
  List<DogModel> _dogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDogs();
  }

  Future<void> _fetchDogs() async {
    setState(() => _loading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      final dogs = await _dogService.getDogsByOwner(user.uid);
      setState(() {
        _dogs = dogs;
        _loading = false;
      });
    }
  }

  void _onAddDog() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDogScreen(ownerId: user.uid),
      ),
    );
    if (result == true) _fetchDogs();
  }

  void _onEditDog(DogModel dog) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDogScreen(ownerId: dog.ownerId, dog: dog),
      ),
    );
    if (result == true) _fetchDogs();
  }

  void _onDeleteDog(DogModel dog) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dog'),
        content: Text('Are you sure you want to delete ${dog.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _dogService.deleteDog(dog.id);
      _fetchDogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dogs'),
        backgroundColor: Colors.blue[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDogs,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddDog,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Dog',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dogs.isEmpty
              ? Center(
                  child: Text(
                    'No dogs added yet. Tap + to add your first dog!',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dogs.length,
                  itemBuilder: (context, index) {
                    final dog = _dogs[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: dog.profileImageUrl != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(dog.profileImageUrl!),
                                radius: 28,
                              )
                            : CircleAvatar(
                                child: Icon(Icons.pets, color: Colors.blue[600]),
                                backgroundColor: Colors.blue[50],
                                radius: 28,
                              ),
                        title: Text(
                          dog.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text('${dog.breed} • ${dog.age} years old'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _onEditDog(dog),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _onDeleteDog(dog),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 