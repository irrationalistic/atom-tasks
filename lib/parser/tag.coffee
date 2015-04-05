ATTRIBUTE_RX = /(@[ ]?(([\w]+) ?(\((.*?)\))?))/gi

class Tag
  constructor: (@editor, @name, @value)->

  markRange: (range)->
    @marker.destroy() if @marker
    @marker = @editor.buffer.markRange range

  update: ()->
    txt = @editor.buffer.getTextInRange @marker.getRange()
    match = ATTRIBUTE_RX.exec txt
    if match
      @name = match[3]
      @value = match[5]

  toString: ()->
    "@#{@name}(#{@value})"

  remove: ()->
    @editor.buffer.delete @marker.getRange()
    @marker.destroy()

  destroy: ()->
    @marker.destroy()

module.exports = Tag
