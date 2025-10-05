const {SemVer} = require('semver');
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

  provide (consumer) {
    for (let version of this.versions) {
      if (consumer.versionRange.test(version)) {
        let value = getValueAtKeyPath(this.servicesByVersion[version.toString()], consumer.keyPath);
        if (value) {
          let consumerDisposable = consumer.callback.call(null, value);
          if (typeof consumerDisposable?.dispose === 'function') {
            this.consumersDisposable.add(consumerDisposable);
          }
          return;
        }
      }
    }
  }

  destroy() {
    this.consumersDisposable.dispose();
  }
}

module.exports = Provider;
