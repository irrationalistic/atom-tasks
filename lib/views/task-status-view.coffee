tasks = require '../tasksUtilities'
touchbar = require '../touchbar'
_ = require 'underscore'


class TaskStatusView extends HTMLElement
  initialize: (completeTask)->
    @classList.add('task-status', 'inline-block')
    @style.display = 'none'
    @completeTask = completeTask

    @activeItemSub = atom.workspace.onDidChangeActivePaneItem =>
      @subscribeToActiveTextEditor()

    @subscribeToActiveTextEditor()

  destroy: ->
    @activeItemSub.dispose()
    @changeSub?.dispose()
    @tokenizeSub?.dispose()

  subscribeToActiveTextEditor: ->
    @changeSub?.dispose()
    @changeSub = @getActiveTextEditor()?.onDidStopChanging =>
      @updateStatus()
    @tokenizeSub?.dispose()
    @tokenizeSub = @getActiveTextEditor()?.tokenizedBuffer
      .onDidTokenize => @updateStatus()
    @updateStatus()

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

      if info.task > 0
        pt = @editor.getCursorBufferPosition()
        config = atom.config.get('tasks')
        linf = tasks.parseLine @editor, pt.row, config

        touchbar.update linf, (complete) =>
          @completeTask()


module.exports = document.registerElement 'status-bar-tasks',
  prototype: TaskStatusView.prototype, extends: 'div'
