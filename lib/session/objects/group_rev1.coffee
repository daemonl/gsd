PathParser = require('../path_parser')


walkPath = (path, obj)->
  obj = obj[0]
  #path = path.replace("]","")
  #path = path.replace("[", ".")

  parts = path.split(".")

  for part in parts
    if obj.hasOwnProperty(part)
      obj = obj[part]
    else
      char1 = part.substr(0, 1)
      if char1 is "*" or char1 is "("
        return obj
      else
        return null

  return obj



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

      sql = "SELECT #{fields.join(', ')} FROM #{parsed.root.table} t0"
      if (joins.length)
        sql += " #{joins.join('  ')}"

      if (conditionStrings.length)
        sql += " WHERE #{conditionStrings.join(' AND ')}"


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




        callback(null, returnResults, parsed)

    #callback(null, query)

  set: (user, path, values, callback)=>
    if values instanceof Object
      getIdPath = path + ".(id)"
    else
      pp = path.split(".")
      k = pp.pop()
      path = pp.join(".")
      value = values
      values = {}
      values[k] = value
      getIdPath = path + ".(id)"


    @get user, getIdPath, (err, response, parsed)=>
      if err
        console.log(err)
        return


      if response.length < 1
        return callback("Data object doesn't exist.")

      pk = walkPath(getIdPath, response)[parsed.final.pk]

      console.log("GET RETURN", pk, values)
      table = parsed.final
      fields = []

      for k,v of values
        if table.fields.hasOwnProperty(k)
          #TODO: ESCAPE PROPERLY!
          esc = v.replace("\"", "\\\"")
          fields.push("t0.#{k} = \"#{esc}\"")

      sql = "UPDATE #{parsed.final.table} t0 SET #{fields.join(", ")} WHERE #{parsed.final.pk} = #{pk};"

      @db.query sql, (err, res)=>
        return callback(err) if err

        @emitChange(path, values)
        return callback(null, res)

  create_new: (user, path, object, callback)=>
    @pathParser.parse path, (err, parsed)=>

      table = parsed.final

      childModels = []
      fields = []
      for k,v of object
        console.log(k)
        if table.fields.hasOwnProperty(k)

          field = table.fields[k]
          if field.type is "model"
            childModels.push {
              field: k
              value: v
              path: path + "." + k
            }

          else
            #TODO: ESCAPE PROPERLY!

            esc = (""+v).replace("\"", "\\\"")
            fields.push("#{k} = \"#{esc}\"")
      console.log("N")

      doModelField = (field)=>
        if field is undefined

          fields.push("#{parsed.final.pk} = NULL")

          sql = "INSERT INTO #{parsed.final.table} SET #{fields.join(", ")};"
          console.log("SQL:", sql)

          @db.query sql, (err, res)=>
            return callback(err) if err
            @emitCreate(path, res.insertId, object)

            return callback(null, res)
        else

          @create_new user, field.path, field.value, (err, res)=>

            id = res.insertId
            #[Parent Object Fields].push [Field's fieldname in object] = [insert id]
            fields.push("#{field.field} = \"#{id}\"")

            doModelField(childModels.shift())

      doModelField(childModels.shift())


  delete: (user, path, callback)=>
    getIdPath = path + ".(id)"
    @get user, getIdPath, (err, response, parsed)=>

      if response.length < 1
        return callback("Data object doesn't exist.")

      pk = walkPath(getIdPath, response)[parsed.final.pk]
      table = parsed.final

      sql = "DELETE FROM #{parsed.final.table} WHERE #{parsed.final.pk} = #{pk};"
      @db.query sql, (err, res)=>
        return callback(err) if err
        @emitDelete(path)
        return callback(null, res)

  do: (user, path, params, callback)=>


  emitChange: (path, value)=>
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('update', path, value)

  emitCreate: (path, insertid, object)=>
    if not object
      object = {}
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('create', path, insertid, object)

  emitDelete: (path)=>
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('delete', path)

module.exports = GroupSession
