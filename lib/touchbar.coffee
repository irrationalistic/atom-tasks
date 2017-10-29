{TouchBar} = require('remote')
{TouchBarLabel, TouchBarButton, TouchBarSpacer} = TouchBar

module.exports =
  update: (info, callback) ->
    if not TouchBar
      return

    window = atom.getCurrentWindow()

    if not info.type
      window.setTouchBar(null)
      return

    if ! @checkIsTasks()
      window.setTouchBar(null)
      return

    config = atom.config.get('tasks')
    buttons = []

    isTask = info.type == 'task'

    if isTask
      completed = info.marker.value in [config.completeMarker, config.cancelledMarker]

    buttons.push new TouchBarButton({
        label: config.baseMarker + " New",
        backgroundColor: '#5293d8',
        click: () =>
          callback "new"
      })
    buttons.push new TouchBarSpacer({size: 'small'})

    if isTask && ! completed
      buttons.push new TouchBarButton({
        label: config.completeMarker + " Complete",
        backgroundColor: '#45A815',
        click: () =>
          callback "complete"
      })
      buttons.push new TouchBarSpacer({size: 'small'})

      buttons.push new TouchBarButton({
        label: config.cancelledMarker + " Cancel",
        backgroundColor: '#CD8E00',
        click: () =>
          callback "cancel"
      })
      buttons.push new TouchBarSpacer({size: 'small'})

    if ! isTask && /\S/.test(info.line)
      buttons.push new TouchBarButton({
        label: config.baseMarker + " Convert to Task",
        click: () =>
          callback "convert"
      })
      buttons.push new TouchBarSpacer({size: 'small'})

    if info.wantArchive
      buttons.push new TouchBarButton({
        label: "Archive",
        click: () =>
          callback "archive"
      })
      buttons.push new TouchBarSpacer({size: 'small'})

    touchBar = new TouchBar({items: buttons})

    window.setTouchBar(touchBar)


  checkIsTasks: ->
    editor = atom.workspace.getActiveTextEditor()
    return editor?.getGrammar().name is 'Tasks'
