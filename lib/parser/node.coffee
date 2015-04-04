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
      @addTag match[3], match[5]

  addItem: (item)->
    item.parent = @
    item.parseLine()
    if item.type is 'project'
      @projects.push item
    else
      @tasks.push item

  addTag: (tagName, tagValue)->
    @tags.push new Tag tagName, tagValue


module.exports = Node
