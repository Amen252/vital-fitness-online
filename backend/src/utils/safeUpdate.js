/**
 * Pick only defined (non-undefined) keys from `source` that appear in `fields`.
 */
function pickDefined(source, fields) {
  const out = {};
  if (!source || typeof source !== 'object') return out;

  for (const key of fields) {
    if (Object.prototype.hasOwnProperty.call(source, key) && source[key] !== undefined) {
      out[key] = source[key];
    }
  }
  return out;
}

const UPDATE_OPTIONS = {
  new: true,
  runValidators: true,
};

module.exports = {
  pickDefined,
  UPDATE_OPTIONS,
};
