# A BuildSystem specifies, how something should be built, how output behaves,
# etc.
#
# Not yet all supported, what you see here.  What definitely is supported is
#
# - cmd
# - args
# - cwd
{$$} = require 'atom'
_ = require 'underscore'
path = require 'path'

class BuildSystem

  constructor: (opts, builder) ->
    # assume a filename
    if typeof opts is "string"
      if opts.test /\.(coffee|js)$/
        opts = require opts.replace(/\.coffee$/, '')
      # else if opts.test /\.cson$/
      #   opts =
      # else if opts.test /\.json$/
      #   opts =

    # sublime text opts (see http://sublime-text-unofficial-documentation.readthedocs.org/en/latest/reference/build_systems.html)
    {file_regex, @cmd, @selector, line_regex, @working_dir} = opts
    {@encoding, @env, @shell, @path, @syntax, @name} = opts

    # atom's protocol opts
    {@args, @cwd, @builder, @build, @resultRegexes, @highlight} = opts
    {@__filename, @__dirname} = opts

    if typeof @cmd is "string" and not @args?
      #if /\n/.test cmd allow multiple shell commands as commands
      # each line will be passed to a shell separately, if ails, build stops
      # similar to make recipes

      @cmd = @cmd.split /\s+/

    if @cmd instanceof Array
      @args = cmd[1..]
      @cmd  = cmd[0]

    if @working_dir? and !@cwd
      @cwd = @working_dir

    if builder
      @builder = builder

    if !@build
      @build = => @builder.startNewBuild this

    if !@resultRegexes
      # fill in some defaults
      @resultRegexes = [
        {
          file_regex: /^(\s*)(.*)\((\d+)\)(\s*:\s*(?:warning|error)\s*)(C\d+)/
          output: (mob) ->
            $$ -> @span =>
              @text m[1]
              @span class: 'build-result', =>
                @span class: 'file', => @text m[2]
                @text "("
                @span class: 'line', => @text m[3]
                @text m[4]
                @a href: class: 'browser'  # https://www.google.de/search?q=msdn+compiler+error+C4005&btnI=I%27m+Feeling+Lucky
                @text
        } # VS C++
        { file_regex: /^\s+File "([^"]+)", line (\d+)/ } # Python traceback
        { file_regex: /^\s+from ([^:]+):(\d+)/ }  # ruby traceback
        { file_regex: /\(([^:]*):(\d+):(\d+)\)$/ }  # javascript traceback
        { file_regex: /([^:]*):(\d+):(\d+)/ }  # general
        { file_regex: /([^:]*):(\d+):[^\d]/ }  # general2
      ]

    # if file_regex and line_regex
    #   @resultRegexes = [ {file_regex: file_regex, line_regex: line_regex} ]

    if file_regex
      @resultRegexes = [ {file_regex: file_regex} ]

    # for rr in @resultRegexes
    #   unless rr.output
    #     rr.output =
    variants = []
    if opts.variants
      for variant in opts.variants
        variants.push @clone variant

    unless @name
      @name = path.basename(opts.__filename).replace(/\..*$/, '')

    @variants = variants

  clone: (opts) ->
    new BuildSystem _.extend _.clone(@), opts


module.exports = BuildSystem
