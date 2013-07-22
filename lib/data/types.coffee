baseTypes = {}

baseTypes.base = {
  toDb: (val)->
    return val
  fromDb: (val)->
    return val
}

baseTypes.int =
  toDb: (val)->
    return null if val is null or val.length < 1
    return val/1
  fromDb: (val)->
    return null if val is null or val.length < 1
    return val




dataTypes = {
  gid: baseTypes.base
  id: baseTypes.int
  ref: baseTypes.int
  datetime: baseTypes.base
  string: baseTypes.base
  text: baseTypes.base
  address: baseTypes.base
  enum: baseTypes.base
  auto_timestamp: baseTypes.base
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
