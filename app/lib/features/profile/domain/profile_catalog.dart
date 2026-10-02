class RegionOption {
  const RegionOption({
    required this.code,
    required this.name,
    required this.schools,
  });

  final String code;
  final String name;
  final List<SchoolOption> schools;
}

class SchoolOption {
  const SchoolOption({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

const List<RegionOption> kRegionOptions = <RegionOption>[
  RegionOption(
    code: 'KR-11',
    name: '서울',
    schools: <SchoolOption>[
      SchoolOption(id: 'seoul-junior', name: '서울 두뇌 초등학교'),
      SchoolOption(id: 'han-river', name: '한강 계산 학교'),
      SchoolOption(id: 'namsan-academy', name: '남산 연산 아카데미'),
    ],
  ),
  RegionOption(
    code: 'KR-26',
    name: '부산',
    schools: <SchoolOption>[
      SchoolOption(id: 'busan-ocean', name: '부산 바다 초등학교'),
      SchoolOption(id: 'gwangalli-math', name: '광안리 수학 학교'),
      SchoolOption(id: 'haeundae-brain', name: '해운대 두뇌 학교'),
    ],
  ),
  RegionOption(
    code: 'KR-27',
    name: '대구',
    schools: <SchoolOption>[
      SchoolOption(id: 'daegu-alpha', name: '대구 알파 학교'),
      SchoolOption(id: 'suseong-math', name: '수성 계산 학교'),
      SchoolOption(id: 'brain-valley', name: '브레인 밸리 초등학교'),
    ],
  ),
];

String schoolNameFor(String schoolId) {
  for (final region in kRegionOptions) {
    for (final school in region.schools) {
      if (school.id == schoolId) {
        return school.name;
      }
    }
  }
  return schoolId;
}

String regionNameFor(String regionCode) {
  for (final region in kRegionOptions) {
    if (region.code == regionCode) {
      return region.name;
    }
  }
  return regionCode;
}
