moment = require 'moment'

module.exports =

  activate: (state) ->
    atom.workspaceView.command "tasks:add", => @newTask()
    atom.workspaceView.command "tasks:complete", => @completeTask()
    atom.workspaceView.command "tasks:archive", => @tasksArchive()

    atom.workspaceView.eachEditorView (editorView) ->
      path = editorView.getEditor().getPath()
      if path.indexOf('.todo')>-1
        editorView.addClass 'task-list'

  deactivate: ->

  serialize: ->

  newTask: ->
    editor = atom.workspace.getActiveEditor()
    editor.transact ->
      editor.insertNewlineBelow()
      editor.insertText('☐ ')

  completeTask: ->
    editor = atom.workspace.getActiveEditor()

    editor.transact ->

      ranges = editor.getSelectedBufferRanges()
      coveredLines = []

      ranges.map (range)->
        coveredLines.push y for y in [range.start.row..range.end.row]

      lastProject = undefined

      coveredLines.map (row)->
        sp = [row,0]
        ep = [row,editor.lineLengthForBufferRow(row)]
        text = editor.getTextInBufferRange [sp, ep]

        for r in [row..0]
          tsp = [r, 0]
          tep = [r, editor.lineLengthForBufferRow(r)]
          checkLine = editor.getTextInBufferRange [tsp, tep]
          if checkLine.indexOf(':') is checkLine.length - 1
            lastProject = checkLine.replace(':', '')
            break

        if text.indexOf('☐') > -1
          text = text.replace '☐', '✔'
          text += " @done(#{moment().format('MM-DD-YY h:mm')})"
          text += " @project(#{lastProject})" if lastProject
        else
          text = text.replace '✔', '☐'
          text = text.replace /@done[ ]?\((.*?)\)/, ''
          text = text.replace /@project[ ]?\((.*?)\)/, ''
          text = text.trimRight()

        editor.setTextInBufferRange [sp,ep], text
      editor.setSelectedBufferRanges ranges

  tasksArchive: ->
    editor = atom.workspace.getActiveEditor()

    editor.transact ->
      ranges = editor.getSelectedBufferRanges()
      # move all completed tasks to the archive section
      text = editor.getText()
      raw = text.split('\n').filter (line)-> line isnt ''
      completed = []
      hasArchive = false

      original = raw.filter (line)->
        hasArchive = true if line.indexOf('Archive:') > -1
        found = '✔' in line
        completed.push line.replace(/^[ \t]+/, ' ') if found
        not found

      newText = original.join('\n') +
        (if not hasArchive then "＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿\nArchive:\n" else '\n') +
        completed.join('\n')

      if newText isnt text
        editor.setText newText
        editor.setSelectedBufferRanges ranges
