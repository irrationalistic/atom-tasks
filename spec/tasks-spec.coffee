Tasks = require '../lib/tasks'
tasksUtilities = require '../lib/tasksUtilities'
[editor, buffer, workspaceElement] = []

find = (selector)->
  workspaceElement.querySelectorAll "body /deep/ #{selector}"

describe 'Tasks', ->
###
  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('sample.todo').then (o) -> editor = o
    runs ->
      buffer = editor.getBuffer()
    waitsForPromise ->
      atom.packages.activatePackage('language-gfm')
      atom.packages.activatePackage('tasks')
    runs ->
      workspaceElement = atom.views.getView atom.workspace
      jasmine.attachToDOM workspaceElement

  describe 'grammar should load', ->
    it 'loads', ->
      grammar = atom.grammars.grammarForScopeName 'source.todo'
      expect(grammar).toBeDefined()
      expect(grammar.scopeName).toBe 'source.todo'

  describe 'should syntax highlight a todo file', ->
    it 'adds .marker to the markers', ->
      expect(find('.marker').length).toBe 3

    it 'adds .attribute to @tags', ->
      expect(find('.attribute').length).toBe 7

    it 'adds .text to plain text', ->
      expect(find('.text').length).toBe 3

    it 'supports markdown in plain text', ->
      expect(find('.bold').length).toBe 1
      expect(find('.italic').length).toBe 1
      expect(find('.link').length).toBe 2

  describe 'should be able to add new tasks', ->
    it 'adds a new task', ->
      Tasks.newTask()
      editor.insertText 'Todo Item from tests'
      line = editor.displayBuffer.tokenizedBuffer.tokenizedLines[1]
      expect(find('.marker').length).toBe 4
      expect(line.indentLevel).toBe 1

    it 'adds a new task above', ->
      Tasks.newTask(-1)
      editor.insertText 'Todo Item from tests'
      line = editor.displayBuffer.tokenizedBuffer.tokenizedLines[1]
      expect(find('.marker').length).toBe 4
      expect(line.indentLevel).toBe 0

  describe 'should be able to complete tasks', ->
    it 'completes a task', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      doneTasks = tasksUtilities.getLinesByToken editor,
        'tasks.text.done.source.gfm'
      projectTasks = tasksUtilities.getLinesByToken editor,
        'tasks.attribute.project'

      expect(doneTasks.length).toBe 2
      expect(projectTasks.length).toBe 3

  describe 'should be able to cancel tasks', ->
    it 'cancels a task', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.cancelTask()
      cancelled = tasksUtilities.getLinesByToken editor,
        'tasks.text.cancelled.source.gfm'
      projectTasks = tasksUtilities.getLinesByToken editor,
        'tasks.attribute.project'

      expect(cancelled.length).toBe 2
      expect(projectTasks.length).toBe 3

  describe 'should be able to set/update timestamps', ->
    it 'adds a timestamp', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.setTimestamp()
      timestampTag = tasksUtilities.getTag editor, 1, 'timestamp', '@'
      expect(timestampTag).toBeDefined()

    it 'should update a timestamp', ->
      curDate = tasksUtilities.getFormattedDate()
      editor.setCursorBufferPosition [2,0]
      Tasks.setTimestamp()
      doneTag = tasksUtilities.getTag editor, 2, 'done', '@'
      expect(doneTag.tagValue.value).toBe(curDate)

  describe 'should be able to archive completed tasks', ->
    it 'creates an archive section', ->
      preText = editor.getText()
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      Tasks.tasksArchive()

      archive = tasksUtilities.getLinesByToken editor,
        'tasks.header.archive'
      expect(archive).toBeDefined()

    it 'moves completed tasks', ->
      preText = editor.getText()
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      Tasks.tasksArchive()

      lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
      line = lines[lines.length - 3]
      hasCancelled = tasksUtilities.getToken line.tokens, 'tasks.text.done'

      expect(hasCancelled).toBeDefined()

    it 'moves cancelled tasks', ->
      preText = editor.getText()
      editor.setCursorBufferPosition [1,0]
      Tasks.cancelTask()
      Tasks.tasksArchive()

      lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines
      line = lines[lines.length - 2]
      hasCancelled = tasksUtilities.getToken line.tokens, 'tasks.text.cancelled'

      expect(hasCancelled).toBeDefined()

  describe 'helper methods should work', ->
    it 'can add a tag with or without a value', ->
      editor.setCursorBufferPosition [1,0]
      lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines

      tasksUtilities.addTag editor, 1, '@', 'noval'

      line = lines[1]
      hasTag = tasksUtilities.getToken line.tokens, 'tasks.attribute.noval'
      expect(hasTag).toBeDefined()

      tasksUtilities.addTag editor, 1, '@', 'hasval', 'myvalue'

      line = lines[1]
      hasTag = tasksUtilities.getToken line.tokens, 'tasks.attribute.hasval'
      expect(hasTag).toBeDefined()

    it 'can update tag values', ->
      editor.setCursorBufferPosition [1,0]
      lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines

      tasksUtilities.addTag editor, 1, '@', 'original'

      line = lines[1]
      hasTag = tasksUtilities.getToken line.tokens, 'tasks.attribute.original'
      expect(hasTag).toBeDefined()

      tasksUtilities.updateTag editor, 1, '@', 'original', 'newval'
      line = lines[1]
      hasTag = tasksUtilities.getToken line.tokens, 'tasks.attribute-value'
      expect(hasTag).toBeDefined()

      tasksUtilities.updateTag editor, 1, '@', 'original'
      line = lines[1]
      hasTag = tasksUtilities.getToken line.tokens, 'tasks.attribute-value'
      expect(hasTag).toBeNull()

    it 'supports custom attribute markers', ->
      atom.config.set 'tasks.attributeMarker', '#'
      editor.setText '☐ Test'
      tasksUtilities.addTag editor, 0, '#', 'test'

      lines = editor.displayBuffer.tokenizedBuffer.tokenizedLines

      hasTag = tasksUtilities.getToken lines[0].tokens, 'tasks.attribute.test'
      expect(hasTag).toBeDefined()


describe 'Taskpaper', ->

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('sample.taskpaper').then (o) -> editor = o
    runs ->
      buffer = editor.getBuffer()
    waitsForPromise ->
      atom.packages.activatePackage('tasks')
    runs ->
      atom.config.set 'tasks.baseMarker', '-'
      atom.config.set 'tasks.completeMarker', '-'
      atom.config.set 'tasks.cancelledMarker', '-'
      workspaceElement = atom.views.getView atom.workspace
      jasmine.attachToDOM workspaceElement

  describe 'should syntax highlight a taskpaper file', ->
    it 'adds .marker to the markers', ->
      expect(find('.marker').length).toBe 6

    it 'adds .attribute to @tags', ->
      expect(find('.attribute').length).toBe 2

    it 'adds .text to plain text', ->
      expect(find('.text').length).toBe 6

  describe 'should support the same marker for base, done, and cancelled', ->
    it 'can complete a task', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()

      doneTasks = tasksUtilities.getLinesByToken editor,
        'tasks.text.done.source.gfm'
      projectTasks = tasksUtilities.getLinesByToken editor,
        'tasks.attribute.project'

      expect(doneTasks.length).toBe 1
      expect(projectTasks.length).toBe 1

describe 'Complex Markers', ->

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('complexMarkers.todo').then (o) -> editor = o
    runs ->
      buffer = editor.getBuffer()
    waitsForPromise ->
      atom.packages.activatePackage('tasks')
    runs ->
      atom.config.set 'tasks.baseMarker', '[ ]'
      atom.config.set 'tasks.completeMarker', '[x]'
      atom.config.set 'tasks.cancelledMarker', '[-]'
      workspaceElement = atom.views.getView atom.workspace
      jasmine.attachToDOM workspaceElement

  describe 'should syntax highlight a complex marker file', ->
    it 'adds .marker to the markers', ->
      expect(find('.marker').length).toBe 3

    it 'adds .attribute to @tags', ->
      expect(find('.attribute').length).toBe 1

    it 'adds .text to plain text', ->
      expect(find('.text').length).toBe 3

  describe 'should support the same marker for base, done, and cancelled', ->
    it 'can complete a task', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()

      doneTasks = tasksUtilities.getLinesByToken editor,
        'tasks.text.done.source.gfm'
      projectTasks = tasksUtilities.getLinesByToken editor,
        'tasks.attribute.project'

      expect(doneTasks.length).toBe 1
      expect(projectTasks.length).toBe 1
###
