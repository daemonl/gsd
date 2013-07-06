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

  get: (user, entity, id, callback)=>
    @db.getCollection entity, (err, collection)->
      return callback(err) if err
      collection.findOneById id, callback

  list: (user, entity, conditions, callback)=>
    @db.getCollection entity, (err, collection)->
      return callback(err) if err
      collection.find(conditions, callback)


  set: (user, entity, id, changeset, callback)=>
    @db.getCollection entity, (err, collection)=>
      return callback(err) if err
      collection.updateOne id, changeset, (err, entity)=>
        return callback(err) if err
        callback(null, entity)
        @emitChange(entity, id, entity)
        





  #UNUSED:
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


  emitChange: (collection, pk, changeset)=>
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('update', collection, pk, changeset)

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
