{Point, Range} = require 'atom'
_ = require 'underscore'
moment = require 'moment'
CSON = require atom.config.resourcePath + "/node_modules/season/lib/cson.js"
Grammar = require atom.config.resourcePath +
  "/node_modules/first-mate/lib/grammar.js"
tasks = require './tasksUtilities'
TaskStatusView = require './views/task-status-view'

# Store the current settings for the markers
marker = completeMarker = cancelledMarker = archiveSeparator = attributeMarker = ''

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
    attributeMarker:
      type: 'string', default: '@'



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
    attributeMarker = atom.config.get('tasks.attributeMarker')

    # Whenever a marker setting changes, update the grammar
    atom.config.observe 'tasks.baseMarker', (val)=>
      marker = val; @updateGrammar()
    atom.config.observe 'tasks.completeMarker', (val)=>
      completeMarker = val; @updateGrammar()
    atom.config.observe 'tasks.cancelledMarker', (val)=>
      cancelledMarker = val; @updateGrammar()
    atom.config.observe 'tasks.archiveSeparator', (val)=>
      archiveSeparator = val
    atom.config.observe 'tasks.attributeMarker', (val)=>
      attributeMarker = val; @updateGrammar()

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
      "tasks:set-timestamp": => @setTimestamp()



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
      str = str.replace '@', clean attributeMarker

    # Load in the grammar manually and do replacement
    g = CSON.readFileSync __dirname + '/tasks.cson'
    # g.repository.marker.match = rep g.repository.marker.match
    g.repository.attribute.match = rep g.repository.attribute.match
    g.patterns = g.patterns.map (pattern) ->
      pattern.match = rep pattern.match if pattern.match
      pattern.begin = rep pattern.begin if pattern.begin
      pattern

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
      info = tasks.parseLine editor, pos.row, atom.config.get('tasks')

      editor.insertNewlineBelow() if direction is 1
      editor.insertNewlineAbove() if direction is -1
      editor.insertText "#{marker} "

      editor.indentSelectedRows() if info.type is 'project' and direction is 1



  ###*
   * Helper for completing a task
  ###
  completeTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->

        info = tasks.parseLine editor, row, atom.config.get('tasks')

        markerToken = info.marker
        doneToken = _.find info.tags, (tag) -> tag.tagName.value is 'done'

        if markerToken and not doneToken
          # This is a task and isn't already done,
          # so calculate the projects this task
          # belongs to.
          projects = tasks.getProjects editor, row
            .map (p)-> tasks.parseProjectName p
            .reverse()

          # Clear any cancelled information beforehand
          tasks.removeTag editor, info, 'cancelled'
          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.removeTag editor, info, 'project'
          info = tasks.parseLine editor, row, atom.config.get('tasks')

          # Add the tag and the projects, if there are any
          tasks.addTag editor, row, attributeMarker, 'done', tasks.getFormattedDate()
          if projects.length
            tasks.addTag editor, row, attributeMarker, 'project', projects.join ' / '

          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.setMarker editor, info, completeMarker

        else if markerToken and doneToken
          # This task was previously completed, so
          # just need to clear out the tags
          tasks.removeTag editor, info, 'done'
          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.removeTag editor, info, 'project'
          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.setMarker editor, info, marker



  ###*
   * Helper for cancelling a task
  ###
  cancelTask: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->

        info = tasks.parseLine editor, row, atom.config.get('tasks')

        markerToken = info.marker
        cancelledToken = _.find info.tags, (tag) -> tag.tagName.value is 'cancelled'


        if markerToken and not cancelledToken
          # This is a task and isn't already cancelled,
          # so calculate the projects this task
          # belongs to.
          projects = tasks.getProjects editor, row
            .map (p)-> tasks.parseProjectName p
            .reverse()

          # Clear any done information beforehand
          tasks.removeTag editor, info, 'done'
          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.removeTag editor, info, 'project'

          # Add the tag and the projects, if there are any
          tasks.addTag editor, row, attributeMarker, 'cancelled', tasks.getFormattedDate()
          if projects.length
            tasks.addTag editor, row, attributeMarker, 'project', projects.join ' / '

          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.setMarker editor, info, cancelledMarker

        else if markerToken and cancelledToken
          # This task was previously completed, so
          # just need to clear out the tags
          tasks.removeTag editor, info, 'cancelled'
          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.removeTag editor, info, 'project'
          info = tasks.parseLine editor, row, atom.config.get('tasks')
          tasks.setMarker editor, info, marker



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
        screenLine = editor.tokenizedBuffer.tokenizedLines[row]
        # These tags will receive updated timestamps
        # based on existing ones
        tagsToUpdate = ['done', 'cancelled', 'timestamp']
        for tag in tagsToUpdate
          info = tasks.parseLine editor, row, atom.config.get('tasks')
          curDateTag = _.find info.tags, (t) -> t.tagName.value is tag
          curDate = curDateTag?.tagValue.value
          if curDate
            tasks.updateTag editor, info, attributeMarker, tag, tasks.getFormattedDate(curDate)



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
        info = tasks.parseLine editor, row, atom.config.get('tasks')
        if info.type is 'text'
          # Only set the marker if this isn't
          # already a task or header.
          tasks.setMarker editor, info, marker


  ###*
   * Helper for setting the timestamp on a task. If it exists, remove and
   * reset it. If it doesn't exist, add it. This will also update the timestamp
   * for tasks that have 'done' or 'cancelled'
  ###
  setTimestamp: ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor

    selection = editor.getSelectedBufferRanges()

    editor.transact ->
      tasks.getAllSelectionRows(selection).map (row)->
        info = tasks.parseLine editor, row, atom.config.get('tasks')

        if info.marker
          doneTag = _.find info.tags, (t) -> t.tagName.value is 'done'
          cancelledTag = _.find info.tags, (t) -> t.tagName.value is 'cancelled'
          timestampTag = _.find info.tags, (t) -> t.tagName.value is 'timestamp'

          curDate = tasks.getFormattedDate()

          if not doneTag and not cancelledTag and not timestampTag
            tasks.addTag editor, row, attributeMarker, 'timestamp', curDate
          else
            tasks.updateTag editor, info, attributeMarker, 'done', curDate
            info = tasks.parseLine editor, row, atom.config.get('tasks')
            tasks.updateTag editor, info, attributeMarker, 'cancelled', curDate
            info = tasks.parseLine editor, row, atom.config.get('tasks')
            tasks.updateTag editor, info, attributeMarker, 'timestamp', curDate

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

      editor.buffer.lines.every (i, ind)->
        # if we already found the archive, no need
        # to parse any more!
        return false if archiveProject
        info = tasks.parseLine editor, ind, atom.config.get('tasks')
        hasDone = _.some info.tags, (t) -> t.tagName.value is 'done'
        hasCancelled = _.some info.tags, (t) -> t.tagName.value is 'cancelled'
        hasArchive = info.project is 'Archive'

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
        editor.buffer.insert insertPoint, "#{indentation}#{i.line.trim()}\n"

      # 4. Copy is completed, start deleting the
      #     copied items
      completedTasks.forEach (i)->
        editor.buffer.deleteRow i.lineNumber
