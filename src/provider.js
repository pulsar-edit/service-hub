const {gt, SemVer} = require('semver');
const {CompositeDisposable} = require('event-kit');

const {getValueAtKeyPath, setValueAtKeyPath} = require('./helpers');

class Provider {
  constructor(keyPath, servicesByVersion) {
    this.consumersDisposable = new CompositeDisposable;
    this.servicesByVersion = {};
    this.versions = [];

    for (let version in servicesByVersion) {
      let service = servicesByVersion[version];
      this.servicesByVersion[version] = {};
      this.versions.push(new SemVer(version));
      setValueAtKeyPath(this.servicesByVersion[version], keyPath, service);
    }

    this.versions.sort((a, b) => b.compare(a));
  }

  provide(consumer) {
    // A consumer can specify multiple version ranges, each with its own
    // callback. It's up to us to (a) find all the versions we advertise that
    // match up with versions that the consumer can consume, then (b) choose
    // the highest version number among these.
    let highestVersion;
    let highestVersionCallback;
    let highestVersionValue;

    for (let version of this.versions) {
      let callback = consumer.callbackForVersion(version);
      if (!callback) continue;

      // This version matches. Does the service name match?
      let value = getValueAtKeyPath(this.servicesByVersion[version.toString()], consumer.keyPath);
      if (!value) continue;

      let isHighestVersion = !highestVersion || gt(version, highestVersion);
      if (!isHighestVersion) continue;

      highestVersion = version;
      highestVersionCallback = callback;
      highestVersionValue = value;
    }

    if (!highestVersionCallback) return;

    let consumerDisposable = highestVersionCallback.call(null, highestVersionValue);

    if (typeof consumerDisposable?.dispose === 'function') {
      this.consumersDisposable.add(consumerDisposable);
    }
  }

  destroy() {
    this.consumersDisposable.dispose();
  }
}

module.exports = Provider;
