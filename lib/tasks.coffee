moment = require 'moment'
_ = require 'underscore'
CSON = require atom.config.resourcePath + "/node_modules/season/lib/cson.js"
TaskGrammar = require './task-grammar'
Grammar = require atom.config.resourcePath +
  "/node_modules/first-mate/lib/grammar.js"

TaskParser = require './parser'
{Point, Range} = require 'atom'
tasks = require './tasksUtilities'

marker = completeMarker = cancelledMarker = ''
# projectRegex = /@project[ ]?\((.*?)\)/
# doneRegex = /@done[ ]?(?:\((.*?)\))?/
# cancelledRegex = /@cancelled[ ]?(?:\((.*?)\))?/

module.exports =

  config:
    dateFormat:
      type: 'string'
      default: "YYYY-MM-DD HH:mm"
    baseMarker:
      type: 'string', default: '☐'
    completeMarker:
      type: 'string', default: '✔'
    cancelledMarker:
      type: 'string', default: '✘'

  activate: (state) ->

    marker = atom.config.get('tasks.baseMarker')
    completeMarker = atom.config.get('tasks.completeMarker')
    cancelledMarker = atom.config.get('tasks.cancelledMarker')

    atom.config.observe 'tasks.baseMarker', (val)=>
      marker = val; @updateGrammar()
    atom.config.observe 'tasks.completeMarker', (val)=>
      completeMarker = val; @updateGrammar()
    atom.config.observe 'tasks.cancelledMarker', (val)=>
      cancelledMarker = val; @updateGrammar()

    @updateGrammar()

    atom.commands.add 'atom-text-editor',
      "tasks:add": => @newTask()
      "tasks:addAbove": => @newTask(-1)
      "tasks:complete": => @completeTask()
      "tasks:archive": => @tasksArchive()
      "tasks:updateTimestamps": => @tasksUpdateTimestamp()
      "tasks:cancel": => @cancelTask()
      "tasks:convertToTask": => @convertToTask()

  updateGrammar: ->
    clean = (str)->
      for pat in ['\\', '/', '[', ']', '*', '.', '+', '(', ')']
        str = str.replace pat, '\\' + pat
      str

    g = CSON.readFileSync __dirname + '/tasks.cson'
    rep = (prop)->
      str = prop
      str = str.replace '☐', clean marker
      str = str.replace '✔', clean completeMarker
      str = str.replace '✘', clean cancelledMarker
    mat = (ob)->
      res = []
      for pat in ob
        pat.begin = rep(pat.begin) if pat.begin
        pat.end = rep(pat.end) if pat.end
        pat.match = rep(pat.match) if pat.match
        if pat.patterns
          pat.patterns = mat pat.patterns
        res.push pat
      res

    g.patterns = mat g.patterns

    # first, clear existing grammar
    atom.grammars.removeGrammarForScopeName 'source.todo'
    newG = new Grammar atom.grammars, g
    atom.grammars.addGrammar newG

    # Reload all todo grammars to match
    atom.workspace.getTextEditors().map (editorView) ->
      grammar = editorView.getGrammar()
      if grammar.name is 'Tasks'
        # editorView.editor.reloadGrammar()
        editorView.setGrammar newG

  deactivate: ->
    # TODO: Clear markers and __tasks

  serialize: ->

  newTask: (direction = 1)->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    editor.transact ->
      pos = editor.getCursorBufferPosition()


      indentation = 0

      if direction is -1
        line = editor.displayBuffer.tokenizedBuffer.tokenizedLines[pos.row - 1]
      else
        line = editor.displayBuffer.tokenizedBuffer.tokenizedLines[pos.row]
        if tasks.getToken line.tokens, 'tasks.header'
          # is a project
          indentation++


      # ok, got the indentation, let's make the line
      finalIndent = editor.buildIndentString indentation

      editor.insertNewlineBelow() if direction is 1
      editor.insertNewlineAbove() if direction is -1
      editor.insertText "#{finalIndent}#{marker} "

  completeTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]

        markerToken = tasks.getToken screenLine.tokens, 'tasks.marker'
        doneToken = tasks.getToken screenLine.tokens, 'tasks.attribute.done'

        if markerToken and not doneToken
          projects = tasks.getProjects editor, row
            .map (p)-> tasks.parseProjectName p
            .reverse()

          tasks.addTag editor, row, 'done', tasks.getFormattedDate()
          tasks.addTag editor, row, 'project', projects.join ' / '
          tasks.setMarker editor, row, completeMarker
        else if markerToken and doneToken
          tasks.removeTag editor, row, 'done'
          tasks.removeTag editor, row, 'project'
          tasks.setMarker editor, row, marker

  cancelTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]

        markerToken = tasks.getToken screenLine.tokens, 'tasks.marker'
        cancelledToken = tasks.getToken screenLine.tokens,
          'tasks.attribute.cancelled'

        if markerToken and not cancelledToken
          projects = tasks.getProjects editor, row
            .map (p)-> tasks.parseProjectName p
            .reverse()

          tasks.addTag editor, row, 'cancelled', tasks.getFormattedDate()
          tasks.addTag editor, row, 'project', projects.join ' / '
          tasks.setMarker editor, row, cancelledMarker
        else if markerToken and cancelledToken
          tasks.removeTag editor, row, 'cancelled'
          tasks.removeTag editor, row, 'project'
          tasks.setMarker editor, row, marker

  tasksUpdateTimestamp: ->
    # Update timestamps to match the current setting (only for tags though)
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]
        tagsToUpdate = ['done', 'cancelled']
        for tag in tagsToUpdate
          curDate = tasks.getTag(editor, row, tag)?.tagValue.value
          if curDate
            tasks.updateTag editor, row, tag, tasks.getFormattedDate(curDate)

  convertToTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]
        markerToken = tasks.getToken screenLine.tokens, 'tasks.marker'
        projectToken = tasks.getToken screenLine.tokens, 'tasks.header'
        if not markerToken and not projectToken
          tasks.setMarker editor, row, marker

  tasksArchive: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    editor.transact ->
      # given an entire document of tasks,
      # this should find all the ones that
      # have the done or cancelled tag.
      # Group them in order and prepend to the
      # existing archive list

      completedTasks = []
      archiveProject = null
      insertRow = -1

      # 1. Find the archives section, if it exists

      # Optimize by looping all at once
      editor.displayBuffer.tokenizedBuffer.tokenizedLines.every (i, ind)->
        # if we already found the archive, no need
        # to parse any more!
        return false if archiveProject
        hasDone = tasks.getToken i.tokens, 'tasks.done'
        hasCancelled = tasks.getToken i.tokens, 'tasks.cancelled'
        hasArchive = tasks.getToken i.tokens, 'tasks.header.archive'

        el =
          lineNumber: ind
          line: i

        archiveProject = el if hasArchive
        completedTasks.push el if hasDone or hasCancelled
        true

      # 2. I have a list of all completed tasks,
      #     as well as where the archive exists, if it does

      if not archiveProject
        # no archive? create it!
        archiveText = """

        ＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿
        Archive:

        """

        # add to the end of the file
        newRange = editor.buffer.append archiveText
        insertRow = newRange.end.row
      else
        insertRow = archiveProject.lineNumber + 1

      # 3. Archive insertion point is ready! Let's
      #     start copying down the completed items.
      completedTasks.reverse()

      insertPoint = new Point insertRow, 0
      indentation = editor.buildIndentString 1
      completedTasks.forEach (i)->
        editor.buffer.insert insertPoint,
          indentation +
          i.line.text.substring(i.line.firstNonWhitespaceIndex) + '\n'

      # 4. Copy is completed, start deleting the
      #     copied items
      completedTasks.forEach (i)->
        editor.buffer.deleteRow i.lineNumber
