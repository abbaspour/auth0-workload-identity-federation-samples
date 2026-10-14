// Everything a user may touch lives under users/<sub>/ . This must match the role's permissions
// policy in aws/tf/aws.tf, which uses the same <sub> from the token.
export function userPrefix(subject) {
  if (!subject) throw new Error('Missing subject');
  return `users/${subject}/`;
}

// RoleSessionName allows [\w+=,.@-], 2-64 chars. Auth0 subjects look like "auth0|abc123".
export function sessionNameFor(subject) {
  return `wif-${subject}`.replace(/[^\w+=,.@-]/g, '-').slice(0, 64);
}

export function objectKey(subject, filename) {
  const name = String(filename).split(/[\\/]/).pop().trim();
  if (!name) throw new Error('File name is empty');
  return userPrefix(subject) + name;
}
