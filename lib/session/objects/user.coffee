
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
    socket.on 'list', @list
    socket.on 'set', @set
    socket.on 'create', @create_new
    socket.on 'delete', @delete
    socket.on 'do', @do
    socket.on 'heartbeat', ()=>

      @group.db.update @config.security.sessionTable, {id: @session.id}, @session, (err, res)=>
        console.log(err) if err
        console.log("Saved Session")



  get: (collection, id, callback)=>
    console.log("GET", collection, id)
    try
      @group.get @, collection, id, (err, entity)->
        callback(err, entity)
        throw err if err


    catch e
      throw e
      null

  list: (collection, query, callback)=>
    console.log("LIST", collection, query)
    try
      return @group.list(@, collection, query, callback)
    catch e
      throw e
      null


  set: (collection, id, changeset, callback)=>
    console.log("SET", collection, id, changeset)
    if not callback
      callback = ()->
        null
    try
      return @group.set(@, collection, id, changeset, callback)
    catch e
      throw e
      null

  create_new: (path, value, callback)=>
    if not callback
      callback = ()->
        null
    try
      return @group.create_new(@, path, value, callback)
    catch e
      throw e
      null

  delete: (path, value, callback)=>
    if not callback
      callback = ()->
        null
    try
      return @group.delete(@, path, callback)
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