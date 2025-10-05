const {Range} = require('semver');

class Consumer {
  constructor(keyPath, versionRange, callback) {
    this.keyPath = keyPath;
    this.callback = callback;
    this.versionRange = new Range(versionRange);
  }
}

module.exports = Consumer;
