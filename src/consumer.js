const {Range} = require('semver');

class Consumer {
  constructor(keyPath, versionRange, callback) {
    this.keyPath = keyPath;

    let versionConsumerObj;
    if (typeof versionRange === 'object') {
      // If the second argument is not a string, it must be an object of
      // version/function pairs, and the third argument must be omitted.
      if (typeof callback === 'function') {
        throw new TypeError('versionRange must be a string or an object of version/function pairs');
      }
      versionConsumerObj = versionRange;
    } else {
      versionConsumerObj = { [versionRange]: callback };
    }

    // A consumer can expose multiple version ranges and multiple callback
    // functions. When matching up a single `Provider` to a single `Consumer`,
    // only the best version match (the highest version that satisfies at least
    // one version range) will be used.
    this.versionRangeMap = new Map();
    for (let [versionRange, callback] of Object.entries(versionConsumerObj)) {
      let range = new Range(versionRange);
      this.versionRangeMap.set(range, callback);
    }
  }

  // If the consumer defines several version ranges, some of which may overlap,
  // the first range we encounter that matches the given version will be used.
  //
  // Since a consumer can list version ranges of arbitrary complexity, we
  // cannot choose the "highest" version range, nor can we specify a logical
  // order in which the version ranges are visited. Theoretically, they should
  // be enumerated in the order they're defined, but this is not a guarantee
  // made by the language. (Enumeration order is guaranteed for the map, but
  // not for the bare object we used to create the map.)
  //
  // Thus it's up to the developer to structure these version ranges to rule
  // out overlaps.
  callbackForVersion (targetVersion) {
    for (let [range, callback] of this.versionRangeMap) {
      if (!range.test(targetVersion)) continue;
      return callback;
    }
    return undefined;
  }
}

module.exports = Consumer;
