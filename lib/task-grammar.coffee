# TODO: This should be
#  {Grammar} = require "first-mate"
# but doing so throws "Error: Cannot find module 'first-mate'"
Grammar = require atom.config.resourcePath +
  "/node_modules/first-mate/lib/grammar.js"

class TaskGrammar extends Grammar
  constructor: (registry) ->
    name = "Tasks"
    scopeName = "source.todo"

    marker = atom.config.get('tasks.taskMarker')
    complete = atom.config.get('tasks.completeMarker')
    cancelled = atom.config.get('tasks.cancelledMarker')

    @headerRegex = /(.*):$/g
    @taskRegex = new RegExp "(.*)(#{marker})|(#{complete})|(#{cancelled})"

    @attributeRegex = /(@[ ]?(?:([\\w ]+)?(?:\\((.*?)\\))?))/gi
    @nonAttributeRegex = /[^@]+/

    super(registry, {name, scopeName})

module.exports = TaskGrammar
