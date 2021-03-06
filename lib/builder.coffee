child_process = require 'child_process'

fs  = require 'fs'
qs  = require 'querystring'
{_} = require 'underscore'
path = require 'path'
CSON = require "season"

BuildSystem           = require './build-system'
BuildSystemProvider   = require './build-system-provider'
{BuildSystemRegistry} = require './build-system-registry'

EventEmitter = require('events').EventEmitter

class Builder extends EventEmitter

  constructor: () ->
    @registry            = new BuildSystemRegistry(this)
    @BuildSystem         = BuildSystem
    @BuildSystemProvider = BuildSystemProvider
    @root                = atom.project.getPath()

    console.log "root", @root
    @building = false

    @on 'end', =>
      @building = false

    @on 'start', =>
      @building = true

    @buildListeners = 0

    @on 'newListener', (event, listener) =>
      #console.log ("new listener for #{event}")

      if 'event' == 'build'
        if @buildListeners
          console.error "There is already a build listener. There must be only one."
          throw "Too many build listeners"

        @buildListeners += 1

    # atom.workspaceView.command "build:trigger", => @build()
    # atom.workspaceView.command "build:stop",    => @stop()

  discoverBuildSystem: (fn) ->
    #console.log "discover", fn

    stat = fs.statSync fn
    return false if stat.isDirectory()

    if /\.json$/.test fn
      data = JSON.parse fs.readFileSync fn
      return false unless @isBuildSystem data
      @register new BuildSystemProvider builder, fn

    else if /\.cson$/.test fn
      data = CSON.readFileSync fn
      return false unless @isBuildSystem data
      @register new BuildSystemProvider builder, fn

    else
#      console.log "else", fn
      try
        modname = fn.replace(/\.[^/]*$/, '')
        # expect a coffee/js/etc. file to have an extension
        return false if modname == fn
#        console.log "modname", modname
        module = require modname
#        console.log "loaded module"
      catch e
        # no error message for non-modules
        return false if /^Error: Cannot find module/.test e.toString()
        #if /\.coffee|\.js/.
        console.log e.stack
        return false

#      console.log "module", module

      return false unless typeof module is "function"

      obj = module(this)

      #console.log "obj", obj

      @register obj

      # if obj instanceof BuildSystemProvider or obj instanceof BuildSystem or u
      #   @register obj
      # else
      #   return false

    return true

  discoverBuildSystems: ->
    # at this point getActivePackages() might not yet return correct number
    # of active packages.

    for pkg in atom.packages.getLoadedPackages()
      continue unless pkg.configActivated

    #   if pkg.mainModule?.registerBuildSystem?
    #     pkg.mainModule.registerBuildSystem this
      build_systems_dir = "#{pkg.path}/build-systems"
      if fs.existsSync build_systems_dir
        for fn in fs.readdirSync build_systems_dir
          @discoverBuildSystem path.join build_systems_dir, fn

    if @root
      for fn in fs.readdirSync @root
        @discoverBuildSystem "#{@root}/#{fn}"

  isBuildSystem: (obj) ->
    return obj.cmd

  projectPathChanged: ->
    if atom.project
        @root = atom.project.getPath()

    if @root?
      @registry.updateBuildSystems()

  register: ->
    @registry.register.apply @registry, arguments

  addCommand: (commandName, selector, options, handler) ->
    console.log("add command #{commandName}")
    atom.workspaceView.command commandName, selector, options, handler

  # removes command from atom workspace
  removeCommand: (name) ->
    console.log("remove command #{name}")
    atom.workspaceView.off name
    # see space-pen jQuery extensions
    data = atom.workspaceView.data('documentation')
    if data?.name?
      delete data[name]

  shutdown: ->
    @child.kill('SIGKILL') if @child

    if @registry?
      @registry.unregister()

    @removeAllListeners()

  build: (callback) ->
    console.log('build')
    @emit 'build', callback

  start: (buildSystem) ->
    console.log('start', buildSystem)
    @emit 'start', buildSystem, new Date()

  stdout: (data) ->
    data = data.toString()
    console.log('stdout', data)
    @emit 'stdout', data
    @emit 'output', data

  print: (data) ->
    data = data.toString()
    console.log('print', data)
    @emit 'stdout', data
    @emit 'output', data

  stderr: (data) ->
    data = data.toString()
    console.log('stderr', data)
    @emit 'stderr', data
    @emit 'output', data

  exit: (code) ->
    console.log('exit', code)
    @emit 'end', code, new Date()

  end: (code) ->
    console.log('end', code)
    @emit 'end', code, new Date()

  output: (data) ->
    data = data.toString()
    console.log('output', data)
    @emit 'output', data
    @emit 'stdout', data

  resolveVars: (buildSystem) ->
    activeEditor = atom.workspace.getActiveEditor()
    newBuildSystem = {}
    if activeEditor
      file_name = activeEditor.getPath()
    else
      file_name = ""

    if atom.project
      project_path   = atom.project.getPath()
    else
      project_path = ''

    vars =
      file_path: path.dirname(file_name)
      file_extension: path.extname(file_name)
      file_base_name: path.basename(file_name, path.extname(file_name))
      file_name: path.basename(file_name)
      file: file_name
      packages: atom.packages.getPackageDirPaths()[0]
      project: project_path    # there is no special atom project file
      project_path: project_path
      project_name: path.basename(project_path)
      project_extension: ""
      project_base_name: path.basename(project_path)

    for k,v of buildSystem
      unless typeof v == "string"
        newBuildSystem[k] = v
        continue

      v = v.replace ///
        \$( file_name
          | file_path
          | file_extension
          | file_base_name
          | file
          | packages
          | project
          | project_path
          | project_name
          | project_extension
          | project_base_name
          ) \b
          ///, (mob) -> vars[mob[1..]]

      v = v.replace ///
        \$\{ ( file_name
          | file_path
          | file_extension
          | file_base_name
          | file
          | packages
          | project
          | project_path
          | project_name
          | project_extension
          | project_base_name
          \}) \b
          ///, (mob) -> vars[mob[2...-1]]

      # TODO: support ${foo:default} ${foo/replace/bythis/}
      # TODO: support getting env vars

      newBuildSystem[k] = v

    newBuildSystem


  startNewBuild: (buildSystem) ->

    buildSystem = @resolveVars(buildSystem)

    {cmd, args, env, cwd} = buildSystem

    args = [] unless args
    env = {} unless env
    cwd = @root unless cwd
    env = _.extend {}, process.env, env

    @build =>
      @start(buildSystem)

      @child = child_process.spawn(cmd, args, {cwd, env})
      @child.stdout.on 'data', (data) => @stdout data
      @child.stderr.on 'data', (data) => @stderr data
      @child.on 'close', (exitCode) =>
        #@buildView.buildFinished(0 == exitCode)
        #@finishedTimer = (setTimeout (=> @buildView.detach()), 1000) if (0 == exitCode)
        @child = null
        @end exitCode

  abort: (cb) ->
    @child.removeAllListeners 'close'
    @child.on 'close', =>
      @child = null
      cb() if cb
    @child.kill()

  # build: ->
  #   clearTimeout @finishedTimer
  #   if @child then @abort(=> @startNewBuild()) else @startNewBuild()

  stop: ->
    if @child
      @abort()
      @buildView.buildAborted()
    else
      @buildView.reset()

module.exports = Builder
