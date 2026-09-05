const {SemVer} = require('semver');
const {CompositeDisposable} = require('event-kit');

const {getValueAtKeyPath, setValueAtKeyPath} = require('./helpers');

class Provider {
  constructor(keyPath, servicesByVersion) {
    if (!servicesByVersion || typeof servicesByVersion !== 'object' || Array.isArray(servicesByVersion)) {
      throw new TypeError('version must be a string or an object of version/service pairs');
    }

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
    // callback. It's up to us to find the highest version we advertise that
    // the consumer can consume. Since `this.versions` is sorted in descending
    // order, the first match is the answer.
    for (let version of this.versions) {
      let callback = consumer.callbackForVersion(version);
      if (!callback) continue;

      // This version matches. Does the service name match?
      let value = getValueAtKeyPath(this.servicesByVersion[version.toString()], consumer.keyPath);
      if (!value) continue;

      let consumerDisposable = callback.call(null, value, version.toString());

      if (typeof consumerDisposable?.dispose === 'function') {
        this.consumersDisposable.add(consumerDisposable);
      }
      return;
    }
  }

  destroy() {
    this.consumersDisposable.dispose();
  }
}

module.exports = Provider;
