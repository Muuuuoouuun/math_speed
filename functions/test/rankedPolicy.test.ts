import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { claimsForProfile, rankedLevelSettings } from '../src/rankedPolicy';

describe('ranked fairness and profile authorization policy', () => {
  it('fixes the official number of questions for every level', () => {
    const counts = [10, 10, 12, 12, 14, 14, 16, 16, 18, 20];
    for (let index = 0; index < counts.length; index++) {
      const level = index + 1;
      assert.deepEqual(rankedLevelSettings({ level }), { level, problemCount: counts[index] });
      assert.deepEqual(rankedLevelSettings({ level, problemCount: counts[index] }),
        { level, problemCount: counts[index] });
    }
  });

  it('rejects extra questions and invalid levels instead of changing the score opportunity', () => {
    for (const input of [{ level: 1, problemCount: 30 }, { level: 10, problemCount: 5 },
      { level: 0 }, { level: 11 }, { level: 2.5 }, { level: 'invalid' }]) {
      assert.throws(() => rankedLevelSettings(input), { code: 'invalid-argument' });
    }
  });

  it('ignores a privileged role embedded in profile data', () => {
    const forgedProfile = { schoolId: 'school-a', regionCode: 'region-a', role: 'admin' };
    assert.equal(claimsForProfile(undefined, forgedProfile).role, 'player');
    assert.equal(claimsForProfile({ role: 'unexpected' }, forgedProfile).role, 'player');
  });

  it('preserves server-managed roles and unrelated claims while refreshing affiliation', () => {
    for (const role of ['admin', 'ops']) {
      assert.deepEqual(claimsForProfile({ role, support: true, schoolId: 'old-school' },
        { schoolId: 'new-school', regionCode: 'new-region' }), {
        role, support: true, schoolId: 'new-school', regionCode: 'new-region',
      });
    }
  });
});
