path = require 'path'
TaskEditor = require './views/task-editor-view'
SubAtom = require 'sub-atom'

module.exports =

  config:
    dateFormat:
      type: 'string', default: "YYYY-MM-DD HH:mm"
    baseMarker:
      type: 'string', default: '☐'
    completeMarker:
      type: 'string', default: '✔'
    cancelledMarker:
      type: 'string', default: '✘'


  validExtensions: [
    '.todo', '.taskpaper'
  ]

  activate: (state) ->
    @opener = (filePath)=>
      if path.extname(filePath) in @validExtensions
        console.log "attempting to open #{filePath}"
        new TaskEditor filePath

    atom.workspace.registerOpener @opener

  deactivate: ->
