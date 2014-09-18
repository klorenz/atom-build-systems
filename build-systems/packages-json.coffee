fs = require 'fs'

{_} = require 'underscore'

module.exports = (builder) ->
  {BuildSystemProvider} = builder

  ###
  Handle defined `npm` targets.

  TODO:
  - add more NPM targets
  - add a publish minor, publish major, etc like APM has

  Assumes that npm is in path.
  ###


  class Npm extends BuildSystemProvider

    buildTool: "npm"

    buildTargets: [
      "install"
      "publish"
      "test"
    ]

    buildFiles: "package.json"

    canUpdate: (data) ->
      return true

    getCommands: (callback) ->
      @buildFile (buildfile) =>
        #console.log "buildFile: #{buildfile}"
        data = JSON.parse fs.readFileSync(buildfile, "utf8")

        commands = {}

        buildToolName = @buildTool.replace(/.*\//, '').replace(/\..*$/, '')

        if @canUpdate(data)
          #console.log "can update", @buildTargets

          for target in @buildTargets
            #console.log "target", target
            cmd = target
                  .replace(/\s+/, "-")
                  .replace(/\W/, "-")
                  .replace(/--+/, "-")

            args = target.split(/\s+/)

            #console.log cmd, args

            commands["build:#{buildToolName}-#{cmd}"] = args

          #commands["build:#{buildToolName}-publish-patch"] = =>
            # if there are changes on git working copy error
            # get most recent tag
            # increase patch number
            # set new tag
            # git push
            # npm publish --tag <newtag>

        #console.log "commands", commands

        callback(commands)

  ###
  Handle predefined APM targets.

  TODO:
  - add more targets
  ###

  class Apm extends Npm

    buildTool: atom.packages.getApmPath()

    buildTargets: [
      "install"
      "publish major"
      "publish minor"
      "publish patch"
      "test"
    ]

    canUpdate: (data) ->
      return false if not data
      return false if not data.engines

      return "atom" of data.engines

  [Apm, Npm]
