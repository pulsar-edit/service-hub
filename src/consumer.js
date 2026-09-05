const {Range, minVersion, rcompare} = require('semver');

class Consumer {
  constructor(keyPath, versionRange, callback) {
    this.keyPath = keyPath;

    let versionConsumerObj;
    if (versionRange && typeof versionRange === 'object' && !Array.isArray(versionRange)) {
      // If the second argument is not a string, it must be an object of
      // version/function pairs, and the third argument must be omitted.
      if (typeof callback === 'function') {
        throw new TypeError('versionRange must be a string or an object of version/function pairs');
      }
      versionConsumerObj = versionRange;
    } else if (typeof versionRange === 'string') {
      versionConsumerObj = { [versionRange]: callback };
    } else {
      throw new TypeError('versionRange must be a string or an object of version/function pairs');
    }

    // A consumer can expose multiple version ranges and multiple callback
    // functions. When matching up a single `Provider` to a single `Consumer`,
    // only the best version match (the highest version that satisfies at least
    // one version range) will be used.
    //
    // Since those ranges may overlap, we sort them by their lower bounds in
    // descending order; that way the most specific match for a given version
    // is always the first one we encounter. Ranges that are unsatisfiable
    // (like `>=2 <1`) have no minimum version, so they sort last. Ties keep
    // their declared order, since `Array#sort` is stable.
    this.versionRanges = Object.entries(versionConsumerObj)
      .map(([raw, callback]) => {
        const range = new Range(raw);
        return { range, callback, min: minVersion(range) };
      })
      .sort((a, b) => (a.min && b.min) ? rcompare(a.min, b.min) : (a.min ? -1 : 1));
  }

  // Returns the callback belonging to the first version range that matches the
  // given version. Because the ranges are sorted by descending lower bound,
  // the first match is also the most specific one.
  callbackForVersion (targetVersion) {
    for (let {range, callback} of this.versionRanges) {
      if (!range.test(targetVersion)) continue;
      return callback;
    }
    return undefined;
  }
}

module.exports = Consumer;
