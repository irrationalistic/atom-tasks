{$} = require 'atom'
# TODO: This should be
#  {Grammar} = require "first-mate"
# but doing so throws "Error: Cannot find module 'first-mate'"
Grammar = require atom.config.resourcePath + "/node_modules/first-mate/lib/grammar.js"

class TaskGrammar extends Grammar
  constructor: (registry) ->
    console.log 'test'
    name = "Tasks"
    scopeName = "source.todo"

    marker = atom.config.get('tasks.taskMarker')
    complete = atom.config.get('tasks.completeMarker')
    cancelled = atom.config.get('tasks.cancelledMarker')

    @headerRegex = /(.*):$/g
    @taskRegex = new RegExp "(.*)(#{marker})|(#{complete})|(#{cancelled})"

    @attributeRegex = /(@[ ]?(?:([\\w ]+)?(?:\\((.*?)\\))?))/gi
    @nonAttributeRegex = /[^@]+/

    ###
    @regexMap = [
      regex: /(.*):$/g
      match: '.header'
    ,
      regex: new RegExp(, 'gi')
      match: '.marker'
    ,
      regex: new RegExp(, 'gi')
      match: '.marker.complete'
    ,
      regex: new RegExp(, 'gi')
      match: '.marker.cancelled'
    ,
      regex: /@[ ]?(?:([\\w ]+)?(?:\\((.*?)\\))?)/gi
      match: '.attribute'
    ]
    ###
    super(registry, {name, scopeName})
###
  tokenizeLine: (line, ruleStack, firstLine = false)->
    # console.log line, ruleStack, firstLine
    tokens = []
    if ruleStack?
      ruleStack = ruleStack.slice()
    else
      ruleStack = [@getInitialRule()]

    registry = @registry
    addToken = (text, start, end, scopes = null)->
      if text
        token = registry.createToken text, ['source.tasks' + (if scopes? then ("." + scopes) else "")]
        token.charstart = start
        token.charend = end
        tokens.push token

    # regex the crap out of this line!
    if @headerRegex.test line
      addToken line, 0, line.length-1, '.header'
    else if @taskRegex.test line
      line.replace @taskRegex, (text, spacing, marker, complete, cancelled, ind)->
        # console.log arguments
        s = 0
        if spacing
          e = spacing.length - 1
        else
          e = 1
        addToken spacing, s, e, '.text'
        s = e
        e = s + 1
        # console.log s, e
        addToken marker, s,e, '.marker'
        addToken complete, s,e, '.marker.complete'
        addToken cancelled, s,e, '.marker.cancelled'
      line.replace @attributeRegex, (match, matches...)->
        ind = matches[4]
        # console.log arguments
        addToken match, ind, ind + match.length - 1, '.attribute'
      # line.replace @nonAttributeRegex, (match, matches...)->
      #   console.log matches
      #   addToken match, 0, 0, '.text'
    console.log tokens
    tokens = tokens.sort (a,b)-> a.charstart - b.charstart
    console.log tokens
    s = 0
    e = 0
    for token in tokens
      e = token.charstart
      # console.log token
      if e - s > 0
        # console.log line.substr(s, e), s, e
        addToken line.substr(s, e), s, e, '.text'
      s = token.charend + 1
    # addToken line, 'test'
    # console.log tokens
    e = line.length-1
    addToken line.substr(s, e), s,e, '.text'
    tokens = tokens.sort (a,b)-> a.charstart - b.charstart
    return {tokens: tokens, ruleStack: ruleStack}
###
module.exports = TaskGrammar
