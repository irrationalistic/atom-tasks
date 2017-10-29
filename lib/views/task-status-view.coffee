tasks = require '../tasksUtilities'
touchbar = require '../touchbar'
_ = require 'underscore'


class TaskStatusView extends HTMLElement
  initialize: (completeTask, createTask, cancelTask, convertToTask, archiveTasks)->
    @classList.add('task-status', 'inline-block')
    @style.display = 'none'
    @completeTask = completeTask
    @createTask = createTask
    @cancelTask = cancelTask
    @convertToTask = convertToTask
    @archiveTasks = archiveTasks
    @lastLine = -1
    @wantArchive = false

    config = atom.config.get('tasks')
    @useTouchbar = config.useTouchbar

    _this = this

    atom.config.onDidChange 'tasks.useTouchbar', ({newValue, oldValue}) ->
      _this.useTouchbar = newValue

      if newValue != oldValue
        _this.updateTouchbar()

    @activeItemSub = atom.workspace.onDidChangeActivePaneItem =>
      _this.subscribeToActiveTextEditor()

    @subscribeToActiveTextEditor()

  destroy: ->
    @activeItemSub.dispose()
    @changeSub?.dispose()
    @tokenizeSub?.dispose()
    @moveSub?.dispose()

  subscribeToActiveTextEditor: ->
    @changeSub?.dispose()
    @changeSub = @getActiveTextEditor()?.onDidStopChanging =>
      @updateStatus()
    @tokenizeSub?.dispose()
    @tokenizeSub = @getActiveTextEditor()?.tokenizedBuffer
      .onDidTokenize => @updateStatus()
    @moveSub?.dispose()
    @moveSub = @getActiveTextEditor()?.onDidChangeCursorPosition =>
      pos = @getActiveTextEditor()?.getCursorBufferPosition()
      if pos.row != @lastLine
        @lastLine = pos.row
        @updateTouchbar()
    @updateStatus()
    @updateTouchbar()

  getActiveTextEditor: ->
    @editor = atom.workspace.getActiveTextEditor()

  checkIsTasks: ->
    if @editor?.getGrammar().name is 'Tasks'
      @style.display = ''
      return true
    @style.display = 'none'
    false


  # need to call on movement (at least for touchbar)
  updateStatus: ->
    if @checkIsTasks()
      tokenizedLines = @editor.tokenizedBuffer.tokenizedLines
      info = _.countBy tokenizedLines, (line)->
        return 'text' if not line
        hasMarker = tasks.getToken line.tokens, tasks.markerSelector
        hasDone = tasks.getToken line.tokens, tasks.doneSelector
        hasCancelled = tasks.getToken line.tokens, tasks.cancelledSelector
        hasProject = tasks.getToken line.tokens, tasks.headerSelector

        return 'project' if hasProject
        return 'done' if hasDone
        return 'cancelled' if hasCancelled
        return 'task' if hasMarker
        return 'text'

      _.defaults info,
        done: 0, cancelled: 0
        project: 0, task: 0
        text: 0

      completed = info.done + info.cancelled
      total = completed + info.task
      completed = '-' if isNaN completed
      total = '-' if isNaN total
      @textContent = "(#{completed}/#{total})"
      @wantArchive = completed > 0

      if info.task > 0
        @updateTouchbar()

  updateTouchbar: ->
    if @useTouchbar && @checkIsTasks()
      pt = @editor.getCursorBufferPosition()
      config = atom.config.get('tasks')
      linf = tasks.parseLine @editor, pt.row, config
      linf.wantArchive = @wantArchive

      touchbar.update linf, (action) =>
        switch action
          when "complete" then @completeTask()
          when "new" then @createTask()
          when "cancel" then @cancelTask()
          when "convert" then @convertToTask()
          when "archive" then @archiveTasks()
    else
      touchbar.update({}, null)


module.exports = document.registerElement 'status-bar-tasks',
  prototype: TaskStatusView.prototype, extends: 'div'
