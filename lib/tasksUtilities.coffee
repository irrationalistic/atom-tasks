{Point, Range} = require 'atom'
_ = require 'underscore'
moment = require 'moment'

ATTRIBUTE_RX = /( ?)(@[ ]?(([\w]+)(\((.*?)\))?))/gi

module.exports =

  markerSelector: 'keyword.tasks.marker'
  doneSelector: 'tasks.text.done'
  cancelledSelector: 'tasks.text.cancelled'
  archiveSelector: 'control.tasks.header.archive'
  headerSelector: 'control.tasks.header-title'

  getAllTags: (editor, lineNumber)->
    tags = []
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    while match = ATTRIBUTE_RX.exec checkLine.text
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

  getTag: (editor, lineNumber, tagName)->
    tags = @getAllTags editor, lineNumber
    _.find tags, (t)->t.tagName.value is tagName

  addTag: (editor, lineNumber, tagName, tagValue)->
    point = new Point lineNumber, editor.buffer.lineLengthForRow lineNumber
    editor.buffer.insert point, " @#{tagName}(#{tagValue})"

  removeTag: (editor, lineNumber, tagName)->
    # get the range of the tag,
    # then remove it
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    tags = @getAllTags editor, lineNumber
    return if not tags

    match = _.find tags, (i)->i.tagName.value is tagName
    editor.buffer.delete match.range if match

  updateTag: (editor, lineNumber, tagName, newTagValue)->
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    tag = @getTag editor, lineNumber, tagName
    editor.buffer.setTextInRange tag.tagValue.range, newTagValue

  getToken: (tokens, selector)->
    for token in tokens
      return token if selector in token.scopes
    null

  getLinesByToken: (editor, toFind)->
    editor.displayBuffer.tokenizedBuffer.tokenizedLines.filter (i)=>
      @getToken i.tokens, toFind

  getProjects: (editor, lineNumber)->
    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]
    projects = []
    return projects if lineNumber is 0
    for row in [lineNumber-1..0]
      curLine = lines[row]
      if curLine.indentLevel < checkLine.indentLevel
        if @getToken curLine.tokens, @headerSelector
          projects.push curLine
        break if curLine.indentLevel is 0
    projects

  parseProjectName: (line)->
    match = @getToken line.tokens, @headerSelector
    match.value

  getAllSelectionRows: (selection)->
    _.flatten selection.map (s)->s.getRows()

  getFormattedDate: (date = Date.now())->
    moment(date).format(atom.config.get('tasks.dateFormat'))

  setMarker: (editor, lineNumber, markerText)->
    # given some line, change the marker
    # if it exists, or add one if it doesn't

    lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
    checkLine = lines[lineNumber]

    marker = @getToken checkLine.tokens, @markerSelector

    if marker
      # already a marker, swap it
      startCol = checkLine.bufferColumnForToken marker
      range = new Range new Point(lineNumber, startCol),
        new Point(lineNumber, startCol + 1)

      editor.buffer.setTextInRange range, markerText

    else
      # need to insert the marker
      pt = new Point lineNumber, checkLine.firstNonWhitespaceIndex
      editor.buffer.insert pt, markerText + ' '
