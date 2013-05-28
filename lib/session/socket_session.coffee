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
      console.log(data.headers)
      return accept('Session cookie required for authentication', false)

    data.signedCookies = connect.utils.parseSignedCookies(cookie.parse(decodeURIComponent(headerCookie)), @config.security.siteSecret)

    data.sessionCookie = data.signedCookies[@config.security.sessionCookie]

    @db.getEntity @config.security.sessionTable, {id: data.sessionCookie}, (err, session)=>
      return accept(err, false) if err

      console.log("Session Found:", {id: data.sessionCookie}, session)

      if (session and session.user and session.group)
        data.session = session
        # To get here, req.session exists, is valid, and has a user.
        @sessionRepository.getUserSession data.session.user, (err, userSession)=>
          return accept(err, false) if err
          @sessionRepository.getGroupSession data.session.group, (err, groupSession)=>
            return accept(err, false) if err
            data.sessionUser = userSession
            userSession.setGroup(groupSession)
            data.sessionGroup = groupSession
            console.log("Accept socket session with user and group")
            accept(null, true)



module.exports = SocketSession