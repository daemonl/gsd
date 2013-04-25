class GroupSession

  activeUsers: {}

  constructor: (@config, @serialized, @db)->
    return @


  addUser: (user)=>
    @activeUsers[user.serialized._id] = user

  getQuery: (user, path)=>
    # match table[id]
    exp = /([a-zA-Z_][a-zA-Z0-9_]*)(\[([0-9]*|\'.*\')\])?/

    selectParts = []
    whereConditions = []
    joins = []
    fromDef = null
    tn = 0

    for p in path.split('.').reverse()
      r = exp.exec(p)
      tableName = r[1]
      key = false
      if r[2] isnt undefined
        key = r[3]
        # quote non numeric keys
        # if parseInt(key) isnt key
        key = "'#{key}'"



      if @config.model.hasOwnProperty(tableName)
        table = @config.model[tableName]
        if fromDef is null
          fromDef = "#{table.table} t#{tn}"
          selectParts.push("t#{tn}.*")
          # Focus Entity

          if key isnt false
            whereConditions.push("t#{tn}.#{table.pk} = #{key}")
        else
          join = "INNER JOIN #{table.table} t#{tn} ON t#{tn}.#{table.pk} = t#{tn-1}.#{table.pk}"
          if key isnt false
            join += " AND t#{tn}.#{table.pk} = #{key}"
          joins.push(join)
        tn += 1

    user_id = user.serialized.id
    group_id = @serialized.id
    whereConditions.push("(t#{tn-1}.user_id = #{user_id} OR t#{tn-1}.user_id IS NULL AND t#{tn-1}.group_id = #{group_id})")

    query = "SELECT #{selectParts.join(',')} FROM #{fromDef} "
    query += joins.join(" ")
    if whereConditions.length
      query += " WHERE " + whereConditions.join(" AND ")
    return query

  _traverse: (user, path, callback)=>
    if not path
      return callback("Path must be specified")
    pathParts = path.split(".")

    model = @config.model

    query = ""

    for part in pathParts
      sp = part.split('[')
      table = ''
      id = null
      if sp.length is 1
        table = sp[0]
      if sp.length is 2
        table = sp[0]
        id = sp[1].substring(0, sp[1].length - 1)
      console.log("A", table, id)



    callback(null, null, null, query)

  get: (user, path, callback)=>
    query = @getQuery(user, path)
    callback(null, query)

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
