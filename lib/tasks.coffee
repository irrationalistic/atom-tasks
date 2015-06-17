{Point, Range} = require 'atom'
_ = require 'underscore'
moment = require 'moment'
CSON = require atom.config.resourcePath + "/node_modules/season/lib/cson.js"
Grammar = require atom.config.resourcePath +
  "/node_modules/first-mate/lib/grammar.js"
tasks = require './tasksUtilities'
TaskStatusView = require './views/task-status-view'

# Store the current settings for the markers
marker = completeMarker = cancelledMarker = archiveSeparator = ''

module.exports =

  ###
    PLUGIN CONFIGURATION:
  ###
  config:
    dateFormat:
      type: 'string', default: "YYYY-MM-DD HH:mm"
    baseMarker:
      type: 'string', default: '☐'
    completeMarker:
      type: 'string', default: '✔'
    cancelledMarker:
      type: 'string', default: '✘'
    archiveSeparator:
      type: 'string', default: '＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿'



  ###*
   * Activation of the plugin. Should set up
   * all listeners and force application of grammar.
   * @param  {object} state Application state
  ###
  activate: (state) ->

    # Get the markers from settings
    marker = atom.config.get('tasks.baseMarker')
    completeMarker = atom.config.get('tasks.completeMarker')
    cancelledMarker = atom.config.get('tasks.cancelledMarker')
    archiveSeparator = atom.config.get('tasks.archiveSeparator')

    # Whenever a marker setting changes, update the grammar
    atom.config.observe 'tasks.baseMarker', (val)=>
      marker = val; @updateGrammar()
    atom.config.observe 'tasks.completeMarker', (val)=>
      completeMarker = val; @updateGrammar()
    atom.config.observe 'tasks.cancelledMarker', (val)=>
      cancelledMarker = val; @updateGrammar()
    atom.config.observe 'tasks.archiveSeparator', (val)=>
      archiveSeparator = val;

    # Update the grammar when activated
    @updateGrammar()

    # Set up the command list
    atom.commands.add 'atom-text-editor',
      "tasks:add": => @newTask()
      "tasks:add-above": => @newTask(-1)
      "tasks:complete": => @completeTask()
      "tasks:archive": => @tasksArchive()
      "tasks:update-timestamps": => @tasksUpdateTimestamp()
      "tasks:cancel": => @cancelTask()
      "tasks:convert-to-task": => @convertToTask()



  ###*
   * Dynamically update the grammar CSON file
   * to support user-set values for markers.
  ###
  updateGrammar: ->
    # Escape a string
    clean = (str)->
      for pat in ['\\', '/', '[', ']', '*', '.', '+', '(', ')']
        str = str.replace pat, '\\' + pat
      str

    # Replace given string's markers
    rep = (prop)->
      str = prop
      str = str.replace '☐', clean marker
      str = str.replace '✔', clean completeMarker
      str = str.replace '✘', clean cancelledMarker

    # Load in the grammar manually and do replacement
    g = CSON.readFileSync __dirname + '/tasks.cson'
    g.repository.marker.match = rep g.repository.marker.match

    # first, clear existing grammar
    atom.grammars.removeGrammarForScopeName 'source.todo'
    newG = new Grammar atom.grammars, g
    atom.grammars.addGrammar newG

    # Reset all todo grammars to match
    atom.workspace.getTextEditors().map (editorView) ->
      grammar = editorView.getGrammar()
      if grammar.name is 'Tasks'
        editorView.setGrammar newG



  ###*
   * Helper for handling the status bar
   * @param {object} statusBar The statusbar
  ###
  consumeStatusBar: (statusBar) ->
    @taskStatus = new TaskStatusView()
    @taskStatus.initialize()
    @statusBarTile = statusBar.addLeftTile(item: @taskStatus, priority: 100)


  ###*
   * Handle deactivation of the plugin. Remove
   * all listeners and connections
  ###
  deactivate: ->
    @statusBarTile?.destroy()
    @statusBarTile = null



  ###*
   * Add a new todo item with the base marker
   * @param {number} direction = 1 Defines whether this should
   *                           		 be above or below the cursor
  ###
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
        if tasks.getToken line.tokens, tasks.headerSelector
          # is a project
          indentation++

      # ok, got the indentation, let's make the line
      finalIndent = editor.buildIndentString indentation

      editor.insertNewlineBelow() if direction is 1
      editor.insertNewlineAbove() if direction is -1
      editor.insertText "#{finalIndent}#{marker} "



  ###*
   * Helper for completing a task
  ###
  completeTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]

        markerToken = tasks.getToken screenLine.tokens, tasks.markerSelector
        doneToken = tasks.getToken screenLine.tokens, tasks.doneSelector

        if markerToken and not doneToken
          # This is a task and isn't already done,
          # so calculate the projects this task
          # belongs to.
          projects = tasks.getProjects editor, row
            .map (p)-> tasks.parseProjectName p
            .reverse()

          # Clear any cancelled information beforehand
          tasks.removeTag editor, row, 'cancelled'
          tasks.removeTag editor, row, 'project'

          # Add the tag and the projects, if there are any
          tasks.addTag editor, row, 'done', tasks.getFormattedDate()
          if projects.length
            tasks.addTag editor, row, 'project', projects.join ' / '
          tasks.setMarker editor, row, completeMarker

        else if markerToken and doneToken
          # This task was previously completed, so
          # just need to clear out the tags
          tasks.removeTag editor, row, 'done'
          tasks.removeTag editor, row, 'project'
          tasks.setMarker editor, row, marker



  ###*
   * Helper for cancelling a task
  ###
  cancelTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]

        markerToken = tasks.getToken screenLine.tokens, tasks.markerSelector
        cancelledToken = tasks.getToken screenLine.tokens,
          tasks.cancelledSelector

        if markerToken and not cancelledToken
          # This is a task and isn't already cancelled,
          # so calculate the projects this task
          # belongs to.
          projects = tasks.getProjects editor, row
            .map (p)-> tasks.parseProjectName p
            .reverse()

          # Clear any done information beforehand
          tasks.removeTag editor, row, 'done'
          tasks.removeTag editor, row, 'project'

          # Add the tag and the projects, if there are any
          tasks.addTag editor, row, 'cancelled', tasks.getFormattedDate()
          if projects.length
            tasks.addTag editor, row, 'project', projects.join ' / '
          tasks.setMarker editor, row, cancelledMarker

        else if markerToken and cancelledToken
          # This task was previously completed, so
          # just need to clear out the tags
          tasks.removeTag editor, row, 'cancelled'
          tasks.removeTag editor, row, 'project'
          tasks.setMarker editor, row, marker



  ###*
   * Helper for updating timestamps to match
   * the given settings
  ###
  tasksUpdateTimestamp: ->
    # Update timestamps to match the current setting (only for tags though)
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]
        # These tags will receive updated timestamps
        # based on existing ones
        tagsToUpdate = ['done', 'cancelled']
        for tag in tagsToUpdate
          curDate = tasks.getTag(editor, row, tag)?.tagValue.value
          if curDate
            tasks.updateTag editor, row, tag, tasks.getFormattedDate(curDate)



  ###*
   * Helper for converting a non-task
   * line to a task
  ###
  convertToTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        screenLine = editor.displayBuffer.tokenizedBuffer.tokenizedLines[row]
        markerToken = tasks.getToken screenLine.tokens, tasks.markerSelector
        projectToken = tasks.getToken screenLine.tokens, tasks.headerSelector
        if not markerToken and not projectToken
          # Only set the marker if this isn't
          # already a task or header.
          tasks.setMarker editor, row, marker



  ###*
   * Helper for handling the archiving of
   * all done and cancelled tasks
  ###
  tasksArchive: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    editor.transact ->

      completedTasks = []
      archiveProject = null
      insertRow = -1

      # 1. Find the archives section, if it exists

      editor.displayBuffer.tokenizedBuffer.tokenizedLines.every (i, ind)->
        # if we already found the archive, no need
        # to parse any more!
        return false if archiveProject
        hasDone = tasks.getToken i.tokens, tasks.doneSelector
        hasCancelled = tasks.getToken i.tokens, tasks.cancelledSelector
        hasArchive = tasks.getToken i.tokens, tasks.archiveSelector

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


        #{archiveSeparator}
        Archive:

        """

        # Before adding the final archive section,
        # we should clear out the empty lines at
        # the end of the file.
        for line, i in editor.buffer.lines by -1
          if editor.buffer.isRowBlank i
            # remove the line
            editor.buffer.deleteRow i
          else
            break

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
