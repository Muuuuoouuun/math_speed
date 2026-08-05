import 'package:flutter/material.dart';

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

  RegionOption get _selectedRegion =>
      kRegionOptions.firstWhere((region) => region.code == _regionCode, orElse: () => kRegionOptions.first);

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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('학습 프로필', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    '학교 대항전과 지역 기록전에 참여하려면 기본 정보를 먼저 적어 주세요.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _IntroChip(label: '학교 랭킹 참여'),
                      _IntroChip(label: '지역 기록 비교'),
                      _IntroChip(label: '개인 최고 기록 저장'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFD9D0C0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCF6),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE4DED1)),
                            ),
                            child: Text(
                              '닉네임은 리더보드와 결과 화면에 표시됩니다. 실명 대신 별명을 사용해도 괜찮아요.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: '이름 또는 닉네임'),
                          ),
                          const SizedBox(height: 14),
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
                                    final region = kRegionOptions.firstWhere((item) => item.code == value);
                                    setState(() {
                                      _regionCode = value;
                                      _schoolId = region.schools.first.id;
                                    });
                                  },
                          ),
                          const SizedBox(height: 14),
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
                                    setState(() {
                                      _schoolId = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 14),
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
                                    setState(() {
                                      _grade = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: widget.isBusy ? null : _submit,
                            child: Text(widget.isBusy ? '저장 중...' : '게임 시작하기'),
                          ),
                        ],
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9D0C0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF474440),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
