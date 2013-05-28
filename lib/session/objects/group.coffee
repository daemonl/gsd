PathParser = require('../path_parser')


class GroupSession

  activeUsers: {}

  constructor: (@config, @serialized, @db)->
    @pathParser = new PathParser(@config.model)
    return @


  addUser: (user)=>
    @activeUsers[user.serialized._id] = user

  get: (user, path, callback)=>
    query = @pathParser.parse path, (err, parsed)=>
      if err
        console.log("ERR:", err)
        return callback(err, null)


      fields = []
      joins = []

      fieldMap = []

      aliasId = 0
      for k, t of parsed.tables
        t.aliasId = aliasId
        aliasId += 1

      for k, t of parsed.tables
        for field in t.fields
          fid = fieldMap.length
          mapLabel = t.mapLabel
          fieldMap.push({table: k, field: field, mapLabel: mapLabel})
          fields.push("t#{t.aliasId}.#{field} AS f#{fid}")
        if t.hasOwnProperty('join')
          parentAlias = parsed.tables[t.join.parent].aliasId
          joins.push("LEFT JOIN #{t.join.childTable} t#{t.aliasId} ON t#{t.aliasId}.#{t.join.childId} = t#{parentAlias}.#{t.join.parentId}")


      conditionStrings = []
      for c in parsed.conditions
        tableAlias = parsed.tables[c.tablePath].aliasId
        conditionStrings.push("t#{tableAlias}.#{c.field} #{c.compare} #{c.value}")

      sql = "SELECT #{fields.join(', ')} \n  FROM #{parsed.root.table} t0"
      if (joins.length)
        sql += "\n  #{joins.join('\n  ')}"

      if (conditionStrings.length)
        sql += "\n WHERE \n  #{conditionStrings.join('\n  AND  ')}"


      @db.query sql, (err, res)->
        if err or not res
          return callback("There was an error in the query. Probably our fault.", null)


        returnResults = []
        for row in res
          retob = {}
          for k, field of fieldMap
            currentObject = retob
            mapLabel = field.mapLabel.replace /\{f[0-9]*\}/g, (k)->
              return row[k.substring(1, k.length - 1)]

            for pathPart in mapLabel.split(".")
              if not currentObject.hasOwnProperty(pathPart)
                currentObject[pathPart] = {}
              currentObject = currentObject[pathPart]
            currentObject[field.field] = row['f'+k]
          returnResults.push(retob)


        callback(null, returnResults)

    #callback(null, query)

  set: (user, path, value, callback)=>
    @_traverse user, path, (err, object, parentObject, key)=>
      return callback(err) if err
      parentObject[key] = value

      @emitChange(path, value)

  do: (user, path, params, callback)=>


  emitChange: (path, value)=>
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('update', path, value)


module.exports = GroupSession
