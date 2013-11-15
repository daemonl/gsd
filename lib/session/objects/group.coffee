PathParser = require('../path_parser')

getEmailString = require("../../middleware/email").getEmailString

nodemailer = require("nodemailer")

# create reusable transport method (opens pool of SMTP connections)


class GroupSession

  activeUsers: {}

  constructor: (@config, @serialized, @db)->
    @pathParser = new PathParser(@config.model)
    @smtpTransport = false
    if @config.hasOwnProperty('email')
      @smtpTransport = nodemailer.createTransport("SMTP", @config.email.transport)
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
        collection.getIdentityString id, (err, identity)=>
          if err
            console.log(err)
            return
          @addHistory(user, action, collection.collectionName, id, changeset, identity)
        @emitChange(entity, id)


  delete: (user, entity, id, callback)=>
    console.log("DEL", entity, id)
    @db.getCollection entity, (err, collection)=>
      collection.getIdentityString id, (err, identity)=>
        if err
           return callback("Data object doesn't exist.")
        @db.delete entity, id, (err)=>
          return callback(err) if err
          @addHistory(user, "delete", collection.collectionName,  id, {}, identity)
          @emitDelete(entity, id)
          callback(null)

  sendEmail: (address, content)->

    return if !@smtpTransport

    lines = content.split("\n")
    subject = lines.shift()
    content = lines.join("\n")

    mailOptions =
      from: @config.email.from,
      to: address
      subject: subject
      text: ""
      html: content
    @smtpTransport.sendMail mailOptions, (error, response)->
      if(error)
          console.log(error);
      else
         console.log("Message sent: " + response.message)

  addHistory: (user, action, collectionName, entity_id, changeset, identity)=>
    console.log "ADDED HISTORY"

    if @config.hasOwnProperty('email')
      if @config.email.hasOwnProperty('hooks')
        for hook in @config.email.hooks
          console.log(hook)
          console.log(changeset)
          console.log(action)
          if (hook.collection is collectionName and
          (hook.triggerType is null or hook.triggerType is action) and
          (hook.triggerField is null or changeset.hasOwnProperty(hook.triggerField)))
            template = @config.email.templates[hook.template]
            getEmailString user, template, entity_id, (email, data)=>
              dp = hook.recipient.split(".")
              o = data
              for p in dp
                if o.hasOwnProperty(p)
                  o = o[p]
                else
                  o = {}
              recipient = o
              @sendEmail(recipient, email)

    @db.getCollection "history", (err, collection)=>
      if err
        console.log(err)
        return
      context = {}
      fields = 
        user: user.serialized.id
        identity: identity
        timestamp: new Date()
        action: action
        entity_id: entity_id
        entity: collectionName
        changeset: JSON.stringify(changeset)



      collection.insert context, fields, (err, escapedFields, returnedFields)=>
        if err 
          console.log(err)
          return
        for id,user of @activeUsers
          for socket in user.sockets
            emitFields =
              user:
                username: user.serialized.username
              identity: fields.identity
              timestamp: fields.timestamp.getTime()/1000
              action: fields.action
              entity: fields.entity
              entity_id: fields.entity_id

            socket.emit('history', emitFields)

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
