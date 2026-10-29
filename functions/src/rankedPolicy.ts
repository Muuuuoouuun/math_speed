import { HttpsError } from 'firebase-functions/v2/https';

/** Official ranked rounds have the same number of questions for every player. */
export function rankedLevelSettings(input: unknown): { level: number; problemCount: number } {
  const data = input && typeof input === 'object' ? input as Record<string, unknown> : {};
  const level = Number(data.level ?? 1);
  if (!Number.isInteger(level) || level < 1 || level > 10) {
    throw new HttpsError('invalid-argument', 'level must be an integer between 1 and 10.');
  }
  const problemCount = level <= 8 ? 10 + (Math.floor((level - 1) / 2) * 2) : level === 9 ? 18 : 20;
  if (data.problemCount !== undefined && Number(data.problemCount) !== problemCount) {
    throw new HttpsError('invalid-argument', 'problemCount is fixed by the selected level.');
  }
  return { level, problemCount };
}

/** Only Auth custom claims, written by the Admin SDK, can confer a privileged role. */
export function claimsForProfile(
  trustedClaims: Record<string, unknown> | undefined,
  profile: { schoolId: string; regionCode: string },
): Record<string, unknown> & { role: string } {
  const role = trustedClaims?.role === 'admin' || trustedClaims?.role === 'ops'
    ? trustedClaims.role
    : 'player';
  return { ...trustedClaims, schoolId: profile.schoolId, regionCode: profile.regionCode, role };
}
