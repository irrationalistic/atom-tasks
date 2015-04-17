###
  Handle viewing of any todo file
###

{ScrollView} = require 'atom-space-pen-views'
{Emitter, Disposable, CompositeDisposable} = require 'atom'
{File} = require 'pathwatcher'

module.exports = class TaskEditorView extends ScrollView
  atom.deserializers.add(this)
  @deserialize: ({filePath}) ->
    new TaskEditorView(filePath)

  constructor: (filePath) ->
    super
    @disposables = new CompositeDisposable
    console.log filePath, @
    @file = new File filePath
    @file.read().then (text)-> updateView(text)
    console.log @file
    @disposables.add @file.onDidChange(@updateView)

  destroy: ->
    @detach()
    @disposables.dispose()

  @content: ->
    @h1 'TESTING!'

  getTitle: ->
    "Todo Thing"

  updateView: (text)->
    # given raw text,
    # parse into a specific format
