
class UserSession

  group: null
  sockets: []

  constructor: (@serialized)->
    return @

  setGroup: (group)=>
    @group = group
    @group.addUser(@)

  addSocket: (socket)=>
    @sockets.push(socket)
    console.log("New Socket for User")
    socket.on 'get', @get
    socket.on 'set', @set
    socket.on 'do', @do


  get: (path, callback)=>
    try
      return @group.get(@, path, callback)
    catch e
      throw e
      console.log(e)
      null


  set: (path, value, callback)=>
    try
      return @group.set(@, path, value, callback)
    catch e
      null

  do: (path, params, callback)=>
    try
      return @group.do(@, path, params, callback)
    catch e
      null


module.exports = UserSession