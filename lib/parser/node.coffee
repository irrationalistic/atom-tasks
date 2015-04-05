_ = require 'underscore'
moment = require 'moment'
Tag = require './tag'
{Range, Point} = require 'atom'

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

    @marker.destroy() if @marker
    sPt = new Point @lineNum, 0
    ePt = new Point @lineNum, @editor.buffer.lineLengthForRow @lineNum
    @marker = @editor.buffer.markRange new Range sPt, ePt
    @marker.onDidChange (e)=>
      # TODO: refactor this
      @raw = @editor.buffer.getTextInRange @marker.getRange()
      @line = @raw.trim()
      @parseLine()

    # parse any tags out
    if @tags
      @tags.map (i)->i.destroy()
      @tags = []
    while match = ATTRIBUTE_RX.exec @raw
      nTag = new Tag @editor, match[3], match[5]
      sPt = new Point @lineNum, match.index
      ePt = new Point @lineNum, match.index + match[0].length
      nTag.markRange new Range sPt, ePt
      # console.log 'marking:', nTag, sPt, ePt
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
    pos = @marker.bufferMarker.range.start.copy()
    pos.column = @editor.buffer.lineLengthForRow pos.row
    # update the buffer test
    @editor.buffer.insert pos, " #{nTag.toString()}"

  removeTag: (tagName)->
    @tags = @tags.filter (i)->
      if i.name is tagName
        i.remove()
        return false
      true

  getLineNumber: ()->
    return -1 if not @marker
    @marker.bufferMarker.range.start.row

  findNodesByRange: (range, rows = null)->
    if not rows
      rows = range.reduce ((t, i)-> i.getRows()), []

    _.chain(@projects.concat @tasks
      .map (i)-> i.findNodesByRange range, rows
      .concat [@ if @getLineNumber() in rows]
    )
      .flatten()
      .compact()
      .value()

  getProjectParents: ()->
    results = []
    cur = @
    while cur = cur.parent
      results.push cur if cur.type is 'project'
    results

  # HELPERS
  complete: ()->
    @editor.transact =>
      if _.any(@tags, (i)->i.name is 'done')
        # already done, so remove
        @removeTag 'done'
        @removeTag 'project'
      else
        @addTag 'done', moment().format(atom.config.get('tasks.dateFormat'))
        @addTag 'project', _.pluck(@getProjectParents(), 'line').join ' / '

module.exports = Node
