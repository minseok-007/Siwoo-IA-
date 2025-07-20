import 'package:flutter/material.dart';

class VerificationScreen extends StatefulWidget {
  final bool isVerified;
  const VerificationScreen({Key? key, required this.isVerified}) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _uploading = false;
  String? _uploadedFile;

  Future<void> _uploadId() async {
    setState(() => _uploading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate upload
    setState(() {
      _uploadedFile = 'id_uploaded.png';
      _uploading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID uploaded! (stub logic)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        backgroundColor: Colors.teal[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isVerified ? 'You are verified!' : 'You are not verified.',
              style: TextStyle(
                fontSize: 20,
                color: widget.isVerified ? Colors.teal[800] : Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (!widget.isVerified)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload a photo of your ID to verify your identity.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _uploading ? null : _uploadId,
                    icon: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Upload ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_uploadedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text('Uploaded: $_uploadedFile'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
} 