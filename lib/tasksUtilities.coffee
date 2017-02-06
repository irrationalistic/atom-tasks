{Point, Range} = require 'atom'
_ = require 'underscore'
moment = require 'moment'

# ATTRIBUTE_RX = /( ?)(@[ ]?(([\w]+)(\((.*?)\))?))/gi

module.exports =

  markerSelector: 'keyword.tasks.marker'
  doneSelector: 'tasks.text.done.source.gfm'
  cancelledSelector: 'tasks.text.cancelled.source.gfm'
  archiveSelector: 'control.tasks.header.archive'
  headerSelector: 'control.tasks.header-title'

    # Escape a string
  cleanRegex: (str)->
    for pat in ['\\', '/', '[', ']', '*', '.', '+', '(', ')']
      str = str.replace pat, '\\' + pat
    str

  parseLine: (editor, lineNumber, config) ->
    whiteRx = /^\s*/
    projectRx = /^\s*(.*):$/
    baseMarker = @cleanRegex config.baseMarker
    completeMarker = @cleanRegex config.completeMarker
    cancelledMarker = @cleanRegex config.cancelledMarker
    taskRx = new RegExp "^(\\s*)(#{baseMarker}|#{completeMarker}|#{cancelledMarker})(.*)$"

    line = editor.buffer.lineForRow lineNumber
    indentation = editor.indentationForBufferRow lineNumber

    result =
      lineNumber: lineNumber
      line: line
      indentation: indentation
      firstNonWhitespaceIndex: line.match(whiteRx)[0].length

    type = 'text'
    if projectRx.test line
      type = 'project'
      match = line.match projectRx
      result.project = match[1]

    else if taskRx.test line
      type = 'task'
      match = line.match taskRx
      result.marker =
        value: match[2]
        range: new Range new Point(lineNumber, match[1].length), new Point(lineNumber, match[1].length + match[2].length)
      result.text = match[3].trim()
      result.tags = @getAllTags editor, lineNumber, config.attributeMarker

    result.type = type
    return result

  ###*
   * Get all the tags on a given line
   * @param {TextEditor} editor  Editor to use
   * @param {Number} lineNumber  Number of line
  ###
  getAllTags: (editor, lineNumber, attributeMarker)->
    tags = []
    # lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    # checkLine = lines[lineNumber]
    checkLine = editor.buffer.lineForRow lineNumber
    attributeRX = new RegExp "( ?)(\\#{attributeMarker}[ ]?(([\\w]+)(\\((.*?)\\))?))", 'gi'
    while match = attributeRX.exec checkLine
      sPt = new Point lineNumber, match.index
      ePt = new Point lineNumber, match.index + match[0].length


      nameStart = new Point(
        lineNumber,
        match.index + match[0].indexOf match[4]
      )
      nameEnd = new Point(
        lineNumber,
        match.index + match[0].indexOf(match[4]) + match[4].length
      )
      if match[6]
        valueStart = new Point(
          lineNumber,
          match.index + match[0].indexOf match[6]
        )
        valueEnd = new Point(
          lineNumber,
          match.index + match[0].indexOf(match[6]) + match[6].length
        )

      tags.push
        tagName:
          value: match[4]
          range: new Range nameStart, nameEnd
        tagValue:
          value: match[6]
          range: new Range valueStart, valueEnd
        range: new Range sPt, ePt

    tags


  ###*
   * Get a specific tag from the given line
   * @param {TextEditor} editor      Editor to use
   * @param {Number} lineNumber      Line number to use
   * @param {String} tagName         Tag to find
   * @param {String} attributeMarker Marker character in use
    ###
  getTag: (editor, lineNumber, tagName, attributeMarker)->
    tags = @getAllTags editor, lineNumber, attributeMarker
    _.find tags, (t)->t.tagName.value is tagName



  ###*
   * Helper for adding a tag/value to a given line
   * @param {TextEditor} editor      Editor to use
   * @param {Number} lineNumber      Line number to use
   * @param {String} attributeMarker Marker being used for attributes
   * @param {String} tagName         Name of tag
   * @param {String} tagValue        Value of tag (optional)
  ###
  addTag: (editor, lineNumber, attributeMarker, tagName, tagValue)->
    point = new Point lineNumber, editor.buffer.lineLengthForRow lineNumber
    if tagValue
      editor.buffer.insert point, " #{attributeMarker}#{tagName}(#{tagValue})"
    else
      editor.buffer.insert point, " #{attributeMarker}#{tagName}"



  ###*
   * Helper for removing a tag by name
   * @param {TextEditor} editor      Editor to use
   * @param {Number} lineNumber      Line number to remove from
   * @param {String} tagName         Tag name to remove
   * @param {String} attributeMarker Marker character in use
  ###
  removeTag: (editor, info, tagName)->
    match = _.find info.tags, (i)->i.tagName.value is tagName
    editor.buffer.delete match.range if match


  ###*
   * Helper for updating the value of a tag
   * @param {TextEditor} editor      Editor to use
   * @param {Number} lineNumber      Line number to update on
   * @param {String} attributeMarker Marker character in use
   * @param {String} tagName         Tag name to update value of
   * @param {String} newTagValue     New value of tag (optional).
   *                                 Leave undefined to remove value
  ###
  updateTag: (editor, info, attributeMarker, tagName, newTagValue)->
    tag = _.find info.tags, (t) -> t.tagName.value is tagName
    return if not tag
    if newTagValue
      if tag.tagValue.range.isEmpty()
        pt = tag.tagName.range.end
        editor.buffer.insert pt, "(#{newTagValue})"
      else
        editor.buffer.setTextInRange tag.tagValue.range, newTagValue
    else
      if not tag.tagValue.range.isEmpty()
        tag.tagValue.range.start.column--
        tag.tagValue.range.end.column++
        editor.buffer.delete tag.tagValue.range


  ###*
   * Find the token on the line given a css-like selector
   * @param {Array} tokens    Array of tokens to look through
   * @param {String} selector CSS-like selector to search for
  ###
  getToken: (tokens, selector)->
    for token in tokens
      return token if selector in token.scopes
    null




  ###*
   * Given a token search string, find all
   * lines in the given editor that match
   * @param {TextEditor} editor Editor to use
   * @param {String} toFind     CSS-like selector to search for
  ###
  getLinesByToken: (editor, toFind)->
    editor.tokenizedBuffer.tokenizedLines.filter (i)=>
      @getToken i.tokens, toFind



  ###*
   * Helper for finding all parent nodes of this line
   * that are projects
   * @param {TextEditor} editor   Editor to use
   * @param {Number} lineNumber   Line number to start at
  ###
  getProjects: (editor, lineNumber)->
    lines = editor.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    projects = []
    curHeaderLevel = editor.indentationForBufferRow(lineNumber)
    return projects if lineNumber is 0
    for row in [lineNumber-1..0]
      curLine = lines[row]
      if editor.indentationForBufferRow(row) < curHeaderLevel
        if @getToken curLine.tokens, @headerSelector
          projects.push curLine
          curHeaderLevel = editor.indentationForBufferRow(row)

        rowIsZero = editor.indentationForBufferRow(row) is 0
        rowIsEmpty = editor.isBufferRowBlank(row)
          
        break if rowIsZero and not rowIsEmpty
    projects


  ###*
   * Given a project line, parse out just the name
   * @param {TokenizedLine} line TokenizedLine to parse
  ###
  parseProjectName: (line)->
    match = @getToken line.tokens, @headerSelector
    match.value



  ###*
   * Helper for getting the rows of a selection,
   * which can be made up of an array of ranges.
   * @param {Array} selection Array of ranges
  ###
  getAllSelectionRows: (selection)->
    _.flatten selection.map (s)->s.getRows()


  ###*
   * Helper for getting the date based on given settings
   * @return {Date/String} Date or date string to use
  ###
  getFormattedDate: (date = Date.now())->
    moment(date).format(atom.config.get('tasks.dateFormat'))



  ###*
   * Helper for setting the marker of a given line
   * @param {TextEditor} editor   Editor to use
   * @param {Number} lineNumber   Line number to use
   * @param {String} markerText   New marker to set
  ###
  setMarker: (editor, info, markerText)->
    # given some line, change the marker
    # if it exists, or add one if it doesn't

    if info.marker
      editor.buffer.setTextInRange info.marker.range, markerText

    else
      # need to insert the marker
      pt = new Point info.lineNumber, info.firstNonWhitespaceIndex
      editor.buffer.insert pt, markerText + ' '
