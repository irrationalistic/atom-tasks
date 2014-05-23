{WorkspaceView} = require 'atom'
Tasks = require '../lib/tasks'
[activationPromise, editor, editorView] = []

waitTest = (cb)->
  waitsForPromise -> activationPromise
  runs ->
    editorView.attachToDom()
    cb()

describe 'Tasks', ->

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    atom.workspaceView.openSync 'sample.todo'
    atom.workspaceView.simulateDomAttachment()
    editorView = atom.workspaceView.getActiveView()
    editor = editorView.getEditor()
    activationPromise = atom.packages.activatePackage('tasks')

  describe 'should syntax highlight a todo file', ->
    it 'adds .task-list to the editor', ->
      waitTest ->
        expect(editorView).toHaveClass 'task-list'

    it 'adds .marker to the markers', ->
      waitTest ->
        expect(editorView.find('.marker').length).toBe 2

    it 'adds .attribute to @tags', ->
      waitTest ->
        expect(editorView.find('.attribute').length).toBe 1

    it 'adds .text to plain text', ->
      waitTest ->
        expect(editorView.find('.text').length).toBe 2

  describe 'should be able to add new tasks', ->
    it 'adds a new task', ->
      waitTest ->
        Tasks.newTask()
        editor.insertText 'Todo Item from tests'
        newText = editorView.find('.marker:first').parent().text()
        indent = newText.match(/^(\s+)/)?[0].length

        expect(editorView.find('.marker').length).toBe 3

        expect(indent).toBe atom.config.get('editor.tabLength')

  describe 'should be able to complete tasks', ->
    it 'completes a task', ->
      waitTest ->
        editor.setCursorBufferPosition [1,0]
        Tasks.completeTask()
        newText = editor.getText()
        expect(editorView.find('.marker.complete').length).toBe 1
        expect(newText.indexOf('@done')).toBeGreaterThan -1
        expect(newText.indexOf('@project')).toBeGreaterThan -1

  describe 'should be able to archive completed tasks', ->
    it 'creates an archive section', ->
      waitTest ->
        preText = editor.getText()
        editor.setCursorBufferPosition [1,0]
        Tasks.completeTask()
        Tasks.tasksArchive()
        newText = editor.getText()

        expect(editor.getText()).toContain 'Archive:'
        expect(newText.split('\n').length).toBe 5

    it 'moves completed tasks',
      waitTest ->
        preText = editor.getText()
        editor.setCursorBufferPosition [1,0]
        Tasks.completeTask()
        Tasks.tasksArchive()
        newText = editor.getText()
        lines = newText.split('\n')
        lastLine = lines[lines.length-1]
        expect(lastLine).toContain '✔'
