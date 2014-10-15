{spawn, exec} = require 'child_process'
fs = require 'fs'
_ = require 'underscore'

BuildSystem = require './build-system'

###
If you have a build system like make, cake, rake, you usually have multiple
targets, which result in "multiple build systems".  These

Derive your build targets providers from this class.
###
class BuildSystemProvider

  # may be null, a string or a list of build files relative to root of current
  # project
  buildFiles: null

  constructor: (@builder, opts) ->
    console.log "buildFiles1", @buildFiles
    if opts
      if typeof opts is "string"
        @buildFiles = path.relative opts.__filename, @builder.root

    console.log "buildFiles2", @buildFiles

      # if @builder.isBuildSystem(opts)
      #   @_buildSystem = new BuildSystem(opts)
      #
      # if opts.__filename
      #   @buildFiles = path.relative opts.__filename, @builder.root

    @commands = {}
    @watchInterval = 3079
    @activate()

  activate: ->
    @root = @builder.root
    #console.log("root #{@root}")
    if @root
      @installWatcher()
      @update()

  deactivate: ->
    if @root
      @uninstallWatcher()

  fileObserver: (curr, prev) =>
    if curr.mtime != prev.mtime
      #console.log("file changed")
      @update()

  # installs watch on files in buildFiles
  installWatcher: ->
    if @buildFiles?
      if not (@buildFiles instanceof Array)
        @buildFiles = [ @buildFiles ]

      for f in @buildFiles
        buildfile = "#{@root}/#{f}".replace(/\/\/+/, "/")

        #console.log("watch #{buildfile}")
        fs.watchFile buildfile, {interval: @watchInterval}, @fileObserver

  uninstallWatcher: ->
    if @buildFiles?

      for f in @buildFiles
        buildfile = "#{@root}/#{f}".replace(/\/\/+/, "/")

        #console.log("unwatch #{buildfile}")
        fs.unwatchFile buildfile, @fileObserver

  # for each buildfile in @buildFiles, there is run `handler` on each file
  #
  # absolute path of buildfile is passed to handler and  handler must return
  # an object.  either empty or it contains a dictionary
  # of command (which is something like "build:buildtoolname-targetname")
  #
  # Value may be one of the following:
  # 1. Build System
  # 2. function
  # 3. args (either a single string for one arg or an Array)
  #
  buildFile: (handler)->
    return {} if not @buildFiles?

    handle = handler

    commands = {}
    for f in @buildFiles
      buildfile = "#{@root}/#{f}".replace(/\/\/+/, "/")
      _.extend(commands, handle buildfile) if fs.existsSync buildfile

    return commands

  # returns build command, which is used for creating atom commands
  buildSystem: (name) ->
    if name instanceof Array
      (new BuildSystem builder: @builder, cmd: @buildTool, args: name).build
    else
      (new BuildSystem builder: @builder, cmd: @buildTool, args: [name]).build

  # implement this function to return a dictionary like described in buildFile
  #
  # usually you would implemnt it like this:
  #
  #    getCommands: ->
  #        @buildFile (buildfile) =>
  #            # now do something with build file
  #
  # Default is to read a json/cson file for
  getCommands: (callback) ->
    @buildFile (buildfile) =>
      if /\.json$/.test buildfile
        data = JSON.parse fs.readFileSync buildfile
      else if /\.cson$/.test buildfile
        data = CSON.parse fs.readFileSync buildfile
      else
        # default is to return empty list of commands
        return callback({})

      data.__filename = buildfile
      data.__dirname  = path.dirname buildfile

      buildsystem = new BuildSystem data, @builder

      commands = {}

      name = buildsystem.name.replace /[^A-Za-z\-]+/g, '-'
      commands["build:#{name}"] = buildsystem

      for variant in buildsystem.variants
        name = variant.name.replace /[^A-Za-z\-]+/g, '-'
        commands["build:#{name}"] = variant

      return commands

  # is called from watcher on file change
  update: -> @getCommands (commands) => @replaceCommands(commands)

  # replaces commands for build targets with new ones
  replaceCommands: (commands) ->
    for k,v of @commands
      if not (k of commands)
        @removeCommand k

    for k,v of commands
      if v instanceof BuildSystem
        @addCommand k, v.build
      if typeof v is "function"
        @addCommand k, (new BuildSystem builder: @builder, build: v).build
      else
        @addCommand k, @buildSystem v

  # adds command to atom workspace
  addCommand: (name, command) ->
    #console.log("add command")
    @commands[name] = command

    if command.scopeName
      @builder.addCommand name, command.scopeName, command
    else
      @builder.addCommand name, command
    #@builder.atom.workspaceView.command name, command

  # removes command from atom workspace
  removeCommand: (name) ->
    #console.log("remove command")
    if @commands[name]
      @builder.removeCommand name

      # @builder.atom.workspaceView.off name
      # # see space-pen jQuery extensions
      # data = @builder.atom.workspaceView.data('documentation')
      # if data?.name?
      #     delete data[name]
      #
      delete @commands[name]

  # run buildTool and call gotline for each line from output of buildTool
  #
  # opts may have cwd, args keys and whatever child_process.exec accepts.
  # args must be an array.
  getLines: (opts, gotline, done) ->
    #console.log "getLines #{opts}, #{gotline}"

    if typeof opts is "function"
      gotline = opts
      opts = {}

    exec_opts =
      cwd: @root

    _.extend exec_opts, opts

    cmd = @buildTool
    if exec_opts.args
      cmd += " " + " ".join(exec_opts.args)
      delete exec_opts.args

    exec cmd, exec_opts, (error, stdout, stderr) ->
      #console.log stdout
      lines = stdout.toString().replace(/\n$/, '').split(/\n/)
      #console.log lines

      for line in lines
        gotline(line) if gotline

      done()

module.exports = BuildSystemProvider
