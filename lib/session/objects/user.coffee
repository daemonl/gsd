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
    console.log("New Socket for User")
    socket.on 'get', @get
    socket.on 'getChoicesFor', @getChoicesFor
    socket.on 'list', @list
    socket.on 'set', @set
    socket.on 'create', @create_new
    socket.on 'delete', @delete
    socket.on 'do', @do
    socket.on 'heartbeat', ()=>


      @session.last = new Moment().format("YYYY-MM-DDTHH:mm:ss")
      @group.db.update @config.security.sessionTable, {id: @session.id}, @session, (err, res)=>
        console.log(err) if err
        console.log("Saved Session")



  get: (collection, id, fieldset, callback)=>
    console.log("GET", collection, id)
    try
      @group.get @, collection, id, fieldset, (err, entity)->
        callback(err, entity)
        throw err if err
    catch e
      console.error(e)
      callback("An unknown error occurred")

  getChoicesFor: (collection, id, field, search, callback)=>
    try
      @group.getChoicesFor @, collection, id, field, search, callback
    catch e
      console.error(e)
      callback("An unknown error occurred")

    


  list: (collection, query, callback)=>
    console.log("LIST", collection, query)
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
