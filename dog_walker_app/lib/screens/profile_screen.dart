import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../services/auth_provider.dart';
import 'dog_list_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/dog_traits.dart';
import '../widgets/reviews_list_widget.dart';
import '../services/review_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _fullName;
  late String _phoneNumber;

  // Walker-specific
  ExperienceLevel _experienceLevel = ExperienceLevel.beginner;
  List<DogSize> _preferredDogSizes = [];
  double _maxDistance = 10.0;
  List<int> _availableDays = [];
  List<String> _preferredTimeSlots = [];
  List<DogTemperament> _preferredTemperaments = [];
  List<EnergyLevel> _preferredEnergyLevels = [];
  List<SpecialNeeds> _supportedSpecialNeeds = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    _fullName = user?.fullName ?? '';
    _phoneNumber = user?.phoneNumber ?? '';
    if (user != null) {
      _experienceLevel = user.experienceLevel;
      _preferredDogSizes = List<DogSize>.from(user.preferredDogSizes);
      _maxDistance = user.maxDistance;
      _availableDays = List<int>.from(user.availableDays);
      _preferredTimeSlots = List<String>.from(user.preferredTimeSlots);
      _preferredTemperaments = List<DogTemperament>.from(
        user.preferredTemperaments,
      );
      _preferredEnergyLevels = List<EnergyLevel>.from(
        user.preferredEnergyLevels,
      );
      _supportedSpecialNeeds = List<SpecialNeeds>.from(
        user.supportedSpecialNeeds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('profile')),
        backgroundColor: Colors.teal[600],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(user),
                    const SizedBox(height: 16),
                    _buildBasicInfo(user),
                    const SizedBox(height: 16),
                    if (user.userType == UserType.dogWalker)
                      _buildWalkerSection(),
                    if (user.userType == UserType.dogOwner)
                      _buildOwnerSection(context, user),
                    const SizedBox(height: 16),
                    _buildReviewsSection(user),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : () => _save(user),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          AppLocalizations.of(context).t('save_changes'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReviewsSection(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).t('leave_a_review'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<double>(
              future: ReviewService().getAverageRating(user.id),
              builder: (context, snapshot) {
                final avg = (snapshot.data ?? 0.0);
                return Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber[700]),
                    const SizedBox(width: 6),
                    Text('${avg.toStringAsFixed(1)}/5'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ReviewsListWidget(userId: user.id),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.teal[100],
          child: Icon(
            user.userType == UserType.dogOwner
                ? Icons.pets
                : Icons.directions_walk,
            color: Colors.teal[700],
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                user.userType == UserType.dogOwner
                    ? AppLocalizations.of(context).t('dog_owner')
                    : AppLocalizations.of(context).t('dog_walker'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfo(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).t('basic_info'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _fullName,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).t('full_name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppLocalizations.of(context).t('enter_name')
                  : null,
              onSaved: (v) => _fullName = v!.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: user.email,
              readOnly: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).t('email'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _phoneNumber,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).t('phone_number'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppLocalizations.of(context).t('enter_phone')
                  : null,
              onSaved: (v) => _phoneNumber = v!.trim(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).t('walker_details'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExperienceLevel>(
              value: _experienceLevel,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).t('experience_level'),
                border: const OutlineInputBorder(),
              ),
              items: ExperienceLevel.values
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(_experienceToLabel(e)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(
                () => _experienceLevel = v ?? ExperienceLevel.beginner,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).t('preferred_dog_sizes'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: DogSize.values.map((size) {
                final selected = _preferredDogSizes.contains(size);
                return FilterChip(
                  label: Text(_dogSizeToLabel(size)),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _preferredDogSizes.add(size);
                      } else {
                        _preferredDogSizes.remove(size);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              '${AppLocalizations.of(context).t('max_distance_km')}: ${_maxDistance.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            Slider(
              value: _maxDistance,
              min: 1,
              max: 100,
              divisions: 99,
              label: _maxDistance.toStringAsFixed(0),
              onChanged: (v) => setState(() => _maxDistance = v),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).t('available_days'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) => i).map((day) {
                final selected = _availableDays.contains(day);
                return FilterChip(
                  label: Text(_dayLabel(day)),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _availableDays.add(day);
                      } else {
                        _availableDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).t('preferred_time_slots'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['morning', 'afternoon', 'evening'].map((slot) {
                final selected = _preferredTimeSlots.contains(slot);
                return FilterChip(
                  label: Text(_slotLabel(slot)),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _preferredTimeSlots.add(slot);
                      } else {
                        _preferredTimeSlots.remove(slot);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).t('preferred_temperaments'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: DogTemperament.values.map((temp) {
                final selected = _preferredTemperaments.contains(temp);
                return FilterChip(
                  label: Text(_temperamentLabel(temp)),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _preferredTemperaments.add(temp);
                      } else {
                        _preferredTemperaments.remove(temp);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).t('accepted_energy_levels'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: EnergyLevel.values.map((level) {
                final selected = _preferredEnergyLevels.contains(level);
                return FilterChip(
                  label: Text(_energyLabel(level)),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _preferredEnergyLevels.add(level);
                      } else {
                        _preferredEnergyLevels.remove(level);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).t('supported_special_needs'),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SpecialNeeds.values.map((need) {
                final selected = _supportedSpecialNeeds.contains(need);
                return FilterChip(
                  label: Text(_specialNeedLabel(need)),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _supportedSpecialNeeds.add(need);
                      } else {
                        _supportedSpecialNeeds.remove(need);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerSection(BuildContext context, UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).t('dog_owner'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).t('owner_manage_dogs_desc')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DogListScreen()),
                );
              },
              icon: const Icon(Icons.pets),
              label: Text(AppLocalizations.of(context).t('manage_dogs')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _saving = true);
    try {
      final updated = user.copyWith(
        fullName: _fullName,
        phoneNumber: _phoneNumber,
        experienceLevel: _experienceLevel,
        preferredDogSizes: _preferredDogSizes,
        maxDistance: _maxDistance,
        availableDays: _availableDays,
        preferredTimeSlots: _preferredTimeSlots,
        preferredTemperaments: _preferredTemperaments,
        preferredEnergyLevels: _preferredEnergyLevels,
        supportedSpecialNeeds: _supportedSpecialNeeds,
        // leave other fields as-is
      );

      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).updateUserProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('profile_updated')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).t('failed_to_save')}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _experienceToLabel(ExperienceLevel e) {
    switch (e) {
      case ExperienceLevel.beginner:
        return AppLocalizations.of(context).t('beginner');
      case ExperienceLevel.intermediate:
        return AppLocalizations.of(context).t('intermediate');
      case ExperienceLevel.expert:
        return AppLocalizations.of(context).t('expert');
    }
  }

  String _dogSizeToLabel(DogSize s) {
    switch (s) {
      case DogSize.small:
        return AppLocalizations.of(context).t('small');
      case DogSize.medium:
        return AppLocalizations.of(context).t('medium');
      case DogSize.large:
        return AppLocalizations.of(context).t('large');
    }
  }

  String _dayLabel(int day) {
    final names = [
      AppLocalizations.of(context).t('sun'),
      AppLocalizations.of(context).t('mon'),
      AppLocalizations.of(context).t('tue'),
      AppLocalizations.of(context).t('wed'),
      AppLocalizations.of(context).t('thu'),
      AppLocalizations.of(context).t('fri'),
      AppLocalizations.of(context).t('sat'),
    ];
    return names[day.clamp(0, 6)];
  }

  String _slotLabel(String slot) {
    switch (slot) {
      case 'morning':
        return AppLocalizations.of(context).t('morning');
      case 'afternoon':
        return AppLocalizations.of(context).t('afternoon');
      case 'evening':
        return AppLocalizations.of(context).t('evening');
      default:
        return slot;
    }
  }

  String _temperamentLabel(DogTemperament temperament) {
    switch (temperament) {
      case DogTemperament.calm:
        return AppLocalizations.of(context).t('temperament_calm');
      case DogTemperament.friendly:
        return AppLocalizations.of(context).t('temperament_friendly');
      case DogTemperament.energetic:
        return AppLocalizations.of(context).t('temperament_energetic');
      case DogTemperament.shy:
        return AppLocalizations.of(context).t('temperament_shy');
      case DogTemperament.aggressive:
        return AppLocalizations.of(context).t('temperament_aggressive');
      case DogTemperament.reactive:
        return AppLocalizations.of(context).t('temperament_reactive');
    }
  }

  String _energyLabel(EnergyLevel level) {
    switch (level) {
      case EnergyLevel.low:
        return AppLocalizations.of(context).t('energy_low');
      case EnergyLevel.medium:
        return AppLocalizations.of(context).t('energy_medium');
      case EnergyLevel.high:
        return AppLocalizations.of(context).t('energy_high');
      case EnergyLevel.veryHigh:
        return AppLocalizations.of(context).t('energy_very_high');
    }
  }

  String _specialNeedLabel(SpecialNeeds need) {
    switch (need) {
      case SpecialNeeds.none:
        return AppLocalizations.of(context).t('special_need_none');
      case SpecialNeeds.medication:
        return AppLocalizations.of(context).t('special_need_medication');
      case SpecialNeeds.elderly:
        return AppLocalizations.of(context).t('special_need_elderly');
      case SpecialNeeds.puppy:
        return AppLocalizations.of(context).t('special_need_puppy');
      case SpecialNeeds.training:
        return AppLocalizations.of(context).t('special_need_training');
      case SpecialNeeds.socializing:
        return AppLocalizations.of(context).t('special_need_socializing');
    }
  }
}
