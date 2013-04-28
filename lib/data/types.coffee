dataTypes = {
  gid: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  id: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  ref: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  datetime: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  string: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  array: {
    toDb: (val)->
      return JSON.stringify(val)
    fromDb: (val)->
      v =  JSON.parse(val)
      if v is null
        return []
      return v
  }
}

module.exports = dataTypes