moment = require('moment')
scrypt = require("scrypt")
baseTypes = {}

baseTypes.base =
  toDb: (val, callback)->
    process.nextTick ()->
      callback(null, val)

  fromDb: (val, callback)->
    process.nextTick ()->
      callback(null, val)

baseTypes.int =
  toDb: (val, callback)->
    process.nextTick ()->
      if val is null or val is undefined or val.length < 1
        return callback(null, null)
      return callback(null, val/1)
    
  fromDb: (val, callback)->
    process.nextTick ()->
      return callback(null, null) if val is null or val is undefined or val.length < 1
      return callback(null, val/1)

baseTypes.datetime =
  toDb: (val, callback)->
    process.nextTick ()->
      if ""+val/1 is ""+val
        return callback(null, moment(val*1000).format("X")/1)
      return callback(null, moment(val).format("X")/1)

  fromDb: (val, callback)->
    process.nextTick ()->
      if ""+val/1 is ""+val
        return callback(null, moment(val*1000).format("X"))
      return callback(null, val)

baseTypes.date =
  toDb: (val, callback)->
    process.nextTick ()->
      return callback(null, null) if (""+val).length < 1
      return callback(null, moment(val).format("YYYY-MM-DD"))

  fromDb: (val, callback)->
    process.nextTick ()->
      return callback(null, null) if (""+val).length < 1
      m = moment(val)
      return callback(null, null) if m is null
      return callback(null, m.format("YYYY-MM-DD"))
  
baseTypes.password =
  toDb: (val, callback)->
    scrypt.passwordHash val, 0.1, (err, pwdhash)->
      callback(err, pwdhash)
   
  fromDb: (val, callback)->
    process.nextTick ()->
      return callback(null, "----")

baseTypes.array =
  toDb: (val, callback)->
    process.nextTick ()->
      callback(null, JSON.stringify(val))

  fromDb: (val, callback)->
    process.nextTick ()->
      try
        obj = JSON.parse(val)
        if obj is null
          return callback(null, [])
        return callback(null, obj)
      catch e
        callback(e)

baseTypes.file =
  toDb: (val, callback)->
    process.nextTick ()->
      callback(null, val)

  fromDb: (val, callback)->
    process.nextTick ()->
      callback(null, val)

dataTypes = {
  gid: baseTypes.base
  id: baseTypes.int
  int: baseTypes.int
  ref: baseTypes.int
  datetime: baseTypes.datetime
  date: baseTypes.date
  string: baseTypes.base
  text: baseTypes.base
  password: baseTypes.password
  address: baseTypes.base
  enum: baseTypes.base
  auto_timestamp: baseTypes.base
  array: baseTypes.array
  file: baseTypes.file
}

module.exports = dataTypes
