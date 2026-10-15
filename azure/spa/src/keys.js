// By convention everything a user touches lives under users/<sub>/ . Unlike the AWS demo, nothing in
// azure/tf enforces this (the role assignment is the same for every federated user), so it is organisation only.
export function userPrefix(subject) {
  if (!subject) throw new Error('Missing subject');
  return `users/${subject}/`;
}

export function objectKey(subject, filename) {
  const name = String(filename).split(/[\\/]/).pop().trim();
  if (!name) throw new Error('File name is empty');
  return userPrefix(subject) + name;
}
