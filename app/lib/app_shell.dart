import 'package:flutter/material.dart';

import 'core/bootstrap/app_environment.dart';
import 'core/theme/app_tokens.dart';
import 'core/widgets/paper_backdrop.dart';
import 'core/widgets/pencil_doodles.dart';
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
      return const _LoadingScreen();
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

/// 프로필을 읽어 오는 동안 보여 주는 화면.
///
/// 빈 회색 스피너 대신 마스코트를 세워 두어 첫인상을 앱 톤과 맞춥니다.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: PaperBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PencilMascot(size: 88, mood: MascotMood.sleepy),
              const SizedBox(height: AppSpacing.lg),
              Text('연필 깎는 중...', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text('기록을 불러오고 있어요', style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              const SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: AppPalette.paperDeep,
                  valueColor: AlwaysStoppedAnimation<Color>(AppPalette.mint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
