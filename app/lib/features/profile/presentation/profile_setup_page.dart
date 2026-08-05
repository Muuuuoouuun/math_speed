import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/paper_backdrop.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/pencil_doodles.dart';
import '../domain/player_profile.dart';
import '../domain/profile_catalog.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    required this.initialProfile,
    required this.onSubmit,
    required this.isBusy,
    super.key,
  });

  final PlayerProfile? initialProfile;
  final Future<void> Function(ProfileDraft draft) onSubmit;
  final bool isBusy;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final TextEditingController _nameController;
  String? _regionCode;
  String? _schoolId;
  int _grade = 4;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile?.displayName ?? '');
    _regionCode = widget.initialProfile?.regionCode.isNotEmpty == true
        ? widget.initialProfile?.regionCode
        : kRegionOptions.first.code;
    _schoolId = widget.initialProfile?.schoolId.isNotEmpty == true
        ? widget.initialProfile?.schoolId
        : kRegionOptions.first.schools.first.id;
    _grade = widget.initialProfile?.grade == 0 ? 4 : (widget.initialProfile?.grade ?? 4);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  RegionOption get _selectedRegion => kRegionOptions.firstWhere(
        (region) => region.code == _regionCode,
        orElse: () => kRegionOptions.first,
      );

  Future<void> _submit() async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름이나 닉네임을 입력해 주세요.')),
      );
      return;
    }

    final draft = ProfileDraft(
      displayName: trimmedName,
      schoolId: _schoolId ?? '',
      regionCode: _regionCode ?? '',
      grade: _grade,
    );
    await widget.onSubmit(draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: PaperBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xl,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  // 표지. 첫 화면이라 여백을 넉넉히 두고 마스코트로 인사합니다.
                  PaperCard(
                    accent: AppPalette.sky,
                    tapeLabel: '처음 오셨네요',
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      children: <Widget>[
                        const PencilMascot(size: 78),
                        const SizedBox(height: AppSpacing.md),
                        Text('학습 프로필', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        const SizedBox(
                          width: 120,
                          child: PencilRule(color: Color(0x8C7CA3CC)),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '학교 대항전과 지역 기록전에 참여하려면\n기본 정보를 먼저 적어 주세요.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: AppPalette.graphite),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          alignment: WrapAlignment.center,
                          children: <Widget>[
                            _IntroChip(label: '학교 랭킹 참여'),
                            _IntroChip(label: '지역 기록 비교'),
                            _IntroChip(label: '개인 최고 기록 저장'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  const SectionLabel(text: '기본 정보'),
                  const SizedBox(height: AppSpacing.sm),
                  PaperCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppPalette.cardSunk,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppPalette.lineSoft),
                          ),
                          child: Text(
                            '닉네임은 리더보드와 결과 화면에 표시돼요. 실명 대신 별명을 써도 괜찮아요.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: '이름 또는 닉네임'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          value: _regionCode,
                          decoration: const InputDecoration(labelText: '지역'),
                          items: kRegionOptions
                              .map(
                                (region) => DropdownMenuItem<String>(
                                  value: region.code,
                                  child: Text(region.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: widget.isBusy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  final region =
                                      kRegionOptions.firstWhere((item) => item.code == value);
                                  setState(() {
                                    _regionCode = value;
                                    _schoolId = region.schools.first.id;
                                  });
                                },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          value: _schoolId,
                          decoration: const InputDecoration(labelText: '학교'),
                          items: _selectedRegion.schools
                              .map(
                                (school) => DropdownMenuItem<String>(
                                  value: school.id,
                                  child: Text(school.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: widget.isBusy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _schoolId = value);
                                },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<int>(
                          value: _grade,
                          decoration: const InputDecoration(labelText: '학년'),
                          items: List<DropdownMenuItem<int>>.generate(
                            6,
                            (index) => DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text('${index + 1}학년'),
                            ),
                          ),
                          onChanged: widget.isBusy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _grade = value);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  FilledButton(
                    onPressed: widget.isBusy ? null : _submit,
                    child: widget.isBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('연필 잡고 시작하기'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroChip extends StatelessWidget {
  const _IntroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppPalette.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppPalette.graphite,
        ),
      ),
    );
  }
}
