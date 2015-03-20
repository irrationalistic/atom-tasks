Tasks = require '../lib/tasks'
[editor, buffer, workspaceElement] = []

find = (selector)->
  workspaceElement.querySelectorAll "body /deep/ #{selector}"

describe 'Tasks', ->

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('sample.todo').then (o) -> editor = o
    runs ->
      buffer = editor.getBuffer()
    waitsForPromise ->
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
      expect(find('.marker').length).toBe 2

    it 'adds .attribute to @tags', ->
      expect(find('.attribute').length).toBe 2

    it 'adds .text to plain text', ->
      expect(find('.text').length).toBe 3

  describe 'should be able to add new tasks', ->
    it 'adds a new task', ->
      Tasks.newTask()
      editor.insertText 'Todo Item from tests'
      newText = find('.marker')[0].parentNode.innerText
      indent = newText.match(/^(\s+)/)?[0].length

      expect(find('.marker').length).toBe 3

      expect(indent).toBe atom.config.get('editor.tabLength')

  describe 'should be able to complete tasks', ->
    it 'completes a task', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      newText = editor.getText()
      expect(find('.marker.done').length).toBe 1
      expect(newText.indexOf('@done')).toBeGreaterThan -1
      expect(newText.indexOf('@project')).toBeGreaterThan -1

  describe 'should be able to cancel tasks', ->
    it 'cancels a task', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.cancelTask()
      newText = editor.getText()
      expect(find('.marker.cancelled').length).toBe 1
      expect(newText.indexOf('@cancelled')).toBeGreaterThan -1
      expect(newText.indexOf('@project')).toBeGreaterThan -1

  describe 'should be able to archive completed tasks', ->
    it 'creates an archive section', ->
      preText = editor.getText()
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      Tasks.tasksArchive()
      newText = editor.getText()

      expect(newText).toContain 'Archive:'
      expect(newText.split('\n').length).toBe 7

    it 'moves completed tasks', ->
      preText = editor.getText()
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      Tasks.tasksArchive()
      newText = editor.getText()
      lines = newText.split('\n')
      lastLine = lines[lines.length-2]
      expect(lastLine).toContain '@done'

    it 'moves cancelled tasks', ->
      preText = editor.getText()
      editor.setCursorBufferPosition [1,0]
      Tasks.cancelTask()
      Tasks.tasksArchive()
      newText = editor.getText()
      lines = newText.split('\n')
      lastLine = lines[lines.length-2]
      expect(lastLine).toContain '@cancelled'

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
      expect(find('.text').length).toBe 7

  describe 'should support the same marker for base, done, and cancelled', ->
    it 'can complete a task', ->
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      newText = editor.getText()
      expect(find('.marker.done').length).toBe 1
      expect(newText.indexOf('@done')).toBeGreaterThan -1
      expect(newText.indexOf('@project')).toBeGreaterThan -1
