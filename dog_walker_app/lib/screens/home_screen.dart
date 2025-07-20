import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_provider.dart';
import '../models/user_model.dart';
import 'walk_request_form_screen.dart';
import 'dog_list_screen.dart';
import 'walk_request_list_screen.dart';
import 'chat_list_screen.dart';
import 'verification_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'PawPal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.userModel == null) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          final user = authProvider.userModel!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(
                              user.userType == UserType.dogOwner 
                                  ? Icons.pets 
                                  : Icons.directions_walk,
                              size: 30,
                              color: Colors.blue[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  user.fullName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  user.userType == UserType.dogOwner 
                                      ? 'Dog Owner' 
                                      : 'Dog Walker',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                if (user.userType == UserType.dogOwner) ...[
                  // Dog Owner Actions
                  _buildActionCard(
                    context,
                    'Post Walk Request',
                    'Find a walker for your dog',
                    Icons.add_circle_outline,
                    Colors.green,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WalkRequestFormScreen(ownerId: user.id),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'My Dogs',
                    'Manage your dog profiles',
                    Icons.pets,
                    Colors.orange,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DogListScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'My Walk Requests',
                    'View and manage your walk requests',
                    Icons.history,
                    Colors.purple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalkRequestListScreen(isWalker: false),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // Dog Walker Actions
                  _buildActionCard(
                    context,
                    'Available Walks',
                    'Browse walk requests',
                    Icons.search,
                    Colors.green,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalkRequestListScreen(isWalker: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'My Schedule',
                    'Manage your availability',
                    Icons.calendar_today,
                    Colors.blue,
                    () {
                      // Placeholder for schedule screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Schedule - Coming Soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'Earnings',
                    'View your earnings',
                    Icons.attach_money,
                    Colors.amber,
                    () {
                      // Placeholder for earnings screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Earnings - Coming Soon!')),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // Common Actions
                Text(
                  'More',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                _buildActionCard(
                  context,
                  'Messages',
                  'Chat with other users',
                  Icons.chat_bubble_outline,
                  Colors.indigo,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatListScreen(userId: user.id),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  'Verification',
                  'Verify your identity',
                  Icons.verified_user,
                  Colors.teal,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VerificationScreen(isVerified: user.isVerified ?? false),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  'Profile',
                  'Edit your profile',
                  Icons.person_outline,
                  Colors.teal,
                  () {
                    // TODO: Navigate to profile screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Profile - Coming Soon!')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  'Settings',
                  'App preferences',
                  Icons.settings,
                  Colors.grey,
                  () {
                    // TODO: Navigate to settings screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Settings - Coming Soon!')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 