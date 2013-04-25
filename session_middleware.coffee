cookie = require('cookie')
signature = require('cookie-signature')
Moment = require('moment')

class SessionMiddleware

  constructor: (@config, @sessionRepository, @db)->
    @sessions = {}

  loginUrl: "/login"
  loginTargetUrl: "/app"

  sendError: (req, res, err)=>
    console.log("E", err)
    res.send(500, "An error occurred setting up your session")

  middleware: (req, res, next)=>

    # Login Paths:
    loginPaths = [
      {path: '/login', methods: ['POST'], handler: @handlePostLogin}
      {path: '/signup', methods: ['POST'], handler: @handlePostSignup}
      {path: '/logout', methods: ['GET', 'POST'], handler: @handleLogout}
    ]

    #Make sure req.session is a valid session
    @ensureSession req, res, (err)=>
      return @sendError(req, res, err) if err

      # add a req.session object from the valid session
      @hidrateSession req, res, (err)=>
        return @sendError(req, res, err) if err

        # If the path/method should change / check the session:
        for path in loginPaths
          if req._parsedUrl.path is path.path and req.method in path.methods
            return path.handler(req, res)

        # If it is a public URL (After the first one, because LOGIN is public
        if req._parsedUrl.path in @config.security.publicUrls and req.method is "GET"
          return next()

        # If the user is logged in:
        if req.sessionUser and req.sessionGroup
          # Exclude paths which will fail for logged in users
          if req._parsedUrl.path in ['/login', '/signup']
            return res.redirect(@loginTargetUrl)
          else
            # Pass on
            next()
        else
          # No user, and the URL is not public.
          return res.redirect @loginUrl

  #Make sure req.session is a valid session, creating a new one if not.
  ensureSession: (req, res, callback)=>

    #Get the cookie from the request, if any
    cookies = req.signedCookies
    req.sessionCookie = cookies[@config.security.sessionCookie]

    # If there is no cookie, shortcut the database lookup
    if not req.sessionCookie
      return @generateSession req, res, callback


    # Check the database for a valid session
    @db.getEntity @config.security.sessionTable, {id: (req.sessionCookie)}, (err, session)=>
      return @sendError(req, res, err) if err

      # If the session matched
      if (session)
        lastUse = new Moment(session.last)
        now = new Moment()
        diff = now.diff(lastUse, "minutes")

        if diff < 5
          req.session = session
          req.session_in_database = {}
          for k,v of session
            req.session_in_database[k] = v
          return callback()

      # Otherwise Generate a new one.
      return @generateSession req, res, callback


  handlePostLogin: (req, res)=>
    if not(req.body and req.body.hasOwnProperty('username') and req.body.hasOwnProperty('password') and req.body.username)
      req.addFlash "error", "Please enter a username and password", ()=>
        return res.redirect(@loginUrl)
      return

    username = req.body.username
    password = req.body.password

    console.log("Login With: ", username, password)

    searchParams = {}
    searchParams[@config.security.user.username] = username

    @db.getEntity @config.security.userTable, searchParams, (err, user)=>
      return @sendError(req, res, err+"AA") if err
      if not user
        req.addFlash "error", "The username or password you entered is incorrect", ()=>
        return res.redirect(@loginUrl)
      # If Password was valid
      console.log("LOGIN SUCCESS - This Function is not complete.", user)
      req.session.user = user.id
      console.log(@config.security.groupTable)
      groupCol = @config.model[@config.security.groupTable].pk
      console.log("GC", groupCol, user[groupCol])
      req.session.group = user[groupCol]
      @hidrateSession req, res, ()=>
        res.redirect(@loginTargetUrl)

  handleLogout: (req, res)=>
    req.session.user = null
    req.session.group = null
    @generateSession req, res, ()->
      res.redirect("/")


  handlePostSignup: (req, res)=>
    null


  generateSession: (req, res, callback)=>
    # Generate a database session
    @db.getCollection @config.security.sessionTable, (err, sessionCollection)=>
      return @sendError(req, res, err) if err
      serializedSession = {}
      sessionCollection.insert serializedSession, (err, result)=>
        return callback(err) if err
        req.session = result
        req.session_in_database = {}
        for k,v of req.session
          req.session_in_database[k] = v
        val = ""+req.session.id
        val = 's:' + signature.sign(val, @config.security.siteSecret);
        val = cookie.serialize(@config.security.sessionCookie, val);
        res.setHeader('Set-Cookie', val);
        # Then do some cookie things...
        callback()

  # Called only when request has a valid session
  # Should only call next when req has a valid usersession and groupsession
  hidrateSession: (req, res, next)=>
    origEnd = res.end
    res.end = (content)=>
      req.session.last = new Moment().format("YYYY-MM-DDTHH:mm:ss")

      @db.getCollection @config.security.sessionTable, (err, sessionCollection)=>
        if err
          console.log(err)
          origEnd()
        sessionCollection.update {id: req.session.id}, req.session, (err)=>
          if err
            console.log(err)
          return origEnd.call(res, content)


    if not (req.session.user and req.session.group)
      return next()

    @sessionRepository.getUserSession req.session.user, (err, userSession)=>
      return @sendError(req, res, err) if err
      @sessionRepository.getGroupSession req.session.group, (err, groupSession)=>
        return @sendError(req, res, err) if err
        req.sessionUser = userSession
        userSession.setGroup(groupSession)
        req.sessionGroup = groupSession
        next()

module.exports = SessionMiddleware