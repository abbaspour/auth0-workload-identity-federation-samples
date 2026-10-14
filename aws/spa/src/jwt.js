// Decode (not verify) a JWT payload, to show the claims AWS evaluates.
export function decodeJwt(token) {
  const parts = String(token).split('.');
  if (parts.length !== 3) {
    throw new Error('Not a JWT. Is the access token opaque? Check that an API audience was requested.');
  }
  const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
  const bytes = Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
}
