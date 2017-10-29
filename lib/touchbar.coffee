tasks = require './tasksUtilities'

{TouchBar} = require('remote')
{TouchBarButton, TouchBarSpacer} = TouchBar

module.exports =
  update: (info, callback) ->
    if not TouchBar
      return

    window = atom.getCurrentWindow()

    if not info.type || not tasks.checkIsTasks()
      window.setTouchBar(null)
      return

    buttons = []
    config = atom.config.get('tasks')

    isTask = info.type == 'task'

    if isTask
      completed = info.marker.value in [config.completeMarker, config.cancelledMarker]

    buttons.push @callbackButton(config.baseMarker, "New", callback, '#5293d8')
    buttons.push new TouchBarSpacer({size: 'small'})

    if isTask && ! completed
      buttons.push @callbackButton(config.completeMarker, "Complete", callback, '#45A815')
      buttons.push new TouchBarSpacer({size: 'small'})

      buttons.push @callbackButton(config.cancelledMarker, "Cancel", callback, '#CD8E00')
      buttons.push new TouchBarSpacer({size: 'small'})

    if ! isTask && /\S/.test(info.line)
      buttons.push @callbackButton(config.baseMarker, "Convert", callback)
      buttons.push new TouchBarSpacer({size: 'small'})

    if info.wantArchive
      buttons.push @callbackButton("⇊", "Archive", callback)
      buttons.push new TouchBarSpacer({size: 'small'})

    touchBar = new TouchBar({items: buttons})

    window.setTouchBar(touchBar)

  callbackButton: (icon, command, callback, bgcolor) ->
    opts = {
      label: icon + " " + command,
      click: () =>
        callback(command.toLowerCase())
    }

    if bgcolor
      opts.backgroundColor = bgcolor

    return new TouchBarButton(opts)
