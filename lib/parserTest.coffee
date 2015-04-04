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


###

IMPORTANT CONSIDERATIONS:

- Speed optimization for large files
- How are buffers handled / watched
- Managing data that doesn't necessarily sync directly.
    For instance, if I add a tag, it will also need to put
    it into the output, which would probably be the end. But
    what if I change the value or name of a tag? It may need
    to keep track of the buffer points it came from...
    Maybe it creates a special template string that uses
    custom id fields to connect parts of the string to the
    tags stored in the array?
- Writing changes back should also be optimized. When
    changing a single item, that's the only modifications
    that should be written. When adding a new task, the contents
    should move around to fit, but it will need to carefully watch
    the buffer for any changes so that it can remain up-to-date
    and not need to re-parse every change and action.


IMPORTANT DOCUMENTATION:
  - https://atom.io/docs/api/v0.189.0/TextBuffer#instance-setTextViaDiff
  - https://atom.io/docs/api/v0.189.0/TextBuffer#instance-markRange
  - https://atom.io/docs/api/v0.189.0/TextEditor#instance-markBufferRange
  - https://atom.io/docs/api/v0.189.0/TextBuffer#instance-markPosition
  - https://atom.io/docs/api/v0.189.0/TextBuffer#instance-findMarkers
  - https://atom.io/docs/api/v0.189.0/Marker
  - https://atom.io/docs/api/v0.189.0/TextBuffer#instance-setTextInRange
  - https://atom.io/docs/api/v0.189.0/TextEditor#instance-indentationForBufferRow

###




testContent = """
☐ Chrome notifications
Roadmap v2:
  ☐ Show player @tag1 and @test(value)
  ☐ Click to toggle enter-send vs cmd+enter -send
  plain text
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

{parse} = require './parser'



setTimeout ->
  console.time 'parsingLight'
  results = parse testContent
  console.timeEnd 'parsingLight'
  console.log results

  # console.time 'parsingHeavy'
  # results = parser complexContent
  # console.timeEnd 'parsingHeavy'
  # console.log results
, 5000
