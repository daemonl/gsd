Moment = require("moment")
class UserSession

  group: null
  sockets: []

  constructor: (@serialized, @session)->
    return @

  setGroup: (group)=>
    @group = group
    @config = @group.config
    @group.addUser(@)

  addSocket: (socket)=>
    @sockets.push(socket)
    socket.on 'get', @get
    socket.on 'getChoicesFor', @getChoicesFor
    socket.on 'list', @list
    socket.on 'set', @set
    socket.on 'create', @create_new
    socket.on 'delete', @delete
    socket.on 'do', @do
    socket.on 'heartbeat', ()=>
      @session.last = new Moment().format("YYYY-MM-DDTHH:mm:ss")
      changeset =
        last: @session.last
      @group.db.update @config.security.sessionTable, {fieldset: 'application', id: @session.id}, changeset, (err, res)=>
        console.log(err) if err
        console.log("Saved Session #{@serialized.username}")
    socket.emit 'whoami', @serialized



  get: (collection, id, fieldset, callback)=>
    console.log("#{@serialized.username} get", collection, fieldset, id)
    try
      @group.get @, collection, id, fieldset, (err, entity)->
        callback(err, entity)

        throw err if err
    catch e
      console.error(e)
      callback("An unknown error occurred")

  getChoicesFor: (collection, id, field, search, callback)=>
    console.log("#{@serialized.username} - getChoicesFor",  collection, id, field, search)
    try
      @group.getChoicesFor @, collection, id, field, search, (err, list)->
        #console.log(list)
        callback(err, list)
    catch e
      console.error(e)
      callback("An unknown error occurred")

    


  list: (collection, query, callback)=>
    console.log("#{@serialized.username} list", collection, query)
    try
      return @group.list(@, collection, query, callback)
    catch e
      callback e
      null


  set: (collection, id, changeset, callback = null)=>
    console.log("SET", collection, id, changeset, callback)
    if callback is null
      callback = ()->
        null
    try
      return @group.set(@, collection, id, changeset, callback)
    catch e
      throw e
      #callback(e)
      null

  create_new: (path, value, callback)=>
    if not callback
      callback = ()->
        null
    try
      return @group.create_new(@, path, value, callback)
    catch e
      console.error(e)
      callback("An unknown error occurred")
      null

  delete: (collection, id, callback)=>
    if not callback
      callback = ()->
        null
    try
      return @group.delete(@, collection, id, callback)
    catch e
      null

  do: (path, params, callback)=>
    if not callback
      callback = ()->
        null
    try
      return @group.do(@, path, params, callback)
    catch e
      null


module.exports = UserSession
