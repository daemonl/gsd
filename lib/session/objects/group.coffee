PathParser = require('../path_parser')


class GroupSession

  activeUsers: {}

  constructor: (@config, @serialized, @db)->
    @pathParser = new PathParser(@config.model)
    return @

  addUser: (user)=>
    @activeUsers[user.serialized.id] = user

  getContext: (user)->
    parameters =
      user: user.serialized.id
      group: @serialized.id
 
  get: (user, entity, id, fieldset, callback)=>
    context = @getContext(user)
    @db.getCollection entity, (err, collection)->
      return callback(err) if err
      collection.findOneById context, id, fieldset, callback

  getChoicesFor: (user, entity, id, field, search, callback)=>
    context = @getContext(user)
    @db.getCollection entity, (err, collection)->
      return callback(err) if err
      collection.getChoicesFor context, id, field, search, callback

  list: (user, entity, conditions, callback)=>
    context = @getContext(user)
    @db.getCollection entity, (err, collection)->
      return callback(err) if err
      collection.find context, conditions, callback

  set: (user, entity, id, changeset, callback)=>
    isCreate = if id is null or id is 'null' or not id then true else false
    context = @getContext(user)
    @db.getCollection entity, (err, collection)=>
      return callback(err) if err
      collection.updateOne context, id, changeset, (err, savedEntity)=>
        return callback(err) if err
        id = savedEntity[collection.pk]
        callback(null, savedEntity)
        action = if isCreate then "create" else "edit"
        @addHistory(user, action, collection.collectionName,  id, changeset)
        @emitChange(entity, id)


  delete: (user, entity, id, callback)=>
    console.log("DEL", entity, id)
    @get user, entity, id, (err, response, parsed)=>
      if response.length < 1
        return callback("Data object doesn't exist.")
      console.log("DELETE ", entity, id)
      @db.delete entity, id, (err)=>
        return callback(err) if err
        @addHistory(user, "delete", collection.collectionName,  id, {})
        @emitDelete(entity, id)
        callback(null)


  addHistory: (user, action, collectionName, entity_id, changeset)=>
    console.log "ADDED HISTORY"    
    @db.getCollection "history", (err, collection)=>
      if err
        console.log(err)
        return
      context = {}
      fields = 
        user: user.serialized.id
        timestamp: new Date()
        action: action
        entity_id: entity_id
        entity: collectionName
        changeset: JSON.stringify(changeset)

      collection.insert context, fields, (err)=>
        if err 
          console.log(err)
        console.log "ADDED HISTORY"
        null

  emitChange: (collection, pk)=>
    console.log("CHANGE")
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('update', collection, pk)

  emitCreate: (collection, id)=>
    if not object
      object = {}
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('create', collection, id)

  emitDelete: (collection, pk)=>
    for id,user of @activeUsers
      for socket in user.sockets
        socket.emit('delete', collection, pk)

module.exports = GroupSession
