{TouchBar} = require('remote')
{TouchBarLabel, TouchBarButton, TouchBarSpacer} = TouchBar

spinning = false

      # _.defaults info,
      #   done: 0, cancelled: 0
      #   project: 0, task: 0
      #   text: 0

      # todo: credit

module.exports =
  update: (info, callback) ->
    if not TouchBar
      return

    touchable = info.type == 'task'

    if touchable
      config = atom.config.get('tasks')
      touchable = (info.marker != config.completeMarker) && (info.marker != config.cancelledMarker)

    if touchable
      button = new TouchBarButton({
        label: config.completeMarker + " Complete",
        backgroundColor: '#353232',
        click: () =>
          callback true
      })
      touchBar = new TouchBar([
        button,
        new TouchBarSpacer({size: 'small'}),
      ])
    else
      touchBar = null

    window = atom.getCurrentWindow()
    window.setTouchBar(touchBar)
