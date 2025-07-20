import 'package:flutter/material.dart';
import '../models/walk_request_model.dart';
import '../services/walk_request_service.dart';

class WalkRequestDetailScreen extends StatefulWidget {
  final WalkRequestModel request;
  final bool isWalker;
  const WalkRequestDetailScreen({Key? key, required this.request, required this.isWalker}) : super(key: key);

  @override
  State<WalkRequestDetailScreen> createState() => _WalkRequestDetailScreenState();
}

class _WalkRequestDetailScreenState extends State<WalkRequestDetailScreen> {
  bool _processing = false;
  late WalkRequestModel _request;
  final WalkRequestService _service = WalkRequestService();

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  Future<void> _acceptRequest() async {
    setState(() => _processing = true);
    final updated = _request.copyWith(
      status: WalkRequestStatus.accepted,
      walkerId: 'walkerId', // TODO: Use real walkerId from Provider
    );
    await _service.updateWalkRequest(updated);
    setState(() {
      _request = updated;
      _processing = false;
    });
    Navigator.pop(context, true);
  }

  Future<void> _cancelRequest() async {
    setState(() => _processing = true);
    final updated = _request.copyWith(status: WalkRequestStatus.cancelled);
    await _service.updateWalkRequest(updated);
    setState(() {
      _request = updated;
      _processing = false;
    });
    Navigator.pop(context, true);
  }

  Future<void> _rescheduleRequest() async {
    // TODO: Implement rescheduling logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rescheduling not implemented yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk Request Details'),
        backgroundColor: Colors.green[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location: ${_request.location}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Time: ${_request.time}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Notes: ${_request.notes ?? "-"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Status: ${_request.status.toString().split(".").last}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            if (_processing) const Center(child: CircularProgressIndicator()),
            if (!_processing)
              Row(
                children: [
                  if (widget.isWalker && _request.status == WalkRequestStatus.pending)
                    ElevatedButton(
                      onPressed: _acceptRequest,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                      child: const Text('Accept'),
                    ),
                  if (!widget.isWalker && _request.status == WalkRequestStatus.pending)
                    ElevatedButton(
                      onPressed: _cancelRequest,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
                      child: const Text('Cancel'),
                    ),
                  if (!widget.isWalker && _request.status == WalkRequestStatus.accepted)
                    ElevatedButton(
                      onPressed: _rescheduleRequest,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]),
                      child: const Text('Reschedule'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
} 