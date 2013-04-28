
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
    return @group.get(@, path, callback)

  set: (path, value, callback)=>
    return @group.set(@, path, value, callback)

  do: (path, params, callback)=>
    return @group.do(@, path, params, callback)


module.exports = UserSession