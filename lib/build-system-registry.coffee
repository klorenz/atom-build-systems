issubclass = (B, A) ->
  B.prototype instanceof A

BuildSystemProvider = require './build-system-provider'

class BuildSystemRegistry
  constructor: (@builder) ->
    @registry = []
    @buildsystems = []
    @containers = []

  register: (thing) ->
    if thing instanceof Array
      for x in thing
        @register x

    else if issubclass(thing, BuildSystemProvider) and  not (thing in @registry)
      @registry.push thing
      @containers.push new thing(@builder)

    else if thing instanceof BuildSystem
      if not (thing in @buildsystems)
        @buildsystems.push thing
        if thing.__filename
          builder.installWatcher thing.__filename
    else
      @register new BuildSystem(thing)

  unregister: (thing) ->
    if not thing
      for x in @containers
        x.deactivate()
      @containers = []
      @registry = []
      @buildsystems = []
      return

    if thing in @buildsystems
      @buildsystems.remove thing
      if thing.variants
        for variant in thing.variants
          @buildsystems.remove variant

    else if thing in @registry
      idx = @registry.indexOf thing
      @registry.splice idx, 1
      @containers.splice idx, 1

  deactivate: ->
    console.log "deactivate"
    for x in @containers
      x.deactivate()

    # for buildsystem in @buildSystems
    #   builder.removeCommand

  activate: ->
    console.log "activate"
    for x in @containers
      x.activate()

    # for buildsystem in @buildSystems
    #   builder.addCommand


  updateBuildSystems: ->
    @deactivate()
    @activate()

module.exports = {issubclass, BuildSystemRegistry}
