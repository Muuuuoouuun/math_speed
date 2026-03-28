import 'package:flutter/material.dart';

import 'core/bootstrap/app_environment.dart';
import 'features/game/presentation/brain_training_page.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/domain/player_profile.dart';
import 'features/profile/presentation/profile_setup_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.environment,
    super.key,
  });

  final AppEnvironment environment;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ProfileRepository _profileRepository = ProfileRepository();
  PlayerProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!widget.environment.firebaseReady) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final profile = await _profileRepository.loadCurrentProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile(ProfileDraft draft) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final profile = await _profileRepository.upsertProfile(draft);
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.environment.firebaseReady && !(_profile?.isComplete ?? false)) {
      return ProfileSetupPage(
        initialProfile: _profile,
        onSubmit: _saveProfile,
        isBusy: _isSaving,
      );
    }

    return BrainTrainingPage(
      environment: widget.environment,
      profile: _profile,
      onProfileUpdated: _loadProfile,
    );
  }
}
