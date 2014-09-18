###
Handles cakefiles

This package assumes cake is in path.

TODO: find cake also in @root/node_modules/.bin

`cake` is called without arguments to get targets listed.  Each line starting
with "cake" like:
```
    cake install      # installs my package
```
is assumed to describe a target.
###

module.exports = (builder) ->
  {BuildSystemProvider} = builder

  class Cake extends BuildSystemProvider
    buildTool: "cake"
    buildFiles: "Cakefile"

    getCommands: (callback) ->
      #console.log "getCommands Cake"
      @buildFile =>
        #console.log "buildFile callback"
        commands = {}

        gotline = (line) ->
          #console.log "gotline #{line}"
          if /^cake/.test line
            [cmd, desc] = line.replace(/^cake\s+/, '').split(/\s*#\s*/, 1)
            name = cmd.replace(/\W/, '-').replace(/--+/, '-')
            commands["build:cake-#{name}"] = cmd.split /\s+/

        @getLines {}, gotline, -> callback(commands)
