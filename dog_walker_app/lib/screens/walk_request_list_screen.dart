import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import 'walk_request_form_screen.dart';
import 'walk_request_detail_screen.dart';

class WalkRequestListScreen extends StatefulWidget {
  final bool isWalker;
  const WalkRequestListScreen({Key? key, required this.isWalker}) : super(key: key);

  @override
  State<WalkRequestListScreen> createState() => _WalkRequestListScreenState();
}

class _WalkRequestListScreenState extends State<WalkRequestListScreen> {
  final WalkRequestService _service = WalkRequestService();
  List<WalkRequestModel> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    List<WalkRequestModel> reqs;
    if (widget.isWalker) {
      reqs = await _service.getAvailableRequests();
      // TODO: Add distance/time filter for matching system
    } else {
      reqs = await _service.getRequestsByOwner(user.uid);
    }
    setState(() {
      _requests = reqs;
      _loading = false;
    });
  }

  void _onAddRequest() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkRequestFormScreen(ownerId: user.uid),
      ),
    );
    if (result == true) _fetchRequests();
  }

  void _onTapRequest(WalkRequestModel req) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkRequestDetailScreen(request: req, isWalker: widget.isWalker),
      ),
    );
    if (result == true) _fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isWalker ? 'Available Walks' : 'My Walk Requests'),
        backgroundColor: Colors.green[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      floatingActionButton: widget.isWalker
          ? null
          : FloatingActionButton(
              onPressed: _onAddRequest,
              backgroundColor: Colors.green[600],
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Post Walk Request',
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Text(
                    widget.isWalker
                        ? 'No available walk requests nearby.'
                        : 'No walk requests posted yet. Tap + to post your first request!',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.directions_walk, color: Colors.green[600], size: 32),
                        title: Text(
                          req.location,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text('${req.time}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                        onTap: () => _onTapRequest(req),
                      ),
                    );
                  },
                ),
    );
  }
} 