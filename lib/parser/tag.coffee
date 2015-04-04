class Tag
  constructor: (@name, @value)->

  toString: ()->
    "@#{@name}(#{@value})"
module.exports = Tag
