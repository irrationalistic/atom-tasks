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


  ###*
   * Get all the tags on a given line
   * @param {TextEditor} editor  Editor to use
   * @param {Number} lineNumber  Number of line
  ###
  getAllTags: (editor, lineNumber, attributeMarker)->
    tags = []
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    attributeRX = new RegExp "( ?)(\\#{attributeMarker}[ ]?(([\\w]+)(\\((.*?)\\))?))", 'gi'
    while match = attributeRX.exec checkLine.text
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
  removeTag: (editor, lineNumber, tagName, attributeMarker)->
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    tags = @getAllTags editor, lineNumber, attributeMarker
    return if not tags

    match = _.find tags, (i)->i.tagName.value is tagName
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
  updateTag: (editor, lineNumber, attributeMarker, tagName, newTagValue)->
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    tag = @getTag editor, lineNumber, tagName, attributeMarker
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
    editor.displayBuffer.tokenizedBuffer.tokenizedLines.filter (i)=>
      @getToken i.tokens, toFind



  ###*
   * Helper for finding all parent nodes of this line
   * that are projects
   * @param {TextEditor} editor   Editor to use
   * @param {Number} lineNumber   Line number to start at
  ###
  getProjects: (editor, lineNumber)->
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    projects = []
    curHeaderLevel = checkLine.indentLevel
    return projects if lineNumber is 0
    for row in [lineNumber-1..0]
      curLine = lines[row]
      if curLine.indentLevel < curHeaderLevel
        if @getToken curLine.tokens, @headerSelector
          projects.push curLine
          curHeaderLevel = curLine.indentLevel
        break if curLine.indentLevel is 0
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
  setMarker: (editor, lineNumber, markerText)->
    # given some line, change the marker
    # if it exists, or add one if it doesn't

    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]

    marker = @getToken checkLine.tokens, @markerSelector

    if marker
      # already a marker, swap it
      # startCol = checkLine.bufferColumnForToken marker
      # bufferColumnForToken was removed, this is a replacement
      startCol = 0
      for token in checkLine.tokens
        break if token.value is marker.value
        startCol += token.bufferDelta

      range = new Range new Point(lineNumber, startCol),
        new Point(lineNumber, startCol + marker.value.length)

      editor.buffer.setTextInRange range, markerText

    else
      # need to insert the marker
      pt = new Point lineNumber, checkLine.firstNonWhitespaceIndex
      editor.buffer.insert pt, markerText + ' '
