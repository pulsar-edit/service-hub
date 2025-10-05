
function getValueAtKeyPath (object, keyPath) {
  const keys = splitKeyPath(keyPath);
  for (var key of keys) {
    object = object[key];
    if (object == null) { return; }
  }
  return object;
}

function setValueAtKeyPath (object, keyPath, value) {
  const keys = splitKeyPath(keyPath);
  while (keys.length > 1) {
    var key = keys.shift();
    object[key] ??= {};
    object = object[key];
  }
  object[keys.shift()] = value;
}

function splitKeyPath (keyPath) {
  if (keyPath == null) { return []; }
  let startIndex = 0;
  const keys = [];
  for (let i = 0; i < keyPath.length; i++) {
    var char = keyPath[i];
    if ((char === '.') && ((i === 0) || (keyPath[i-1] !== '\\'))) {
      keys.push(keyPath.substring(startIndex, i));
      startIndex = i + 1;
    }
  }
  keys.push(keyPath.substr(startIndex, keyPath.length));
  return keys;
}

module.exports = {
  getValueAtKeyPath,
  setValueAtKeyPath
};
