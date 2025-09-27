import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dog_model.dart';
import '../services/dog_service.dart';
import '../services/auth_provider.dart';
import 'edit_dog_screen.dart';
import '../l10n/app_localizations.dart';

/// Screen showing a user's dogs.
/// - Fetches, edits, and deletes dogs in Firestore scoped by owner.
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
      MaterialPageRoute(builder: (context) => EditDogScreen(ownerId: user.uid)),
    );
    if (result != null) _fetchDogs();
  }

  void _onEditDog(DogModel dog) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDogScreen(ownerId: dog.ownerId, dog: dog),
      ),
    );
    if (result != null) _fetchDogs();
  }

  void _onDeleteDog(DogModel dog) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('delete_dog')),
        content: Text(
          AppLocalizations.of(
            context,
          ).t('delete_dog_confirm').replaceFirst('%s', dog.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context).t('delete'),
              style: const TextStyle(color: Colors.red),
            ),
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
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('my_dogs')),
        backgroundColor: Colors.blue[600],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDogs),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddDog,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: t.t('add_dog'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dogs.isEmpty
          ? Center(
              child: Text(
                t.t('no_dogs_yet'),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      '${dog.breed} • ${dog.age} ${t.t('years_old')}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _onEditDog(dog),
                          tooltip: t.t('edit'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _onDeleteDog(dog),
                          tooltip: t.t('delete'),
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
