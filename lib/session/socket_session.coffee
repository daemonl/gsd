connect = require("connect")
cookie = require("cookie")


class SocketSession
  constructor: (@config, @sessionRepository, @db)->

  bindSocket: (io)=>
    io.set('authorization', @socketHandshake)
    io.on 'connection', (socket)=>
      hs = socket.handshake
      hs.sessionUser.addSocket(socket)

  socketHandshake: (data, accept)=>
    headerCookie = null
    if data.headers.cookie
      headerCookie = data.headers.cookie
    else if data.headers.cookietest
      headerCookie = data.headers.cookietest
    else
      return accept('Session cookie required for authentication', false)

    data.signedCookies = connect.utils.parseSignedCookies(cookie.parse(decodeURIComponent(headerCookie)), @config.security.siteSecret)

    data.sessionCookie = data.signedCookies[@config.security.sessionCookie]
    @db.getEntity @config.security.sessionTable, {id: data.sessionCookie}, (err, session)=>
      return accept(err, false) if err
      return accept(null, false) if not session


      if @config.security.groupTable is null
        session.group = 1

      

      if (session and session.user and session.group)
        data.session = session
        # To get here, req.session exists, is valid, and has a user.
        @sessionRepository.getUserSession data.session, (err, userSession)=>
          return accept(err, false) if err
          @sessionRepository.getGroupSession data.session.group, (err, groupSession)=>
            return accept(err, false) if err
            data.sessionUser = userSession
            userSession.setGroup(groupSession)
            data.sessionGroup = groupSession
            console.log("Socked Handshake Accepted. Session #{data.sessionCookie}, User '#{userSession.serialized.username}'")
            accept(null, true)
      else
        console.log("Socked Handshake Rejected. Session id #{data.sessionCookie}")
        console.log(session)
        accept(null, false)



module.exports = SocketSession
