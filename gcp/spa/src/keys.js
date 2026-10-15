// By convention everything a user touches lives under users/<sub>/ . Unlike the AWS demo, nothing in
// gcp/tf enforces this (the pool-wide bucket grant has no per-user condition), so it is organisation only.
export function userPrefix(subject) {
  if (!subject) throw new Error('Missing subject');
  return `users/${subject}/`;
}

export function objectKey(subject, filename) {
  const name = String(filename).split(/[\\/]/).pop().trim();
  if (!name) throw new Error('File name is empty');
  return userPrefix(subject) + name;
}
