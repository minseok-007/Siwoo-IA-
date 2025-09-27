import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import 'walk_request_form_screen.dart';
import 'walk_request_detail_screen.dart';
import '../l10n/app_localizations.dart';

/// Walk-request list screen.
/// - Adapts tabs/lists to optimize UX for walkers versus owners.
class WalkRequestListScreen extends StatefulWidget {
  final bool isWalker;
  const WalkRequestListScreen({Key? key, required this.isWalker}) : super(key: key);

  @override
  State<WalkRequestListScreen> createState() => _WalkRequestListScreenState();
}

class _WalkRequestListScreenState extends State<WalkRequestListScreen> with SingleTickerProviderStateMixin {
  final WalkRequestService _service = WalkRequestService();
  List<WalkRequestModel> _availableRequests = [];
  List<WalkRequestModel> _acceptedRequests = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    if (widget.isWalker) {
      _tabController = TabController(length: 2, vsync: this);
    }
    _fetchRequests();
  }

  @override
  void dispose() {
    if (widget.isWalker) {
      _tabController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      if (widget.isWalker) {
        // For walkers, fetch both available and accepted requests
        final available = await _service.getAvailableRequests();
        final accepted = await _service.getRequestsByWalker(user.uid);
        
        setState(() {
          _availableRequests = available;
          _acceptedRequests = accepted.where((req) => 
            req.status == WalkRequestStatus.accepted || 
            req.status == WalkRequestStatus.completed
          ).toList();
          _loading = false;
        });
      } else {
        // For owners, fetch their own requests
        final reqs = await _service.getRequestsByOwner(user.uid);
        setState(() {
          _availableRequests = reqs;
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

  Widget _buildRequestCard(WalkRequestModel req) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          Icons.directions_walk, 
          color: _getStatusColor(req.status!), 
          size: 32
        ),
        title: Text(
          req.location,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${req.time.day}/${req.time.month}/${req.time.year} ${AppLocalizations.of(context).t('at')} ${req.time.hour}:${req.time.minute.toString().padLeft(2, '0')}'),
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
                : _availableRequests.isEmpty
                    ? Center(
                        child: Text(
                          t.t('no_available_walks'),
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _availableRequests.length,
                        itemBuilder: (context, index) => _buildRequestCard(_availableRequests[index]),
                      ),
            
            // Accepted Walks Tab
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
                        itemBuilder: (context, index) => _buildRequestCard(_acceptedRequests[index]),
                      ),
          ],
        ),
      );
    } else {
      // Owner view (unchanged)
      return Scaffold(
        appBar: AppBar(
          title: Text(t.t('my_walk_requests')),
          backgroundColor: Colors.green[600],
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
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _availableRequests.isEmpty
                ? Center(
                    child: Text(
                      t.t('no_walk_requests_yet'),
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableRequests.length,
                    itemBuilder: (context, index) => _buildRequestCard(_availableRequests[index]),
                  ),
      );
    }
  }
}
