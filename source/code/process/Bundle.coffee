# externals
_ = require 'lodash'
_.mixin (require 'underscore.string').exports()
fs = require 'fs'
wrench = require 'wrench'
_B = require 'uberscore'
l = new _B.Logger 'urequire/process/Bundle'
globExpand = require 'glob-expand'
minimatch = require 'minimatch'

# uRequire
upath = require '../paths/upath'
MasterDefaultsConfig = require '../config/MasterDefaultsConfig'
AlmondOptimizationTemplate = require '../templates/AlmondOptimizationTemplate'
Dependency = require '../Dependency'
DependenciesReporter = require './../utils/DependenciesReporter'
UError = require '../utils/UError'

#our file system
BundleFile = require './../fileResources/BundleFile'
FileResource = require './../fileResources/FileResource'
TextResource = require './../fileResources/TextResource'
Module = require './../fileResources/Module'

Build = require './Build'
BundleBase = require './BundleBase'

isFileInSpecs = require '../utils/isFileInSpecs'

debugLevelSkipTempDeletion = 50

###
  @todo: doc it!
###
class Bundle extends BundleBase
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p
  Function::staticProperty = (p)=> Object.defineProperty @::, n, d for n, d of p

  constructor:-> @_constructor.apply @, arguments
  _constructor: (bundleCfg)->
    _.extend @, bundleCfg
    @reporter = new DependenciesReporter()
    @filenames = @getGlobExpandFilez() #our initial filenames
    @files = {}  # all bundle files are in this map
#    @files[filename] = {} for filename in @filenames #initialized to an unknown placeholder

  getGlobExpandFilez:->
    _.filter globExpand({cwd: @path}, '**/*.*'), (f)=> isFileInSpecs f, @filez

  @staticProperty requirejs: get:=> require 'requirejs'

  @property
    modules: get:-> _.pick @files, (file)-> file instanceof Module
    fileResources: get:-> _.pick @files, (file)-> file instanceof FileResource # includes TextResource & Module

  ###
    Processes each filename, either as array of filenames (eg instructed by `watcher`) or all @filenames

    If a filename is new, create a new BundleFile (or more interestingly a TextResource or Module)

    In any case, refresh() each one, either new or existing

    @param []<String> with filenames to process.
      @default ALL files from filesystem (property @filenames)

    @return Number of bundlefiles changed, i.e @change.bundlefiles
  ###
  loadOrRefreshResources: (filenames = @filenames)->
    l.debug """\n
      #####################################################################
      loadOrRefreshResources: filenames.length = #{filenames.length}
      #####################################################################""" if l.deb 30
    updateChanged = => # @todo: refactor this
      @changed.bundlefiles++ #
      @changed.resources++ if bundlefile instanceof FileResource
      @changed.modules++ if bundlefile instanceof Module
      @changed.errors++ if bundlefile.hasErrors

    # check which filenames match resource converters
    # and instantiate them as TextResource or Module
    for filename in filenames
      isNew = false

      if not @files[filename] # a new filename
        isNew = true
        matchedConverters = [] # create a XXXResource (eg Module), if we have some matchedConverters
        dstFilename = filename

        # Add matched converters
        # - match filename in resConv.filez, either srcFilename or dstFilename depending on `~` flag
        # - determine its clazz from type
        # - until a terminal converter found
        for resConv in @resources
          if isFileInSpecs (if resConv.isMatchSrcFilename then filename else dstFilename), resConv.filez
            # converted dstFilename for converters `filez` matching (i.e 'myDep.js' instead of 'myDep.coffee')
            if _.isFunction resConv.convFilename
              dstFilename = resConv.convFilename dstFilename, filename

            matchedConverters.push resConv
            break if resConv.isTerminal

        # NOTE: last matching converter (that has a clazz) determines if file is a TextResource || FileResource || Module
        lastResourcesWithClazz =  _.filter matchedConverters, (conv)-> conv.clazz
        resourceClass = _.last(lastResourcesWithClazz)?.clazz or BundleFile       # default is BundleFile

        l.debug "New *#{resourceClass.name}*: '#{filename}'" if l.deb 80
        @files[filename] = new resourceClass @, filename, matchedConverters
      else
        l.debug "Refreshing existing resource: '#{filename}'" if l.deb 80

      bundlefile = @files[filename]
      try
         # compilations / conversions on refresh() = true if resource.hasChanged
        updateChanged() if bundlefile.refresh()

        if isNew # check there is no same dstFilename
          if sameDstFile = (
            _.find @files, (f)=>
                f.dstFilename is bundlefile.dstFilename and
                f isnt bundlefile
          )
            l.err uerr = """
              Same dstFilename '#{sameDstFile.dstFilename}' for '#{bundlefile.filename}' & '#{sameDstFile.filename}'
            """
            bundlefile.hasErrors = true
            throw new UError uerr

      catch err
        if not fs.existsSync bundlefile.srcFilepath  # remove it, if missing from filesystem

          delMsgs = ["Missing file: ", bundlefile.srcFilepath,
                    "\n  Removing bundle file: ", filename]
          delMsgs.push "\n  Deleting build in dstPath: #{bundlefile.dstFilepath}" if bundlefile.dstExists
          l.verbose.apply l, delMsgs

          if bundlefile.dstExists
            try
              fs.unlinkSync bundlefile.dstFilepath
            catch err
              l.err "Cant delete destination file '#{bundlefile.dstFilepath}'."
          else
            l.err "No dstFilepath / dstExists for '#{filename}'."

          #updateChanged()
          delete @files[filename]

        else
          uerr = new UError "Something wrong while loading/refreshing/processing '#{filename}'.", {stack:true, nested:err}
          l.err uerr.message
          if not (@build.continue or @build.watch)
            l.log uerr
            throw uerr
          else
            l.warn "Continuing from error due to @build.continue || @build.watch - not throwing:\n", uerr


    @filenames = _.keys @files
    @dstFilenames = _.map @files, (file)-> file.dstFilename # just dstFilenames
    return @changed.bundlefiles

  ###
    build / convert all resources that have changed since last
  ###
  buildChangedResources: (@build, filenames=@filenames)->
    l.debug """\n
      #####################################################################
      buildChangedResources: filenames.length = #{filenames.length}
      #####################################################################""" if l.deb 30
    @changed = bundlefiles:0, resources: 0, modules: 0, errors: 0 #reset all change counters

    @isPartialBuild = filenames isnt @filenames

    @reporter = new DependenciesReporter() #each build has a new reporter

    # for 'partial' i.e 'watched' filenames
    if @isPartialBuild
      # filter filenames not passing through bundle.filez
      bundleFilenames = _.filter filenames, (f)=> isFileInSpecs f, @filez
      if diff = filenames.length - bundleFilenames.length
        l.verbose "Ignored #{diff} non bundle.filez"
        filenames = bundleFilenames

    if filenames.length > 0
      # setup 'combinedFile' on 'combined' template
      # (i.e where to output AMD-like templates & where the combined .js file)
      if (@build.template.name is 'combined') and (not @build.combinedFile) # fix 1st time only
        @build.combinedFile = upath.changeExt @build.dstPath, '.js'
        @build.dstPath = "#{@build.combinedFile}__temp"
        l.debug("Setting @build.combinedFile =", @build.combinedFile,
                '\n  and @build.dstPath = ', @build.dstPath) if l.deb 30

      # now load/refresh some filenames (or all @filenames)
      if @loadOrRefreshResources(filenames) > 0 # returns @changed.bundlefiles
        if @changed.modules
          l.debug """\n
            #####################################################################
            Converting changed modules with template '#{@build.template.name}'
            #####################################################################""" if l.deb 30
          for filename in filenames
            if uModule = @files[filename] # exists when refreshed, but not deleted
              if uModule?.hasChanged and (uModule instanceof Module) # it has changed, conversion needed
                try
                  uModule.convertWithTemplate @build
                  uModule.runResourceConverters (converter)-> converter.isAfterTemplate is true
                catch err
                  uerr = new UError 'Uncaught Exception at Module.convertWithTemplate or uModule.runResourceConverters', {nested:err}
                  l.err uerr.message
                  @changed.errors++
                  uModule.hasErrors = true
                  if @build.continue then continue else throw uerr

        if not @isPartialBuild
          @hasFullBuild = true if @changed.errors is 0
        else
          # partial build - Warn and perhaps force a full build... # @todo: (3 3 2) add more cases
          if (not @hasFullBuild) and @changed.resources
            forceFullBuild = false
            partialWarns = ["Partial build, without a previous full build."]

            # last chance to skip forcing full build (high debug mode)
            if fs.existsSync(@build.dstPath) and
              (l.deb(debugLevelSkipTempDeletion) || @build.watch) # just warn!
                partialWarns.push w for w in [
                  "\nNOT PERFORMING a full build cause fs.exists(@build.dstPath)", @build.dstPath,
                  "\nand (@build.watch or debugLevel >= #{debugLevelSkipTempDeletion} or @build.template.name isnt 'combined')"
                ]
            else
              if @build.template.name is 'combined'
                partialWarns.push w for w in [
                   "on 'combined' template.",
                   "\nForcing a full build of all module to __temp directory: ", @build.dstPath]
                forceFullBuild = true

            if forceFullBuild
              filenames = @filenames              # full build, all files
              @hasFullBuild = true                # note it
              file.reset() for fn, file of @files
              if @build.watch
                partialWarns.push "\nNote on watch: NOT DELETING ...__temp - when you quit 'watch'-ing, delete it your self!"
                debugLevelSkipTempDeletion = 0      # dont delete ___temp

              l.warn.apply l, partialWarns

              @buildChangedResources @build, @getGlobExpandFilez() # call self, with all filesystem @filenames
              return # dont run again!
            else
              partialWarns.push """\n
                Note: other modules info not available: falsy errors possible, including :
                  * `Bundle-looking dependencies not found in bundle`
                  * requirejs.optmize crashing, not finding some global var etc.
                Best advice: a full fresh build first, before watch-ing.
                """
              l.warn.apply l, partialWarns

        @saveChangedResources()

      copied = @copyNonResourceFiles filenames

      # some build reporting
      report = @reporter.getReport @build.interestingDepTypes
      l.warn 'Report for this `build`:\n', report if not _.isEmpty report
      l.verbose "Copied #{copied[0]} files, Skipped copying #{copied[1]} files." if copied[0] or copied[1]
      l.verbose "Changed & built: #{@changed.resources} resources of which #{@changed.modules} were modules."
      l.err "#{@changed.errors} files/resources with errors in this build." if @changed.errors

    # 'combined' or done()
    if (@build.template.name is 'combined')
      if @changed.modules # @todo: if @@changed.modules or (@changed.bundlefiles and build.template.{combined}.noModulesBuild
        @combine @build # @todo: allow throwing errors for better done() handling
      else
        l.debug 30, "Not executing *'combined' template optimizing with r.js*: no @modulesChanged."
        @build.done not @changed.errors
    else
      @build.done not @changed.errors

  saveChangedResources:->
    if @changed.resources
      l.debug """\n
        #####################################################################
        Saving changed resource files that have a `converted` String
        #####################################################################""" if l.deb 30
      fr = @fileResources
      for fn, resource of fr when resource.hasChanged
        if resource.converted and _.isString(resource.converted) # only non-empty Strings are written
          if _.isFunction @build.out # @todo:5 else if String, output to this file ?
            @build.out resource.dstFilepath, resource.converted
        else
          l.debug 80, "Not saving #{resource.dstFilename} cause its not a non-empty String."

        resource.hasChanged = false
    null

  # All @files (i.e bundle.filez) that ARE NOT `TextResource`s and below (i.e are plain `BundleFile`s)
  # are copied to build.dstPath.
  copyNonResourceFiles: (filenames=@filenames)->
    if @changed.bundlefiles # need if ?

      if not _.isEmpty @copy then copyNonResFilenames = #save time
        _.filter filenames, (fn)=>
          not (@files[fn] instanceof FileResource) and
          @files[fn]?.hasChanged and # @todo: 5 2 1 only really changed (BundleFile reads timestamp/size etc)!
          (isFileInSpecs fn, @copy)

      if not _.isEmpty copyNonResFilenames
        l.debug """\n
          #####################################################################
          Copying #{copyNonResFilenames.length} non-resources files..."
          #####################################################################""" if l.deb 30
        copiedCount = skippedCount = 0
        for fn in copyNonResFilenames
          try
            if @files[fn].copy() # @todo: overwrite:"olderOrSizediff"
              copiedCount++
            else
              skippedCount++

            @files[fn].hasChanged = false
          catch err
            if not (@build.continue or @build.watch) then throw err

    [copiedCount, skippedCount]

  ###
  ###
  combine: (@build)->
    l.debug """\n
      #####################################################################
      'combined' template: optimizing with r.js
      #####################################################################""" if l.deb 30

    if not @main # set to name, or index.js, main.js @todo: & other sensible defaults ? NOTE: modules have to be refreshed 1st!
      for mainCand in [@name, 'index', 'main'] when mainCand and not mainModule
        mainModule = _.find @modules, (m)-> m.modulePath is mainCand
          
        if mainModule
          @main = mainModule.modulePath
          l.warn """
           combine() note: 'bundle.main', your *entry-point module* was missing from bundle config(s).
           It's defaulting to #{if @main is @name then 'bundle.name = ' else ''
           }'#{@main}', as uRequire found an existing '#{@path}/#{mainModule.filename}' module in your path.
          """

    if not @main
      l.err """
        Quiting cause 'bundle.main' is missing (after so much effort).
        No module found either as name = '#{@name}', nor as ['index', 'main'].
      """
      @build.done false
      return

    else
      # check no global dependency without a variable binding - quit otherwise
      globalDepsVars = @getDepsVars (dep)=>
        (dep.type is Dependency.TYPES.global) and
        (dep.pluginName isnt 'node') and
        (dep.name(plugin:false) not in @dependencies.node)

      if _.any(globalDepsVars, (v)-> _.isEmpty v) and false
        l.err """
          Some global dependencies are missing a variable binding:

          #{l.prettify _B.go globalDepsVars, fltr: (v)->_.isEmpty v}

          These variable names are used to grab the dependency from the global object, when running as <script>.
          Eg. 'jquery' corresponds to '$' or 'jQuery', hence it should be known as `jquery: ['$', 'jQuery']`

          Remedy:

          You should add it at uRequireConfig 'bundle.dependencies.depsVars' as:
            ```
              depsVars: {
                'myDep1': 'VARIABLE_IT_BINDS_WITH',
                'myDep2': ['VARIABLE_IT_BINDS_WITH', 'ANOTHER VARIABLE_IT_BINDS_WITH']
              }
            ```
          Alternativelly, pick one medicine :
            - define at least one module that has this dependency + variable binding (currently using AMD only) and uRequire will find it!
            - use an `rjs.shim`, and uRequire will pick it from there (@todo: NOT IMPLEMENTED YET!)
            - RTFM & let us know if still no remedy!
        """
        @changed.errors++ #lame - make it count the real errors !
        if not (@build.watch or @build.continue)
          @build.done false
          return
        else
          l.warn "Continuing from error due to @build.continue || @build.watch - not throwing:\n", uerr

      nodeOnly = _.keys @getDepsVars (dep)=>
        (dep.pluginName is 'node') or (dep.name(plugin:false) in @dependencies.node)

      almondTemplates = new AlmondOptimizationTemplate {
        globalDepsVars
        nodeOnly
        @main
      }

      for depfilename, genCode of almondTemplates.dependencyFiles
        TextResource.save upath.join(@build.dstPath, depfilename+'.js'), genCode

      @copyAlmondJs()
      @copyWebMapDeps()

      try #delete old combinedFile
        fs.unlinkSync @build.combinedFile
      catch err

      rjsConfig =
        paths: _.extend almondTemplates.paths, @getRequireJSConfig().paths

        wrap: almondTemplates.wrap
        baseUrl: @build.dstPath
        include: [@main]
        deps: nodeOnly # we include the 'fake' AMD files 'getNodeOnly_XXX' @todo: why 'rjs.deps' and not 'rjs.include' ?
        out: @build.combinedFile
  #      out: (text)=>
  #        #todo: @build.out it!
  #        l.verbose "uRequire: writting combinedFile '#{combinedFile}'."
  #        @save text, @combinedFile
  #        if fs.existsSync @combinedFile
  #          l.verbose "uRequire: combined file '#{combinedFile}' written successfully."
        name: 'almond'

      if rjsConfig.optimize = @build.optimize                # set if we have build:optimize: 'uglify2',
        rjsConfig[@build.optimize] = @build[@build.optimize] # copy { uglify2: {...uglify2 options...}}
      else
        rjsConfig.optimize = "none"

      rjsConfig.logLevel = 0 if l.deb 90

      # actually combine (r.js optimize)
      l.verbose "Optimize with r.js (v#{@requirejs.version}) with uRequire's 'build.js' = \n", _.omit(rjsConfig, ['wrap'])

      hasError = false # how lame is this - use promises next time!
      @requirejs.optimize _.clone(rjsConfig, true),
        (buildResponse)->
          l.verbose '@requirejs.optimize rjsConfig, (buildResponse)-> = ', buildResponse

        (errorResponse)->
          l.err '@requirejs.optimize errorResponse: ', errorResponse
          hasError = true
          build.done false

      setTimeout  (=>
        if not hasError
          l.debug(60, 'Checking r.js output file...')
          if fs.existsSync build.combinedFile
            l.verbose "Combined file '#{build.combinedFile}' written successfully."

            globalDepsVars = @getDepsVars (dep)->dep.depType is 'global'
            if not _.isEmpty globalDepsVars
              if (not build.watch and not build.verbose) or l.deb 30
                l.log "Global bindinds: make sure the following global dependencies:\n", globalDepsVars,
                  """\n
                  are available when combined script '#{build.combinedFile}' is running on:

                  a) nodejs: they should exist as a local `nodes_modules`.

                  b) Web/AMD: they should be declared as `rjs.paths` (or `rjs.baseUrl`)

                  c) Web/Script: the binded variables (eg '_' or '$')
                     must be a globally loaded (i.e `window.$`) BEFORE loading '#{build.combinedFile}'
                  """

            # delete dstPath, used as temp directory with individual AMD files
            if not (l.deb(debugLevelSkipTempDeletion) or build.watch)
              l.debug(40, "Deleting temporary directory '#{build.dstPath}'.")
              wrench.rmdirSyncRecursive build.dstPath
            else
              l.debug("NOT Deleting temporary directory '#{build.dstPath}', due to build.watch || debugLevel >= #{debugLevelSkipTempDeletion}.")
            build.done not @changed.errors
          else
            l.err """
            Combined file '#{build.combinedFile}' NOT written."

              Some remedy:

               a) Is your *bundle.main = '#{@main}'* or *bundle.name = '#{@name}'* properly defined ?
                  - 'main' should refer to your 'entry' module, that requires all other modules - if not defined, it defaults to 'name'.
                  - 'name' is what 'main' defaults to, if its a module.

               b) Perhaps you have a missing dependcency ?
                  r.js doesn't like this at all, but it wont tell you unless logLevel is set to error/trace, which then halts execution.

               c) Re-run uRequire with debugLevel >=90, to enable r.js's logLevel:0 (trace).
                  *Note this prevents uRequire from finishing properly / printing this message!*

               Note that you can check the AMD-ish files used in temporary directory '#{build.dstPath}'.

               More remedy on the way... till then, you can try running r.js optimizer your self, based on the following build.js: \u001b[0m

            """, rjsConfig

            build.done false
      ), 500

  getRequireJSConfig: -> {} #@todo:(7 5 2) HOW LAME - remove & fix this!
#      paths:
#        text: "requirejs_plugins/text"
#        json: "requirejs_plugins/json"


  copyAlmondJs: ->
    try # copy almond.js from GLOBAL/urequire/node_modules -> dstPath
      BundleFile.copy(
        "#{__dirname}/../../../node_modules/almond/almond.js" # from
        upath.join(@build.dstPath, 'almond.js')            # to
      )
    catch err
      l.err uerr = """
        uRequire: error copying almond.js from uRequire's installation node_modules - is it installed ?
        Tried: '#{__dirname}/../../../node_modules/almond/almond.js'
      """
      uerr = new UError uerr, nested:err
      if not (@build.continue or @build.watch)
        throw uerr
      else
        l.warn "Continuing from error due to @build.continue || @build.watch - not throwing:\n", uerr

  ###
   Copy all bundle's webMap dependencies to dstPath
   @todo: use path.join
   @todo: should copy dep.plugin & dep.resourceName separatelly
  ###
  copyWebMapDeps: ->
    webRootDeps = _.keys @getDepsVars (dep)->dep.depType is Dependency.TYPES.webRootMap
    if not _.isEmpty webRootDeps
      l.verbose "Copying webRoot deps :\n", webRootDeps
      for depName in webRootDeps
#        BundleFile.copy     "#{@webRoot}#{depName}",         #from
#                            "#{@build.dstPath}#{depName}" #to
        l.err "NOT IMPLEMENTED: copyWebMapDeps #{@webRoot}#{depName}, #{@build.dstPath}#{depName}"


  ###
  Gets dependencies & the variables (they bind with), througout this bundle.

  The information is gathered from all modules and joined together.

  Also it uses bundle.dependencies.depsVars, _knownDepsVars, exports.bundle & exports.root
  to discover var bindings, if some dep has no corresponding vars [].

  @param {Object} q optional query with 3 optional fields : depType, depName & pluginName

  @return {dependencies.depsVars} `dependency: ['var1', 'var2']` eg
              {
                  'underscore': ['_']
                  'jquery': ["$", "jQuery"]
                  'models/PersonModel': ['persons', 'personsModel']
              }

  ###
  getDepsVars: (depFltr)->
    depsVars = {}

    gatherDepsVars = (_depsVars)-> # add non-exixsting var to the dep's `vars` array
      for dep, vars of _depsVars
        dv = (depsVars[dep] or= [])
        dv.push v for v in vars when v not in dv

    # gather depsVars from all loaded resources
    gatherDepsVars uModule.getDepsVars depFltr for uMK, uModule of @modules

    # given a DepsVars object, it picks for existing depsVars,
    # that have no vars associated with them (yet).
    getMissingDeps = (fromDepsVars)=>
      _B.go fromDepsVars,
         fltr: (v,k)=>
            (depsVars[k] isnt undefined) and   # we have this dep
            _.isEmpty(depsVars[k])             # but no vars associated with this dep


    # picking from @bundle.dependencies. [depsVars, _KnownDepsVars, ... ] etc
    for dependenciesDepsVarsPath in _.map(
          ['depsVars', '_knownDepsVars',
          'exports.bundle', 'exports.root'], (v)-> 'dependencies.' + v)
      dependenciesDepsVars = _B.getp @, dependenciesDepsVarsPath, {separator:'.'}

      if not _.isEmpty vn = getMissingDeps dependenciesDepsVars
        l.warn "\n Picked from `@#{dependenciesDepsVarsPath}` for some deps with missing dep-variable bindings: \n", dependenciesDepsVars
        gatherDepsVars dependenciesDepsVars

    depsVars

module.exports = Bundle

