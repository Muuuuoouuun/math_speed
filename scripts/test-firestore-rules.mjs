import assert from 'node:assert/strict';

// Run with a local Firestore emulator loaded with this repository's rules.
const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8181';
assert.match(host, /^(?:localhost|127\.0\.0\.1):\d+$/, 'Use a local emulator only.');
const project = 'demo-brain-math-rules';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const uid = `rules-test-${Date.now()}`;

function token(subject) {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    sub: subject, user_id: subject, aud: project,
    iss: `https://securetoken.google.com/${project}`,
    iat: now, exp: now + 3600,
    firebase: { sign_in_provider: 'anonymous' },
  })}.`;
}

async function request(method, path, fields, identity = token(uid)) {
  const response = await fetch(`${base}/${path}`, {
    method,
    headers: { Authorization: `Bearer ${identity}`, 'Content-Type': 'application/json' },
    body: fields === undefined ? undefined : JSON.stringify({ fields }),
  });
  const body = await response.json();
  return { status: response.status, body };
}

const field = (stringValue) => ({ stringValue });
let result = await request('PATCH', `users/${uid}`, {
  role: field('admin'), schoolId: field('school'), regionCode: field('region'),
});
assert.equal(result.status, 403, 'A client must not create a trusted profile.');

result = await request('PATCH', `users/${uid}`, {
  displayName: field('Player'), role: field('player'),
  schoolId: field('school'), regionCode: field('region'),
}, 'owner');
assert.equal(result.status, 200, JSON.stringify(result.body));

result = await request('PATCH', `users/${uid}?updateMask.fieldPaths=displayName`, {
  displayName: field('New name'),
});
assert.equal(result.status, 200, 'An owner can still edit their display name.');

result = await request('PATCH', `users/${uid}?updateMask.fieldPaths=role`, {
  role: field('admin'),
});
assert.equal(result.status, 403, 'An owner cannot change role.');

result = await request('PATCH', `users/${uid}?updateMask.fieldPaths=role`, {});
assert.equal(result.status, 403, 'An owner cannot delete role to re-add an administrator role.');

result = await request('PATCH', `users/${uid}?updateMask.fieldPaths=personalBestOverall`, {
  personalBestOverall: { integerValue: '999999' },
});
assert.equal(result.status, 403, 'An owner cannot add a server-controlled score field.');

result = await request('GET', `users/${uid}`, undefined, token(`${uid}-other`));
assert.equal(result.status, 403, 'Another player cannot read the private profile.');

result = await request('DELETE', `users/${uid}`, undefined, 'owner');
assert.equal(result.status, 200);
console.log('Firestore rules: 7 permission checks passed.');
