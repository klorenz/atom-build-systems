{$, $$, EditorView, ScrollView} = require 'atom'
buildOutputGrammar = require "./build-output-grammar"
path = require 'path'

class BuildOutput
  constructor: (@builder, @editor) ->
    builder.on 'start', =>
      #console.log "start", this, arguments
      @startBuild.apply this, arguments

    builder.on 'stdout', =>
      #console.log "stdout", this, arguments
      @appendOutput.apply this, arguments

    builder.on 'stderr', =>
      #console.log "stderr", this, arguments
      @appendError.apply this, arguments

    builder.on 'end', =>
      #console.log "end", this, arguments
      @stopBuild.apply this, arguments

    @editor.isModified = ->
      return false

    @titleLoopIndex = null
    @lineno = 0
    @currentBuildResult = null
    @editorView = null

  clear: ->
    @editor.selectAll()
    @editor.delete()

  getEditorView: ->
    return @editorView if @editorView?

    for view in atom.workspaceView.getEditorViews()
      if view.editor is @editor
        @editorView = view
        return @editorView

  withBuildResults: (callback) ->
    buildResults = []

    view = @getEditorView()
    console.log "results", view.find(".build-output.result")
    console.log "parents(line)", view.find(".build-output.result").parents(".line")

    lineCount = @editor.getLineCount()

    @editor.tokenizedLinesForScreenRows(0, lineCount).forEach (tokLine, line) =>
      result = line: line

      tokLine.tokens.forEach (token) =>
        token.scopes.forEach (scope) =>
          if /^meta\.file-name/.test scope
            result.fileName = token.value
          if /^meta\.line-no/.test scope
            result.initialLine = parseInt(token.value)
          if /^meta\.column/.test scope
            result.initalColumn = parseInt(token.value)

      if result.fileName
        if not result.initialColumn
          result.initialColumn = 0
        buildResults.push result

    console.log "buildResults", buildResults

    callback buildResults

    #
    # # get all lines containing a build-output
    # view.find(".build-output.result").parents(".line")
    #   .each ->
    #     $e = $(this)
    #     buildResults.push
    #       line: $e.prevAll().length
    #       fileName: $e.find(".file-name").text()
    #       initialLine: parseInt($e.find(".line-no").text())-1
    #       initialColumn: parseInt($e.find(".column").text() or 0)
    #   .promise().done ->
    #     console.log "buildResults", buildResults
    #     callback buildResults
    #
    # # console.log "buildResults", buildResults
    # #
    # # return buildResults
    #
  gotoPrevResult: -> @withBuildResults (buildResults) =>

    return unless buildResults.length

    row = @editor.getCursorScreenRow()
    prevBuildResult = null
    buildResults.reverse()

    for result in buildResults
      if result.line < row
        prevBuildResult = result
        break

    unless prevBuildResult?
      prevBuildResult = buildResults[0]

    @currentBuildResult = prevBuildResult
    @editor.setCursorScreenPosition([prevBuildResult.line, 0])

  gotoNextResult: (next=true)-> @withBuildResults (buildResults) =>
    prev = not next

    return unless buildResults.length

    if prev
      buildResults.reverse()

    # line is in screen coordinates
    row = @editor.getCursorScreenRow()
    nextBuildResult = null
    for result in buildResults
      if (prev and result.line < row) or (!prev and result.line > row)
        nextBuildResult = result
        break

    unless nextBuildResult?
      nextBuildResult = buildResults[0]

    @currentBuildResult = nextBuildResult
    @editor.setCursorScreenPosition([nextBuildResult.line, 0])

  openResultFile: ->
    unless @currentBuildResult?
      @withBuildResults (buildResults) =>
        row = @editor.getCursorScreenRow()
        for result in buildResults
          if row == result.line
            @currentBuildResult = result
            break
        return

    return unless @currentBuildResult?
    return unless @editor.getCursorScreenRow() == @currentBuildResult.line
    cbs = @currentBuildResult
    absfilename = path.resolve atom.project.getPath(), cbs.fileName

    atom.workspace.open(absfilename, @currentBuildResult)
    # ).done (editor) =>
    #   editor.setCursorBufferPosition([cbs.fileLine-1, cbs.fileColumn ? 0])

  appendData: (data, type) ->
    console.log "appendData", data, type
    console.log "editor", @editor

    unless @editor.getCursors().length
      @editor.addCursorAtBufferPosition([0,0])

    # check if last line visible

    @editor.moveToBottom()

    console.log "ceckpoint1"

    @hasLF = /\n$/.test(data)

    data = data.replace /\n$/, ''
    lines = data.split /\n/

    for line in lines[...-1]
      @lineno += 1
      @editor.insertText(line+"\n",
        undo: "skip", autoIndent: false, autoIndentNewline: false,
        autoDecreaseIndent: false)
      #@editor.insertNewline()

    console.log "ceckpoint2"

    if lines.length
      @editor.insertText(lines[lines.length-1],
        undo: "skip", autoIndent: false, autoIndentNewline: false,
        autoDecreaseIndent: false)

    console.log "ceckpoint3"

    if @hasLF
      @editor.insertText("\n",
        undo: "skip", autoIndent: false, autoIndentNewline: false,
        autoDecreaseIndent: false)

      # following fails with call of setCursorBufferPosition() of undefined
      # because cursors array is empty.  But even if use addcurser, the array
      # keeps empty, so rather use function above
      #@editor.insertNewline()

    console.log "ceckpoint4"

    #if lastline was visible, scroll down to last line

  appendOutput: (data) ->
    #for line in data.split /\n/
    #console.log("appendOutput", data)

    @appendData data, "info"

#    @buildOutput.append $$ -> @li class: "info", => @text(data)

  appendError: (data) ->
    #console.log("appendError", data)
    @appendData data, "error"

    #@buildOutput.append $$ -> @li class: "error", => @text(data)

  stopBuild: (errorcode, timestamp) ->
    #console.log("stopBuild", errorcode, timestamp)
    # unless @hasLF
    #   @editor.insertNewline()

    if errorcode
      summary = "\n[Failed at #{timestamp}, result: #{errorcode}]\n"
      @appendData summary, "error"
    else
      summary = "\n[Success at #{timestamp}, result: #{errorcode}]\n"
      @appendData summary, "success"

    @appendData "\n"
    @appendData "# Hit F4 to go to next result\n"
    @appendData "# Hit Shift-F4 to go to prev result\n"
    @appendData "# Hit ENTER if cursor on result line to open file\n"

    # @buildOutput.append $$ ->
    #   unless errorcode
    #     @li class: "success", => @text(summary)
    #   else
    #     @li class: "error", => @text(summary)

  startBuild: (buildSystem, timestamp) ->
    #console.log("startBuild", buildSystem, timestamp)

    # TODO: if buildSystem.syntax given, then use custom syntax

    grammar = atom.syntax.createGrammar("<generated>", buildOutputGrammar(buildSystem))
    #console.log "grammar", grammar
    @editor.setGrammar(grammar)

    @buildSystem = buildSystem
    @started = timestamp

    cmd = path.basename @buildSystem.cmd

    text = "[Started at #{timestamp}: #{cmd} #{buildSystem.args.join(' ')}]\n"
    @appendData text

    # add id build-output, there is only one view with this ID, this is for
    # making our keymap "enter" selector win the fight against editor specific
    # keybindings

    @getEditorView().attr("id", "build-output")

    #@buildOutput.append $$ -> @li => @text(text)

    #@getPane().activate()

    #super()
    # @titleLoop = [
    #   "[/] Building",
    #   "[-] Building",
    #   "[\\] Building",
    #   "[|] Building",
    # ];
    # @titleLoopIndex = 0

  shutdown: ->
    console.log "build output shutdown called"
    @editor.destroy()



class BuildOutputView extends EditorView
  # @content: =>
  #   @div class: 'build-output-root'
  #
  # @content: =>
  #   # button bar on top to show/hide debug, info, warning, error, fatal
  #
  #   @div class: 'build build-output', =>
  #     @div =>
  #       @ol class: 'output', outlet: 'buildOutput'

    # @div tabIndex: -1, class: 'build overlay from-bottom', =>
    #   @button class: 'btn btn-info', outlet: 'closeButton', click: 'close' , "close"
    #   @div =>
    #     @ol class: 'output panel-body', outlet: 'output'
    #   @div =>
    #     @h1 class: 'title panel-heading', outlet: 'title'

  constructor: (options) ->
    super(options)

    {builder} = options

    console.log "register output callbacks"

    builder.on 'start', =>
      #console.log "start", this, arguments
      @startBuild.apply this, arguments

    builder.on 'stdout', =>
      #console.log "stdout", this, arguments
      @appendOutput.apply this, arguments

    builder.on 'stderr', =>
      #console.log "stderr", this, arguments
      @appendError.apply this, arguments

    builder.on 'end', =>
      #console.log "end", this, arguments
      @stopBuild.apply this, arguments

    @titleLoopIndex = null

    @builder = builder

  makeOutput: (type, data) ->
    data.replace /\n$/, ''

    for line in data.split /\n/
#      for r in @buildSystem.
      $$ -> @li class: type, => @text(line)

  appendOutput: (data) ->
    #for line in data.split /\n/
    #console.log("appendOutput", data)



    @buildOutput.append $$ -> @li class: "info", => @text(data)

  appendError: (data) ->
    #console.log("appendError", data)
    @buildOutput.append $$ -> @li class: "error", => @text(data)

  stopBuild: (errorcode, timestamp) ->
    #console.log("stopBuild", errorcode, timestamp)
    summary = "[Ended at #{timestamp}, result: #{errorcode}]"
    @buildOutput.append $$ ->
      unless errorcode
        @li class: "success", => @text(summary)
      else
        @li class: "error", => @text(summary)

  startBuild: (buildSystem, timestamp) ->
    #console.log("startBuild", buildSystem, timestamp)
    @buildSystem = buildSystem
    @started = timestamp

    text = "[started at #{timestamp}: #{buildSystem.cmd} #{buildSystem.args.join(' ')}]"

    @buildOutput.append $$ -> @li => @text(text)

    #@getPane().activate()

    #super()
    # @titleLoop = [
    #   "[/] Building",
    #   "[-] Building",
    #   "[\\] Building",
    #   "[|] Building",
    # ];
    # @titleLoopIndex = 0

  detach: ->
    atom.workspaceView.focus();
    super()

  reset: =>
    clearTimeout @titleTimer if @titleTimer
    clearTimeout @abortTimer if @abortTimer
    @abortTimer = null
    @titleTimer = null
    @title.removeClass('success')
    @title.removeClass('error')
    @closeButton.hide()
    @output.empty()
    @detach()

  updateTitle: =>
    @title.text @titleLoop[@titleLoopIndex]
    @titleLoopIndex = (@titleLoopIndex + 1) % @titleLoop.length
    @titleTimer = setTimeout @updateTitle, 200

  getTitle: ->
    if @titleLoop?
      @titleLoop[@titleLoopIndex]
    else
      "Build Output"

  clear: ->
    @buildOutput.children().remove()

  getUri: ->
    return "build-output://"

  close: (event, element) ->
    @detach()

  buildStarted: =>
    @reset()
    atom.workspaceView.append(this)
    @focus()
    @updateTitle()

  buildFinished: (success) ->
    @title.text(if success then 'Build finished.' else 'Build failed.')
    @title.addClass(if success then 'success' else 'error')
    @closeButton.show() if !success
    clearTimeout @titleTimer if @titleTimer

  buildAborted: =>
    @title.text('Aborted!')
    @title.addClass('error')
    clearTimeout @titleTimer if @titleTimer
    @abortTimer = setTimeout @reset, 1000

  append: (line) =>
    line = line.toString()
    @output.append "<li>#{line}</li>"
    @output.scrollTop(@output[0].scrollHeight)

module.exports = {BuildOutputView, BuildOutput}
