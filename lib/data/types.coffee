baseTypes = {}

baseTypes.base = {
  toDb: (val)->
    return val
  fromDb: (val)->
    return val
}

dataTypes = {
  gid: baseTypes.base
  id: baseTypes.base
  ref: baseTypes.base
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
