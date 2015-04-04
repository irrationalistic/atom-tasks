_ = require 'underscore'
Tag = require './tag'

PROJECT_RX = /(.*):$/g

marker = atom.config.get('tasks.taskMarker')
complete = atom.config.get('tasks.completeMarker')
cancelled = atom.config.get('tasks.cancelledMarker')

TASK_RX = new RegExp "(.*)(☐)"

ATTRIBUTE_RX = /(@[ ]?(([\w]+) ?(\((.*?)\))?))/gi

class Node
  constructor: (@raw, @indentation, @editor, @lineNum, @parent = null)->
    @projects = []
    @tasks = []
    @tags = []
    @line = @raw.trim()

  parseLine: ()->
    # parse the line of this node
    @type = 'text'
    @type = 'project' if PROJECT_RX.test @line
    @type = 'task' if TASK_RX.test @line

    # Create a marker to represent this line
    @lineMarker = @editor.markBufferPosition [@lineNum, 0]

    # parse any tags out
    while match = ATTRIBUTE_RX.exec @line
      nTag = new Tag match[3], match[5]
      @tags.push nTag

  addItem: (item)->
    item.parent = @
    item.parseLine()
    if item.type is 'project'
      @projects.push item
    else
      @tasks.push item

  addTag: (tagName, tagValue)->
    nTag = new Tag tagName, tagValue
    @tags.push nTag
    pos = @lineMarker.bufferMarker.range.start.copy()
    pos.column = @editor.buffer.lineLengthForRow pos.row
    # update the buffer test
    @editor.buffer.insert pos, " #{nTag.toString()}"

  getLineNumber: ()->
    return -1 if not @lineMarker
    @lineMarker.bufferMarker.range.start.row

  findElementsByRange: (range, rows = null)->
    if not rows
      rows = range.reduce ((t, i)-> i.getRows()), []

    # add to matches if this is such,
    # but also check all child projects
    # and tasks

    # console.log @, @getLineNumber(), @getLineNumber() in rows
    # console.log @projects.concat @tasks

    _.chain(@projects.concat @tasks
      .map (i)-> i.findElementsByRange range, rows
      .concat [@ if @getLineNumber() in rows]
    )
      .flatten()
      .compact()
      .value()




module.exports = Node
