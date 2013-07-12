GroupSession = require('./objects/group')
UserSession = require('./objects/user')

###
  Responsible for managing user and group sessions, serializing to the database, and hidrating.
###
class SessionRepository

  userSessions: {}
  groupSessions: {}

  constructor: (@config, @db)->
    null

  getUserSession: (userId, callback)=>
    # Check for an active session
    if @userSessions.hasOwnProperty(userId)
      callback(null, @userSessions[userId])
      return

    # Create a new session for the user
    @hidrateUserSession userId, (err, userSession)=>
      return callback(err) if err
      callback(null, userSession)


  getGroupSession: (groupId, callback)=>
    # Check for an active session
    
    if @groupSessions.hasOwnProperty(groupId)
      callback(null, @groupSessions[groupId])
      return

    @hidrateGroupSession groupId, (err, groupSession)=>
      return callback(err) if err
      callback(null, groupSession)


  hidrateUserSession: (session, callback)=>

    # Create a new User Session Object from the serialized class
    @db.getEntity @config.security.userTable, {pk: session.user, fieldset: "login"}, (err, serialized)=>
      return callback(err) if err
      return callback("User #{session.user} not found") if not serialized
      userSession = new UserSession(serialized, session)
      if userSession is false
        callback("Serialized user session was invalid.")
      else
        @userSessions[serialized.id] = userSession
        callback(null, userSession)

  hidrateGroupSession: (groupId, callback)=>
    # Create a new Group Session Object from the serialized class
    if not @config.security.groupTable
      groupSession = new GroupSession(@config, {id: 1}, @db)
      @groupSessions[1] = groupSession
      console.log("Created null group session - config.security.groupTable was null")
      callback(null, groupSession)
    else
      @db.getEntity @config.security.groupTable, groupId, (err, serialized)=>
        return callback(err) if err
        if serialized is null
          callback("No Serialized Group Found")
          return
        groupSession = new GroupSession(@config, serialized, @db)
        if groupSession is false
          callback("Serialized group session was invalid.")
        else
          @groupSessions[serialized.id] = groupSession
          callback(null, groupSession)


module.exports = SessionRepository
