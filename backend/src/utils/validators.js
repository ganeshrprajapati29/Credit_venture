const { ApiError } = require('./http');

const RX = {
  mobile: /^[6-9]\d{9}$/,
  mpin: /^\d{4}$/,
  pan: /^[A-Z]{5}[0-9]{4}[A-Z]$/,
  aadhaar: /^[2-9]\d{11}$/,
  ifsc: /^[A-Z]{4}0[A-Z0-9]{6}$/,
  pincode: /^[1-9]\d{5}$/,
  email: /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/,
  accountNumber: /^\d{9,18}$/,
};

/** Verhoeff checksum used by Aadhaar numbers. */
const verhoeff = (() => {
  const d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];
  const p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];
  return (num) => {
    let c = 0;
    const digits = String(num).split('').reverse().map(Number);
    for (let i = 0; i < digits.length; i++) c = d[c][p[i % 8][digits[i]]];
    return c === 0;
  };
})();

const isValidAadhaar = (n) => RX.aadhaar.test(String(n)) && verhoeff(n);

/**
 * Tiny schema validator. rules: { field: { required, rx, min, max, oneOf, label, msg } }
 * Throws ApiError(400) with per-field details.
 */
function validate(body, rules) {
  const errors = {};
  for (const [key, r] of Object.entries(rules)) {
    const v = body[key];
    const label = r.label || key;
    const empty = v === undefined || v === null || String(v).trim() === '';
    if (empty) {
      if (r.required) errors[key] = `${label} is required`;
      continue;
    }
    if (r.rx && !r.rx.test(String(v).trim())) errors[key] = r.msg || `Invalid ${label}`;
    if (r.test && !r.test(v)) errors[key] = r.msg || `Invalid ${label}`;
    if (r.min !== undefined && Number(v) < r.min) errors[key] = `${label} must be at least ${r.min}`;
    if (r.max !== undefined && Number(v) > r.max) errors[key] = `${label} must be at most ${r.max}`;
    if (r.oneOf && !r.oneOf.includes(v)) errors[key] = `Please select a valid ${label}`;
  }
  const keys = Object.keys(errors);
  if (keys.length) throw ApiError.badRequest(errors[keys[0]], errors);
}

const maskAadhaar = (n) => (n ? `XXXX XXXX ${String(n).slice(-4)}` : n);
const maskAccount = (n) => (n ? `${'X'.repeat(Math.max(0, String(n).length - 4))}${String(n).slice(-4)}` : n);

const ageFrom = (dob) => {
  const d = new Date(dob);
  if (Number.isNaN(d.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age--;
  return age;
};

module.exports = { RX, validate, isValidAadhaar, maskAadhaar, maskAccount, ageFrom };
