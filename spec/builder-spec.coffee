Builder = require '../lib/builder'
temp = require 'temp'
{WorkspaceView} = require 'atom'

describe "Builder", ->
  describe "resolveVars", ->

    beforeEach ->
      atom.workspaceView = new WorkspaceView
      atom.workspace = atom.workspaceView.model
      atom.project.setPath(temp.mkdirSync('some-test-package-'))
      fs.copySync(path.join(__dirname, 'fixtures'), atom.project.getPath())
      activatePromise = atom.packages.activatePackage('atom-build-systems')
      # atom.workspaceView.attachToDom()

    it "resolves variables in a given build system", ->
      builder = new Builder()

      # need workspace.getActiveEditor()
      # and  project.getPath()
      bs = builder.resolveVars
        cmd: "python ${file}"
        cwd: "${file_path}"

      expect(bs).toEqual
        cmd: "python"
        cwd: "xy"
