moment = require('moment')
baseTypes = {}

baseTypes.base = {
  toDb: (val)->
    return val
  fromDb: (val)->
    return val
}

baseTypes.int =
  toDb: (val)->
    return null if val is null or val is undefined or val.length < 1
    return val/1
  fromDb: (val)->
    return null if val is null or val is undefined or val.length < 1
    return val


baseTypes.datetime =
  toDb: (val)->
    if ""+val/1 is ""+val
      return moment(val*1000).format("X")/1
    return moment(val).format("X")/1

  fromDb: (val)->
    if ""+val/1 is ""+val
      return moment(val*1000).format("X")
    return val
baseTypes.date =
  toDb: (val)->
    if ""+val.length < 1
      return null
    return moment(val).format("YYYY-MM-DD")

  fromDb: (val)->
    if ""+val.length < 1
      return null
    return moment(val).format("YYYY-MM-DD")

dataTypes = {
  gid: baseTypes.base
  id: baseTypes.int
  ref: baseTypes.int
  datetime: baseTypes.datetime
  date: baseTypes.date
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
