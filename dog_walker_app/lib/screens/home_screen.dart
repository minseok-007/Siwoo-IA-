import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../models/user_model.dart';
import 'walk_request_form_screen.dart';
import 'dog_list_screen.dart';
import 'walk_request_list_screen.dart';
import 'chat_list_screen.dart';
import 'scheduled_walks_screen.dart';
import 'optimal_schedule_screen.dart';
import 'recommendations_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import '../l10n/app_localizations.dart';

/// Home dashboard shown after login.
/// - Presents tailored quick actions based on the user's role.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'PawPal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
            return const Center(
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
                                  t.t('welcome_back_comma'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  user.userType == UserType.dogOwner 
                                      ? t.t('dog_owner') 
                                      : t.t('dog_walker'),
                                  style: const TextStyle(
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
                  t.t('quick_actions'),
                  style: TextStyle(
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
                    t.t('post_walk_request'),
                    t.t('post_walk_request_desc'),
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
                    t.t('my_dogs'),
                    t.t('my_dogs_desc'),
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
                    t.t('my_walk_requests'),
                    t.t('my_walk_requests_desc'),
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
                    t.t('available_walks'),
                    t.t('available_walks_desc'),
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
                    t.t('my_schedule'),
                    t.t('my_schedule_desc'),
                    Icons.calendar_today,
                    Colors.blue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScheduledWalksScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'Optimal Schedule',
                    'AI-powered schedule optimization',
                    Icons.auto_awesome,
                    Colors.purple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OptimalScheduleScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'AI Recommendations',
                    'Personalized recommendations using ML',
                    Icons.recommend,
                    Colors.pink,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecommendationsScreen(),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // Common Actions
                Text(
                  t.t('more'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                _buildActionCard(
                  context,
                  t.t('messages'),
                  t.t('messages_desc'),
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
                  t.t('profile'),
                  t.t('profile_desc'),
                  Icons.person_outline,
                  Colors.teal,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  t.t('settings'),
                  t.t('app_preferences'),
                  Icons.settings,
                  Colors.grey,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
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
