moment = require 'moment'

lpad = (value, padding) ->
  zeroes = "0"
  zeroes += "0" for i in [1..padding]
  (zeroes + value).slice(padding * -1)

mapSelectedItems = (editor, cb)->
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

    cb text, lastProject, sp, ep

  {
    lines: coveredLines
    ranges: ranges
  }

module.exports =

  configDefaults:
    dateFormat: "YYYY-MM-DD hh:mm"

  activate: (state) ->
    atom.workspaceView.command "tasks:add", => @newTask()
    atom.workspaceView.command "tasks:complete", => @completeTask()
    atom.workspaceView.command "tasks:archive", => @tasksArchive()
    atom.workspaceView.command "tasks:updateTimestamps", => @tasksUpdateTimestamp()
    atom.workspaceView.command "tasks:cancel", => @cancelTask()

    atom.workspaceView.eachEditorView (editorView) ->
      path = editorView.getEditor().getPath()
      if path.indexOf('.todo')>-1
        editorView.addClass 'task-list'

  deactivate: ->

  serialize: ->

  newTask: ->
    editor = atom.workspace.getActiveEditor()
    editor.transact ->
      current_pos = editor.getCursorBufferPosition()
      prev_line = editor.lineForBufferRow(current_pos.row)
      indentLevel = prev_line.match(/^(\s+)/)?[0]
      targTab = Array(atom.config.get('editor.tabLength') + 1).join(' ')
      indentLevel = if not indentLevel then targTab else ''
      editor.insertNewlineBelow()
      # should have a minimum of one tab in
      editor.insertText indentLevel + '☐ '

  completeTask: ->
    editor = atom.workspace.getActiveEditor()

    editor.transact ->
      {lines, ranges} = mapSelectedItems editor, (line, lastProject, bufferStart, bufferEnd)->
        if line.indexOf('☐') > -1
          line = line.replace '☐', '✔'
          line += " @done(#{moment().format(atom.config.get('tasks.dateFormat'))})"
          line += " @project(#{lastProject})" if lastProject
        else
          line = line.replace '✔', '☐'
          line = line.replace /@done[ ]?\((.*?)\)/, ''
          line = line.replace /@project[ ]?\((.*?)\)/, ''
          line = line.trimRight()

        editor.setTextInBufferRange [bufferStart,bufferEnd], line
      editor.setSelectedBufferRanges ranges

  cancelTask: ->
    editor = atom.workspace.getActiveEditor()

    editor.transact ->
      {lines, ranges} = mapSelectedItems editor, (line, lastProject, bufferStart, bufferEnd)->
        if line.indexOf('☐') > -1
          line = line.replace '☐', '✘'
          line += " @cancelled(#{moment().format(atom.config.get('tasks.dateFormat'))})"
          line += " @project(#{lastProject})" if lastProject
        else
          line = line.replace '✘', '☐'
          line = line.replace /@cancelled[ ]?\((.*?)\)/, ''
          line = line.replace /@project[ ]?\((.*?)\)/, ''
          line = line.trimRight()

        editor.setTextInBufferRange [bufferStart,bufferEnd], line
      editor.setSelectedBufferRanges ranges

  tasksUpdateTimestamp: ->
    # Update timestamps to match the current setting (only for tags though)
    editor = atom.workspace.getActiveEditor()
    editor.transact ->
      nText = editor.getText().replace /@done\(([^\)]+)\)/igm, (matches...)->
        "@done(#{moment(matches[1]).format(atom.config.get('tasks.dateFormat'))})"
      editor.setText nText

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
        found = '✔' in line or '✘' in line
        completed.push line.replace(/^[ \t]+/, ' ') if found
        not found

      newText = original.join('\n') +
        (if not hasArchive then "\n＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿\nArchive:\n" else '\n') +
        completed.join('\n')

      if newText isnt text
        editor.setText newText
        editor.setSelectedBufferRanges ranges
