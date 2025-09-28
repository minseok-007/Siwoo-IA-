import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/dog_traits.dart';
import '../services/auth_provider.dart';
import '../utils/validators.dart';
import 'login_screen.dart';
import 'auth_wrapper.dart';
import '../l10n/app_localizations.dart';

/// Email/password sign-up screen.
/// - Collects the user type (owner/walker) along with basic personal details.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserType _selectedUserType = UserType.dogOwner;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Walker preference fields
  ExperienceLevel _experienceLevel = ExperienceLevel.beginner;
  double _hourlyRate = 25;
  double _maxDistance = 10;
  List<DogSize> _preferredDogSizes = [];
  List<int> _availableDays = [];
  List<String> _preferredTimeSlots = [];
  List<DogTemperament> _preferredTemperaments = [];
  List<EnergyLevel> _preferredEnergyLevels = [];
  List<SpecialNeeds> _supportedSpecialNeeds = [];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Validates the form and submits the sign-up request.
  /// - On success, navigates to `AuthWrapper` so routing follows auth state.
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUserType == UserType.dogWalker) {
      if (_preferredDogSizes.isEmpty) {
        _showWarning(AppLocalizations.of(context).t('select_dog_sizes'));
        return;
      }
      if (_preferredTemperaments.isEmpty) {
        _showWarning(AppLocalizations.of(context).t('select_temperaments'));
        return;
      }
      if (_preferredEnergyLevels.isEmpty) {
        _showWarning(AppLocalizations.of(context).t('select_energy_levels'));
        return;
      }
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      userType: _selectedUserType,
      experienceLevel: _experienceLevel,
      hourlyRate: _hourlyRate,
      maxDistance: _maxDistance,
      preferredDogSizes: _preferredDogSizes,
      availableDays: _availableDays,
      preferredTimeSlots: _preferredTimeSlots,
      preferredTemperaments: _preferredTemperaments,
      preferredEnergyLevels: _preferredEnergyLevels,
      supportedSpecialNeeds: _supportedSpecialNeeds,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    } else if (mounted) {
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? t.t('failed_to_create_account')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // App Logo/Title
                Icon(Icons.pets, size: 80, color: Colors.blue[600]),
                const SizedBox(height: 16),
                Text(
                  'PawPal',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  t.t('connect_with_dog_lovers'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // User Type Selection
                Text(
                  t.t('i_am_a'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildUserTypeCard(
                        UserType.dogOwner,
                        t.t('dog_owner'),
                        Icons.pets,
                        t.t('owner_desc'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUserTypeCard(
                        UserType.dogWalker,
                        t.t('dog_walker'),
                        Icons.directions_walk,
                        t.t('walker_desc'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Full Name Field
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: t.t('full_name'),
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (v) => Validators.validateFullName(v, context),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: t.t('email'),
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (v) => Validators.validateEmail(v, context),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: t.t('phone_number'),
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (v) => Validators.validatePhoneNumber(v, context),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: t.t('password'),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (v) => Validators.validatePassword(v, context),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: t.t('confirm_password'),
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (value) => Validators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                    context,
                  ),
                  obscureText: _obscureConfirmPassword,
                ),
                const SizedBox(height: 24),
                if (_selectedUserType == UserType.dogWalker)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildWalkerPreferences(t),
                  ),

                // Sign Up Button
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: authProvider.isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              t.t('create_account'),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t.t('already_have_account'),
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        t.t('sign_in'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeCard(
    UserType userType,
    String title,
    IconData icon,
    String description,
  ) {
    final isSelected = _selectedUserType == userType;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserType = userType;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Theme.of(context).cardColor,
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.blue[600] : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.blue[600] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkerPreferences(AppLocalizations t) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.t('walker_preferences'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExperienceLevel>(
              value: _experienceLevel,
              decoration: InputDecoration(
                labelText: t.t('experience_level'),
                border: const OutlineInputBorder(),
              ),
              items: ExperienceLevel.values
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text(_experienceToLabel(t, level)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(
                () => _experienceLevel = value ?? ExperienceLevel.beginner,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${t.t('hourly_rate')} (4${_hourlyRate.toStringAsFixed(0)}/hr)',
            ),
            Slider(
              value: _hourlyRate,
              min: 10,
              max: 80,
              divisions: 70,
              label: _hourlyRate.toStringAsFixed(0),
              onChanged: (value) => setState(() => _hourlyRate = value),
            ),
            const SizedBox(height: 12),
            Text(
              '${t.t('max_distance_km')}: ${_maxDistance.toStringAsFixed(0)}',
            ),
            Slider(
              value: _maxDistance,
              min: 1,
              max: 40,
              divisions: 39,
              label: _maxDistance.toStringAsFixed(0),
              onChanged: (value) => setState(() => _maxDistance = value),
            ),
            const SizedBox(height: 12),
            _buildSelectionChips<DogSize>(
              label: t.t('preferred_dog_sizes'),
              options: DogSize.values,
              selectedValues: _preferredDogSizes,
              display: (size) => _dogSizeToLabel(t, size),
              onToggle: (value, isSelected) => setState(() {
                if (isSelected) {
                  _preferredDogSizes.add(value);
                } else {
                  _preferredDogSizes.remove(value);
                }
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectionChips<DogTemperament>(
              label: t.t('preferred_temperaments'),
              options: DogTemperament.values,
              selectedValues: _preferredTemperaments,
              display: (temp) => _temperamentLabel(t, temp),
              onToggle: (value, isSelected) => setState(() {
                if (isSelected) {
                  _preferredTemperaments.add(value);
                } else {
                  _preferredTemperaments.remove(value);
                }
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectionChips<EnergyLevel>(
              label: t.t('accepted_energy_levels'),
              options: EnergyLevel.values,
              selectedValues: _preferredEnergyLevels,
              display: (level) => _energyLabel(t, level),
              onToggle: (value, isSelected) => setState(() {
                if (isSelected) {
                  _preferredEnergyLevels.add(value);
                } else {
                  _preferredEnergyLevels.remove(value);
                }
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectionChips<SpecialNeeds>(
              label: t.t('supported_special_needs'),
              options: SpecialNeeds.values,
              selectedValues: _supportedSpecialNeeds,
              display: (need) => _specialNeedLabel(t, need),
              onToggle: (value, isSelected) => setState(() {
                if (isSelected) {
                  _supportedSpecialNeeds.add(value);
                } else {
                  _supportedSpecialNeeds.remove(value);
                }
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectionChips<int>(
              label: t.t('available_days'),
              options: List.generate(7, (index) => index),
              selectedValues: _availableDays,
              display: (day) => _dayLabel(t, day),
              onToggle: (value, isSelected) => setState(() {
                if (isSelected) {
                  _availableDays.add(value);
                } else {
                  _availableDays.remove(value);
                }
              }),
            ),
            const SizedBox(height: 12),
            _buildSelectionChips<String>(
              label: t.t('preferred_time_slots'),
              options: const ['morning', 'afternoon', 'evening'],
              selectedValues: _preferredTimeSlots,
              display: (slot) => _slotLabel(t, slot),
              onToggle: (value, isSelected) => setState(() {
                if (isSelected) {
                  _preferredTimeSlots.add(value);
                } else {
                  _preferredTimeSlots.remove(value);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionChips<T>({
    required String label,
    required List<T> options,
    required List<T> selectedValues,
    required String Function(T) display,
    required void Function(T value, bool isSelected) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = selectedValues.contains(option);
            return FilterChip(
              label: Text(display(option)),
              selected: isSelected,
              onSelected: (value) => onToggle(option, value),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _experienceToLabel(AppLocalizations t, ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner:
        return t.t('beginner');
      case ExperienceLevel.intermediate:
        return t.t('intermediate');
      case ExperienceLevel.expert:
        return t.t('expert');
    }
  }

  String _dogSizeToLabel(AppLocalizations t, DogSize size) {
    switch (size) {
      case DogSize.small:
        return t.t('small');
      case DogSize.medium:
        return t.t('medium');
      case DogSize.large:
        return t.t('large');
    }
  }

  String _temperamentLabel(AppLocalizations t, DogTemperament temperament) {
    switch (temperament) {
      case DogTemperament.calm:
        return t.t('temperament_calm');
      case DogTemperament.friendly:
        return t.t('temperament_friendly');
      case DogTemperament.energetic:
        return t.t('temperament_energetic');
      case DogTemperament.shy:
        return t.t('temperament_shy');
      case DogTemperament.aggressive:
        return t.t('temperament_aggressive');
      case DogTemperament.reactive:
        return t.t('temperament_reactive');
    }
  }

  String _energyLabel(AppLocalizations t, EnergyLevel level) {
    switch (level) {
      case EnergyLevel.low:
        return t.t('energy_low');
      case EnergyLevel.medium:
        return t.t('energy_medium');
      case EnergyLevel.high:
        return t.t('energy_high');
      case EnergyLevel.veryHigh:
        return t.t('energy_very_high');
    }
  }

  String _specialNeedLabel(AppLocalizations t, SpecialNeeds need) {
    switch (need) {
      case SpecialNeeds.none:
        return t.t('special_need_none');
      case SpecialNeeds.medication:
        return t.t('special_need_medication');
      case SpecialNeeds.elderly:
        return t.t('special_need_elderly');
      case SpecialNeeds.puppy:
        return t.t('special_need_puppy');
      case SpecialNeeds.training:
        return t.t('special_need_training');
      case SpecialNeeds.socializing:
        return t.t('special_need_socializing');
    }
  }

  String _slotLabel(AppLocalizations t, String slot) {
    switch (slot) {
      case 'morning':
        return t.t('morning');
      case 'afternoon':
        return t.t('afternoon');
      case 'evening':
        return t.t('evening');
      default:
        return slot;
    }
  }

  String _dayLabel(AppLocalizations t, int day) {
    final labels = [
      t.t('sun'),
      t.t('mon'),
      t.t('tue'),
      t.t('wed'),
      t.t('thu'),
      t.t('fri'),
      t.t('sat'),
    ];
    return labels[day.clamp(0, 6)];
  }
}
