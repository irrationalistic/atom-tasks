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
    # TODO: on removing a tag, check to see
    # if there is extraneous white-space on both
    # sides. If so, remove one of the spaces
    @editor.buffer.delete @marker.getRange()
    @marker.destroy()

  destroy: ()->
    @marker.destroy() if @marker

module.exports = Tag
