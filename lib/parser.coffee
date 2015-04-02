###
  Todo Parser:

  TODO: Building a language parser

  Question: How does this differ from the existing parsing, which
            is technically already happening? It has to parse the
            file to style it, then re-parse the same file every
            time the user peforms an action? Seems pretty inefficient.
            Unless! All it does is piggy-back on the actual style parser
            by reading each line and building an object representation
            of the dom? Though DOM manipulation is still slower anyways.

  THOUGHTS:
    - want to optimize speed, so that performing actions are fast, no
      matter how much space they span.
    - DOM manipulations are slow:
      - adding/removing tags
      - swapping marker
      - converting tasks

  - Want to attach it to be publicly available
    Think in terms of supporting plugins like the timeclock.
  - Also think about how this will be used, especially in terms
    of things like adding a task, completing a task, cancelling
    a task, adding different tags, conversion, etc. Listed out below...
  - Should be able to parse any selection to gather information
    This could cause issues when trying to figure out what
    project something is in, or if it is a subtask, etc
  - From the information, should be able to convert non-task items,
    discern proper indentation, toggle state, detect archiveable tasks.
  - Should improve support for 3rd party plugins (like the time system)
  - Able to detect total number of primary items and sub items in a project
  - Better support for sub-projects and sub-tasks
  - Support for project-less tasks
  - Connection to status bar
  - How is this going to be optimized? If it has to read the entire file
    contents into memory each time an action occurs, seems pretty heavy.
    Might need some stress testing.

  [{
    type: 'project',
    raw: 'My Project:',
    name: 'My Project',
    completed: 3,
    total: 10,
    tasks: [{
      type: 'task',
      raw: '  ☐ A sample task @tag1 and something else @tag2',
      buffer: {start: ..., end: ...},
      indentation: '  ',
      content: 'A sample task @tag1(testing) and something else @tag2',
      tags: [{
        key: 'tag1',
        value: 'testing'
      },{
        key: 'tag2'
      }],
      tasks: [{...}]
    }],
    projects: [{...}]
  },{
    type: 'archive',
    tasks: [{...}]
  }]


  FEATURES:
    - Projects
    - Nested projects
    - Adding a task (above, below, to a project, to a task)
    - Adding tags to a task (done, cancelled, project)
      - Also supporting random tags for external plugins
    - Using the dynamic grammar to allow custom task markers
    - Archiving tasks with certain tags (done, cancelled)
###

class Node
  constructor: (@line, @indentation, @parent = null)->
    @items = []

  addItem: (item)->
    @items.push item
    item.parent = @

tl = atom.config.get 'editor.tabLength'
getIndentationForLine = (line)->
  indent = /(\s)*/.exec(line)
  return 0 if !indent or !indent[0]
  indent[0].length / tl



testContent = """
☐ Chrome notifications
Roadmap v2:
  ☐ Show player (and teller, somewhere, avatars) @test(value)
  ☐ Click to toggle enter-send vs cmd+enter -send
  ☐ Can archive convos
Roadmap v3:
  ☐ Multi-user stories
  ☐ A new task @cancelled(2015-02-14 21:04) @project(Roadmap v3)
    ☐ Another new task
"""

pad = (length)->
  str = ''
  while (str.length < length)
    str = " " + str
  str

complexContent = ""

indent = 0
indentV = ""
for i in [0..10000]
  indentV = pad indent
  complexContent += "#{indentV}☐ test #{i}\n"
  indent+=2 if Math.random() > 0.5
  indent-=2 if Math.random() > 0.5
  indent = 0 if indent < 0
###

There will be two cursors. One will represent the parent
item, where all new items will be added, and the other
will represent the last node that was created. That way,
if child nodes are encountered, the parent cursor can
be properly set.

As the cursors move through the system, try to use up
as little memory and callstack as possible.

###

parseContent = (lines, node, indentation = 0)->
  parentCursor = node
  lastCursor = node

  for line, i in lines
    # need to check if the indentation of the currently reading line
    # is one greater than the parent's indentation.

    lineIndent = getIndentationForLine line
    tempNode = new Node line, lineIndent


    if lineIndent > parentCursor.indentation + 1
      # parseContent lines.slice(i), lastCursor
      parentCursor = lastCursor
    if lineIndent <= parentCursor.indentation
      parentCursor = parentCursor.parent
    #	return
    # console.log parentCursor, lineIndent, parentCursor.indentation
    if lineIndent is parentCursor.indentation + 1
      # add as child
      parentCursor.addItem tempNode
      # console.log "Adding #{tempNode.line} to #{parentCursor.line}"
    lastCursor = tempNode


parser = (content)->
  # given some text in the proper format, let's parse it
  rootNode = new Node 'rootNode', -1

  lines = content.split '\n'
  parseContent lines, rootNode

  rootNode


module.exports = parser




setTimeout ->
  console.time 'parsingLight'
  results = parser testContent
  console.timeEnd 'parsingLight'

  console.log results

  console.time 'parsingHeavy'
  results = parser complexContent
  console.timeEnd 'parsingHeavy'

  console.log results
, 5000
