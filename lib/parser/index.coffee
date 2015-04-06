# Actual parser code:
#   Setup the base function
#   and export it with the other classes
Node = require './node'
Tag = require './tag'


tl = atom.config.get 'editor.tabLength'
# Needs to be able to update indentation values for each line
# when changed
getIndentationForLine = (line)->
  indent = /(\s)*/.exec(line)
  return 0 if !indent or !indent[0]
  indent[0].length / tl

parseContent = (lines, node, editor, indentation = 0)->
  parentCursor = node
  lastCursor = node

  for line, i in lines
    lineIndent = getIndentationForLine line
    tempNode = new Node line, lineIndent, editor, i

    if lineIndent > parentCursor.indentation + 1
      parentCursor = lastCursor
    if lineIndent <= parentCursor.indentation
      # TODO: Fix for more than one indentation level drop
      parentCursor = parentCursor.parent
    if lineIndent is parentCursor.indentation + 1
      parentCursor.addItem tempNode
    lastCursor = tempNode

  node

parser = (textEditor)->
  rootNode = new Node 'root', -1, textEditor, -1
  lines = textEditor.buffer.lines

  parseContent lines, rootNode, textEditor

module.exports =
  Node: Node
  Tag: Tag
  parse: parser
