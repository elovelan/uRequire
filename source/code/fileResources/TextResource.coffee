# externals
_ = require 'lodash'
_B = require 'uberscore'
l = new _B.Logger 'urequire/fileResources/TextResource'

# uRequire
FileResource = require './FileResource'
UError = require '../utils/UError'

###
  Represents a FileResource that is any *textual/utf-8* resource (including but not limited to js-convertable code).

  It knows how to `refresh()` its `source` and `reset` it:

  Each time it `@refresh()`es, if parent & `@source` (content) in source file is changed, its passed through all @converters.
###
class TextResource extends FileResource

  ###
    Check if source (AS IS eg js, coffee, LESS etc) has changed
    and if it has, then convert it passing throught all @converters

    @return true if there was a change (and conversions took place) and note as @hasChanged, false otherwise
  ###
  refresh: ->
    if not super
      return false # no change in parent, why should I change ?

    else # refresh only if parent says so
      source = @read()
      if source and (@source isnt source)
        # go through all converters, converting source & filename in turn
        @source = @converted = source
        @dstFilename = @filename # @todo: why init?

        return @hasChanged = @runResourceConverters (conv)->not conv.isAfterTemplate # only 'isAfterTemplate:false' aren't a module converted with template
      else
        l.debug "No changes in `source` of TextResource/#{@constructor.name} '#{@filename}' " if l.deb 90
        return @hasChanged = false

  reset:-> super; delete @source

module.exports = TextResource

