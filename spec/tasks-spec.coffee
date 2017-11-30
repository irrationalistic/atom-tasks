path = require 'path'
Tasks = require '../lib/tasks'
tasksUtilities = require '../lib/tasksUtilities'
[editor, buffer, grammar, workspaceElement] = []

baseTokens = ['source.todo', 'tasks.text']
doneTokens = ['source.todo', 'tasks.text.done']
cancelledTokens = ['source.todo', 'tasks.text.cancelled']

describe 'Tasks', ->
  beforeEach ->
    waitsForPromise ->
      atom.workspace.open().then (o) -> editor = o
    waitsForPromise ->
      atom.packages.activatePackage('tasks')
    runs ->
      grammar = atom.grammars.grammarForScopeName 'source.todo'
      editor = atom.workspace.getActiveTextEditor()
      editor.setGrammar grammar

  describe 'grammar should load', ->
    it 'loads', ->
      expect(grammar).toBeDefined()
      expect(grammar.scopeName).toBe 'source.todo'

  describe 'should tokenize', ->
    it 'tokenizes a task', ->
      tokens = grammar.tokenizeLines('☐ text @tag(test)')
      expect(tokens[0][0]).toEqual value: '☐', scopes: [baseTokens..., 'keyword.tasks.marker']
      expect(tokens[0][1]).toEqual value: ' text ', scopes: baseTokens
      expect(tokens[0][2]).toEqual value: '@', scopes: [baseTokens..., 'tasks.attribute.tag']
      expect(tokens[0][3]).toEqual value: 'tag', scopes: [baseTokens..., 'tasks.attribute.tag', 'tasks.attribute-name']
      # skip (
      expect(tokens[0][5]).toEqual value: 'test', scopes: [baseTokens..., 'tasks.attribute.tag', 'tasks.attribute-value']

    it 'tokenizes a project', ->
      tokens = grammar.tokenizeLines('project:')
      expect(tokens[0][0]).toEqual value: 'project', scopes: ['source.todo', 'control.tasks.header.project', 'control.tasks.header-title']

    it 'tokenizes a completed task', ->
      tokens = grammar.tokenizeLines('✔ text @done()')
      expect(tokens[0][3]).toEqual value: 'done', scopes: [doneTokens..., 'tasks.attribute.done', 'tasks.attribute-name']

    it 'tokenizes a cancelled task', ->
      tokens = grammar.tokenizeLines('✘ text @cancelled()')
      expect(tokens[0][3]).toEqual value: 'cancelled', scopes: [cancelledTokens..., 'tasks.attribute.cancelled', 'tasks.attribute-name']

  describe 'manage tasks', ->
    it 'creates a task below', ->
      editor.setText '  ☐ item 1'
      Tasks.newTask()
      editor.insertText 'item 2'
      line = editor.tokenizedBuffer.tokenizedLines[1]
      expect(line.tokens[1]).toEqual value: '☐', scopes: [baseTokens..., 'keyword.tasks.marker']
      expect(editor.indentationForBufferRow 1).toBe 1

    it 'creates a task above', ->
      editor.setText '  ☐ item 1'
      Tasks.newTask(-1)
      editor.insertText 'item 2'
      line = editor.tokenizedBuffer.tokenizedLines[0]
      expect(line.tokens[1]).toEqual value: '☐', scopes: [baseTokens..., 'keyword.tasks.marker']
      expect(editor.indentationForBufferRow 1).toBe 1

    it 'completes tasks', ->
      editor.setText 'project:\n  ☐ item 1'
      editor.setCursorBufferPosition [1,0]
      Tasks.completeTask()
      line = editor.tokenizedBuffer.tokenizedLines[1]
      expect(line.tokens[1]).toEqual value: '✔', scopes: [doneTokens..., 'keyword.tasks.marker']
      expect(line.tokens[4]).toEqual value: 'done', scopes: [doneTokens..., 'tasks.attribute.done', 'tasks.attribute-name']
      expect(line.tokens[12]).toEqual value: 'project', scopes: [doneTokens..., 'tasks.attribute.project', 'tasks.attribute-value']

    it 'cancels tasks', ->
      editor.setText 'project:\n  ☐ item 1'
      editor.setCursorBufferPosition [1,0]
      Tasks.cancelTask()
      line = editor.tokenizedBuffer.tokenizedLines[1]
      expect(line.tokens[1]).toEqual value: '✘', scopes: [cancelledTokens..., 'keyword.tasks.marker']
      expect(line.tokens[4]).toEqual value: 'cancelled', scopes: [cancelledTokens..., 'tasks.attribute.cancelled', 'tasks.attribute-name']
      expect(line.tokens[12]).toEqual value: 'project', scopes: [cancelledTokens..., 'tasks.attribute.project', 'tasks.attribute-value']

    it 'should add a timestamp', ->
      editor.setText '  ☐ item 1'
      Tasks.setTimestamp()
      line = editor.tokenizedBuffer.tokenizedLines[0]
      expect(line.tokens[4]).toEqual value: 'timestamp', scopes: [baseTokens..., 'tasks.attribute.timestamp', 'tasks.attribute-name']
      expect(line.tokens[6]).toEqual value: '1969-12-31 16:00', scopes: [baseTokens..., 'tasks.attribute.timestamp', 'tasks.attribute-value']

    it 'should update a timestamp', ->
      editor.setText '  ✔ item 1 @done(1970-1-1 0:00)'
      Tasks.setTimestamp()
      line = editor.tokenizedBuffer.tokenizedLines[0]
      expect(line.tokens[6]).toEqual value: '1969-12-31 16:00', scopes: [doneTokens..., 'tasks.attribute.done', 'tasks.attribute-value']

    it 'should convert to task', ->
      editor.setText 'item'
      Tasks.convertToTask()
      line = editor.tokenizedBuffer.tokenizedLines[0]
      expect(line.tokens[0]).toEqual value: '☐', scopes: [baseTokens..., 'keyword.tasks.marker']

    it 'should convert to task with timestamp', ->
      atom.config.set 'tasks.addTimestampOnConvertToTask', true
      editor.setText 'item'
      Tasks.convertToTask()
      line = editor.tokenizedBuffer.tokenizedLines[0]
      expect(line.tokens[5]).toEqual value: '1969-12-31 16:00', scopes: [baseTokens..., 'tasks.attribute.timestamp', 'tasks.attribute-value']

    it 'should archive completed tasks', ->
      editor.setText('''
      project:
        ☐ item 1
        ✔ item 2 @done(1970-1-1 0:00) @project(project)
      ''')
      Tasks.tasksArchive()
      line = editor.tokenizedBuffer.tokenizedLines[3]
      expect(line.tokens[0]).toEqual value: '＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿', scopes: ['source.todo']
      line = editor.tokenizedBuffer.tokenizedLines[4]
      expect(line.tokens[0]).toEqual value: 'Archive', scopes: ['source.todo', 'control.tasks.header.archive', 'control.tasks.header-title']
      line = editor.tokenizedBuffer.tokenizedLines[5]
      expect(line.tokens[2]).toEqual value: ' item 2 ', scopes: doneTokens

    it 'should archive cancelled tasks', ->
      editor.setText('''
      project:
        ☐ item 1
        ✘ item 2 @cancelled(1970-1-1 0:00) @project(project)
      ''')
      Tasks.tasksArchive()
      line = editor.tokenizedBuffer.tokenizedLines[5]
      expect(line.tokens[2]).toEqual value: ' item 2 ', scopes: cancelledTokens

  describe 'Taskpaper', ->
    beforeEach ->
      atom.config.set 'tasks.baseMarker', '-'
      atom.config.set 'tasks.completeMarker', '-'
      atom.config.set 'tasks.cancelledMarker', '-'
      grammar = atom.grammars.grammarForScopeName 'source.todo'
      editor.setGrammar grammar

    describe 'should tokenize', ->
      it 'tokenizes a task', ->
        tokens = grammar.tokenizeLines('- text @tag(test)')
        expect(tokens[0][0]).toEqual value: '-', scopes: [baseTokens..., 'keyword.tasks.marker']
        expect(tokens[0][1]).toEqual value: ' text ', scopes: baseTokens
        expect(tokens[0][2]).toEqual value: '@', scopes: [baseTokens..., 'tasks.attribute.tag']
        expect(tokens[0][3]).toEqual value: 'tag', scopes: [baseTokens..., 'tasks.attribute.tag', 'tasks.attribute-name']
        # skip (
        expect(tokens[0][5]).toEqual value: 'test', scopes: [baseTokens..., 'tasks.attribute.tag', 'tasks.attribute-value']

      it 'tokenizes a completed task', ->
        tokens = grammar.tokenizeLines('- text @done()')
        expect(tokens[0][3]).toEqual value: 'done', scopes: [doneTokens..., 'tasks.attribute.done', 'tasks.attribute-name']

      it 'tokenizes a cancelled task', ->
        tokens = grammar.tokenizeLines('- text @cancelled()')
        expect(tokens[0][3]).toEqual value: 'cancelled', scopes: [cancelledTokens..., 'tasks.attribute.cancelled', 'tasks.attribute-name']

    describe 'Complex markers', ->
      beforeEach ->
        atom.config.set 'tasks.baseMarker', '[ ]'
        atom.config.set 'tasks.completeMarker', '[x]'
        atom.config.set 'tasks.cancelledMarker', '[-]'
        grammar = atom.grammars.grammarForScopeName 'source.todo'
        editor.setGrammar grammar

      describe 'should tokenize', ->
        it 'tokenizes a task', ->
          tokens = grammar.tokenizeLines('[ ] text @tag(test)')
          expect(tokens[0][0]).toEqual value: '[ ]', scopes: [baseTokens..., 'keyword.tasks.marker']
          expect(tokens[0][1]).toEqual value: ' text ', scopes: baseTokens
          expect(tokens[0][2]).toEqual value: '@', scopes: [baseTokens..., 'tasks.attribute.tag']
          expect(tokens[0][3]).toEqual value: 'tag', scopes: [baseTokens..., 'tasks.attribute.tag', 'tasks.attribute-name']
          # skip (
          expect(tokens[0][5]).toEqual value: 'test', scopes: [baseTokens..., 'tasks.attribute.tag', 'tasks.attribute-value']

        it 'tokenizes a completed task', ->
          tokens = grammar.tokenizeLines('[x] text @done()')
          expect(tokens[0][3]).toEqual value: 'done', scopes: [doneTokens..., 'tasks.attribute.done', 'tasks.attribute-name']

        it 'tokenizes a cancelled task', ->
          tokens = grammar.tokenizeLines('[-] text @cancelled()')
          expect(tokens[0][3]).toEqual value: 'cancelled', scopes: [cancelledTokens..., 'tasks.attribute.cancelled', 'tasks.attribute-name']

  describe 'Escape', ->
    beforeEach ->
      editor.setText 'Project with (parens):\n  ☐ An incomplete task'
      editor.setCursorBufferPosition [1,0]

    describe 'should escape tag values', ->
      it 'adds a project attribute', ->
        Tasks.completeTask()

        projectTag = tasksUtilities.getTag editor, 1, 'project', '@'

        expect(projectTag).toBeDefined()
        expect(projectTag.tagValue.value).toEqual("Project with \\(parens\\)")

    describe 'should discard parenthesized done tags', ->
      it 'adds a project attribute', ->
        Tasks.completeTask()

        projectTag = tasksUtilities.getTag editor, 1, 'project', '@'

        # undo completion
        Tasks.completeTask()

        line = editor.getBuffer().lineForRow 1
        expect(line).toMatch(/☐\s+An incomplete task\s*$/)
