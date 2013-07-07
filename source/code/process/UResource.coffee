# externals
_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'
l = new _B.Logger 'urequire/UResource'

# uRequire
ModuleGeneratorTemplates = require '../templates/ModuleGeneratorTemplates'
ModuleManipulator = require "../moduleManipulation/ModuleManipulator"
Dependency = require "../Dependency"
BundleFile = require './BundleFile'
UError = require '../utils/UError'


###
  Represents any *textual* resource (including but not limited to js-convertable code).

  Each time it `@refresh()`es,
    if `@source` (content) in file is changed, its passed through all @converters:
    - stores .convert(@source) result as @converted
    - stores .dstFilename(@filname) result as @dstFilename
###
class UResource extends BundleFile
  Function::property = (p)-> Object.defineProperty @::, n, d for n, d of p ;null

  ###
  @param {Object} bundle The Bundle where this URersource belongs
  @param {String} filename, bundleRelative eg 'models/PersonModel.coffee'
  @param {Array<?>} converters The converters (bundle.resources) that matched this filename & are used in turn to convert, each time we `refresh()`
  ###
  constructor: (@bundle, @filename, @converters)-> super

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and convert it passing throught all @converters

    @return true if there was a change (and convertions took place) and note as @hasChanged
            false otherwise
  ###
  refresh: ->
    if not super
      return false # no change in parent, why should I change ?

    else #refresh only if parent says so
      source = undefined
      try
        source = fs.readFileSync @srcFilepath, 'utf-8'
      catch err
        @hasErrors = true
        throw new UError "Error reading file '#{@srcFilepath}'", nested:err

      if source and (@source isnt source)
        # go through all converters, converting source & filename in turn
        @source = @converted = source
        @dstFilename = @filename

        return @hasChanged = @runResourceConverters (conv)->not conv.isAfterTemplate
      else
        l.debug "No changes in source of resource '#{@filename}' " if l.deb 90
        return @hasChanged = false

  # go through all converters, converting with each one
  # Note: it acts on @converted & @dstFlename, leaving them in a new state
  runResourceConverters: (convFilter=->true) ->
    try
      for converter in @converters when convFilter converter

        # convert source (i.e the previous @converted from convert(), intially its source)
        if _.isFunction converter.convert
          l.debug "Converting '#{@dstFilename}' with '#{converter.name}'..." if l.deb 60
          @converted = converter.convert @converted, @dstFilename

        #convert Filename
        if _.isFunction converter.dstFilename
          @dstFilename = converter.dstFilename @dstFilename
          l.debug "...resource.dstFilename is '#{@dstFilename}'" if l.deb 95

      @hasErrors = false
      return @hasChanged = true
    catch err
      @hasErrors = true
      l.err uerr = "Error converting '#{@filename}' with converter '#{converter?.name}'."
      throw new UError uerr, nested:err

  reset:-> super; delete @source; delete @converted

module.exports = UResource

### Debug information ###
#if l.deb >= 90
#  YADC = require('YouAreDaChef').YouAreDaChef
#
#  YADC(UModule)
#    .before /_constructor/, (match, bundle, filename)->
#      l.debug("Before '#{match}' with filename = '#{filename}'")


