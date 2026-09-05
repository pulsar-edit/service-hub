{Disposable} = require 'event-kit'
ServiceHub = require '../src/service-hub'
Consumer = require '../src/consumer'

describe "ServiceHub", ->
  hub = null

  beforeEach ->
    hub = new ServiceHub

  onNextTick = (fn) ->
    waits(1)
    runs(fn)

  describe "::consume(keyPath, versionString, callback)", ->
    it "invokes the callback with each existing service that matches the key path and version range", ->
      services = []

      hub.provide "a", "1.0.0", w: 1
      hub.provide "b", "1.0.0", x: 2
      hub.consume "a", "^1.0.0", (service) -> services.push(service)
      expect(services).toEqual [{w: 1}]

      hub.provide "a", "1.1.0", y: 3
      hub.provide "b", "1.2.0", z: 4
      expect(services).toEqual [{w: 1}, {y: 3}]

    it "invokes the callback with the newest version of a service provided in a given batch", ->
      hub.provide "a",
        "1.0.0": {w: 1}
        "1.1.0": {x: 2}
      hub.provide "a",
        "1.2.0": {y: 3}
      hub.provide "b",
        "1.0.0": {z: 4}

      services = []
      hub.consume "a", "^1.0.0", (service) -> services.push(service)

      expect(services).toEqual [{x: 2}, {y: 3}]

    it "invokes the callback when a new service is provided that matches the key path and version range", ->
      services = []
      hub.consume "a", "^1.0.0", (service) -> services.push(service)
      expect(services).toEqual []

      hub.provide "a", "1.0.0", x: 1
      hub.provide "a", "1.1.0", y: 2
      hub.provide "b", "1.0.0", z: 3
      expect(services).toEqual [{x: 1}, {y: 2}]

    it "invokes the callback with the newest version of a service provided in a given batch when 'consume' is called with an object", ->
      hub.provide "a",
        "1.0.0": {w: 1}
        "1.1.0": {x: 2}
      hub.provide "a",
        "1.2.0": {y: 3}
      hub.provide "b",
        "1.0.0": {z: 4}
      hub.provide "a",
        "1.1.0": { should_not_be_used: 999 },
        "1.2.0": { v: 0 }
      hub.provide "a",
        "1.0.0": { w: -1 }

      services100 = []
      services110 = []
      services120 = []

      hub.consume "a", {
        '1.0.0': (s) -> services100.push(s),
        '1.1.0': (s) -> services110.push(s),
        '1.2.0': (s) -> services120.push(s)
      }

      # The first and third `a` providers should fulfill with only the higher
      # of the two services they expose.
      expect(services100).toEqual([{ w: -1 }])
      expect(services110).toEqual([{ x: 2 }])
      expect(services120).toEqual([{ y: 3 }, { v: 0 }])

    it "prefers the most specific matching version range when a consumer's ranges overlap", ->
      calls = []

      hub.provide "my-service",
        "1.0.0": {v: 1}
        "2.0.0": {v: 2}

      hub.consume "my-service", {
        '>=1.0.0': (s) -> calls.push(['v1-handler', s]),
        '^2.0.0': (s) -> calls.push(['v2-handler', s])
      }

      expect(calls).toEqual [['v2-handler', {v: 2}]]

    it "falls back to a less specific range when the more specific one does not match", ->
      calls = []

      hub.provide "my-service", "1.5.0", {v: 1}

      hub.consume "my-service", {
        '>=1.0.0': (s) -> calls.push(['v1-handler', s]),
        '^2.0.0': (s) -> calls.push(['v2-handler', s])
      }

      expect(calls).toEqual [['v1-handler', {v: 1}]]

    it "passes the resolved version as the second argument to the callback", ->
      versions = []

      hub.provide "a",
        "1.0.0": {w: 1}
        "2.3.4": {x: 2}
      hub.provide "a", "1.1.0", {y: 3}

      hub.consume "a", ">=1.0.0", (service, version) -> versions.push(version)

      expect(versions).toEqual ["2.3.4", "1.1.0"]

    it "can specify a key path that navigates into the contents of a service", ->
      hub.provide "a", "1.0.0", b: c: 1
      hub.provide "a", "1.0.0", d: e: 2

      services = []
      hub.consume "a.b", "^1.0.0", (service) -> services.push(service)
      expect(services).toEqual [{c: 1}]

    it "can specify a key path that's shorter than the key path passed to ::provide", ->
      hub.provide "a.b", "1.0.0", c: 1
      hub.provide "a.d", "1.0.0", e: 2

      services = []
      hub.consume "a", "^1.0.0", (service) -> services.push(service)
      expect(services).toEqual [{b: c: 1}, {d: e: 2}]

  describe "version range ordering", ->
    orderOf = (versionConsumerObj) ->
      consumer = new Consumer("a", versionConsumerObj)
      consumer.versionRanges.map ({range}) -> range.raw

    noop = ->

    it "sorts overlapping ranges by descending lower bound", ->
      expect(orderOf({'>=1.0.0': noop, '^2.0.0': noop}))
        .toEqual ['^2.0.0', '>=1.0.0']

      expect(orderOf({'>=0.2 <=0.3.6': noop, '^0.4.1': noop}))
        .toEqual ['^0.4.1', '>=0.2 <=0.3.6']

      expect(orderOf({'*': noop, '^3.0.0': noop, '^2.0.0': noop}))
        .toEqual ['^3.0.0', '^2.0.0', '*']

    it "preserves the declared order of ranges that tie on their lower bound", ->
      expect(orderOf({'>=1.0.0': noop, '^1.0.0': noop}))
        .toEqual ['>=1.0.0', '^1.0.0']

      expect(orderOf({'^1.0.0': noop, '>=1.0.0': noop}))
        .toEqual ['^1.0.0', '>=1.0.0']

    it "sorts unsatisfiable ranges last instead of throwing", ->
      expect(orderOf({'>=2 <1': noop, '^1.0.0': noop}))
        .toEqual ['^1.0.0', '>=2 <1']

    it "does not depend on the caller's key order", ->
      # JS hoists canonical numeric keys to the front of an object regardless
      # of insertion order, so the caller cannot control this.
      expect(orderOf({'2': noop, '1': noop, '^3.0.0': noop}))
        .toEqual ['^3.0.0', '2', '1']

  describe "input validation", ->
    it "rejects a versionRange that is neither a string nor a plain object", ->
      expect(-> hub.consume "x", null)
        .toThrow('versionRange must be a string or an object of version/function pairs')
      expect(-> hub.consume "x", ['^1.0.0'])
        .toThrow('versionRange must be a string or an object of version/function pairs')
      expect(-> hub.consume "x", 42)
        .toThrow('versionRange must be a string or an object of version/function pairs')

    it "rejects an object versionRange when a callback is also given", ->
      expect(-> hub.consume "x", {'^1.0.0': (->)}, (->))
        .toThrow('versionRange must be a string or an object of version/function pairs')

    it "rejects a version that is neither a string nor a plain object", ->
      expect(-> hub.provide "x", null)
        .toThrow('version must be a string or an object of version/service pairs')
      expect(-> hub.provide "x", ['1.0.0'])
        .toThrow('version must be a string or an object of version/service pairs')
      expect(-> hub.provide "x", "1.0.0")
        .toThrow('version must be a string or an object of version/service pairs')

  describe "disposing of a consumer", ->
    it "marks the consumer as destroyed so it is skipped mid-iteration", ->
      services1 = []
      services2 = []

      disposable2 = null
      hub.consume "a", "^1.0.0", (service) ->
        services1.push(service)
        disposable2.dispose()
      disposable2 = hub.consume "a", "^1.0.0", (service) -> services2.push(service)

      hub.provide "a", "1.0.0", x: 1

      expect(services1).toEqual [{x: 1}]
      expect(services2).toEqual []

    it "does not invoke the consumer callback for any newly-added providers", ->
      services = []
      disposable = hub.consume "a", "^1.0.0", (service) -> services.push(service)

      hub.provide "a", "1.0.0", x: 1

      disposable.dispose()

      hub.provide "a", "1.0.1", y: 2
      expect(services).toEqual [{x: 1}]

  describe "disposing of a provider", ->
    it "does not invoke the callbacks of any newly-added consumers", ->
      disposable1 = hub.provide "a", "1.0.0", x: 1
      disposable2 = hub.provide "a", "1.1.0", y: 2

      services1 = []
      hub.consume "a", "^1.0.0", (service) -> services1.push(service)

      disposable1.dispose()

      services2 = []
      hub.consume "a", "^1.0.0", (service) -> services2.push(service)
      expect(services1).toEqual [{x: 1}, {y: 2}]
      expect(services2).toEqual [{y: 2}]

    it "disposes of consumer Disposables", ->
      provideDisposable = hub.provide "a", "1.0.0", x: 1

      teardownConsumerSpy1 = jasmine.createSpy('teardownConsumer1')
      teardownConsumerSpy2 = jasmine.createSpy('teardownConsumer2')

      hub.consume "a", "^1.0.0", (service) -> new Disposable(teardownConsumerSpy1)
      hub.consume "a", "^1.0.0", (service) -> new Disposable(teardownConsumerSpy2)
      provideDisposable.dispose()

      expect(teardownConsumerSpy1).toHaveBeenCalled()
      expect(teardownConsumerSpy2).toHaveBeenCalled()

  describe "::clear()", ->
    it "removes all providers and consumers, disposing of consumers' disposables", ->
      hub.provide "a", "1.0.0", w: 1
      hub.provide "b", "1.0.0", x: 2

      consumeSpy = jasmine.createSpy('consume')
      teardownConsumer1Spy = jasmine.createSpy('teardownConsumer1')
      teardownConsumer2Spy = jasmine.createSpy('teardownConsumer2')

      hub.consume "a", "^1.0.0", (service) -> new Disposable(teardownConsumer1Spy)
      hub.consume "b", "^1.0.0", (service) -> new Disposable(teardownConsumer2Spy)

      hub.clear()
      expect(teardownConsumer1Spy).toHaveBeenCalled()
      expect(teardownConsumer2Spy).toHaveBeenCalled()

      hub.consume "a", "^1.0.0", consumeSpy
      expect(consumeSpy).not.toHaveBeenCalled()
