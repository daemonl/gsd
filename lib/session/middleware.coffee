cookie = require('cookie')
signature = require('cookie-signature')
Moment = require('moment')
scrypt = require('scrypt')

class SessionMiddleware

  constructor: (@config, @sessionRepository, @db)->
    @sessions = {}
    @config.security.publicUrls.push(@config.security.paths.login)
    @config.security.publicUrls.push(@config.security.paths.signup)

    @loginPaths = [
      {path: @config.security.paths.login,  methods: ['POST'], handler: @handlePostLogin}
      {path: @config.security.paths.signup, methods: ['POST'], handler: @handlePostSignup}
      {path: @config.security.paths.logout, methods: ['GET', 'POST'], handler: @handleLogout}
    ]

  sendError: (req, res, err)=>
    console.log("SECURITY ERROR:", err)
    res.send(500, @config.security.messages.unknownError)

  middleware: (req, res, next)=>
    middleware = @


    #Make sure req.session is a valid session
    @ensureSession req, res, (err)->
      return middleware.sendError(req, res, err) if err

      # add a req.session object from the valid session
      middleware.hidrateSession req, res, (err)->
        return middleware.sendError(req, res, err) if err

        # If the path/method should change / check the session:
        for path in middleware.loginPaths
          if req._parsedUrl.path is path.path and req.method in path.methods
            return path.handler(req, res)

        # If it is a public URL (After the first one, because LOGIN is public
        if req._parsedUrl.path in middleware.config.security.publicUrls and req.method is "GET"
          return next()

        # If the user is logged in:
        if req.sessionUser and req.sessionGroup
          next()
        else
          # No user, and the URL is not public.
          req.addFlash "danger", middleware.config.security.messages.notLoggedIn, ()->
            return res.redirect middleware.config.security.paths.login

  #Make sure req.session is a valid session, creating a new one if not.
  ensureSession: (req, res, callback)=>

    #Get the cookie from the request, if any
    cookies = req.signedCookies
    req.sessionCookie = cookies[@config.security.sessionCookie]

    # If there is no cookie, shortcut the database lookup
    if not req.sessionCookie
      return @generateSession req, res, callback


    # Check the database for a valid session
    @db.getEntity @config.security.sessionTable, {id: (req.sessionCookie), fieldset: "application"}, (err, session)=>
      return @sendError(req, res, err) if err

      # If the session matched
      if (session)
        lastUse = new Moment(session.last * 1000)
        now = new Moment()
        console.log lastUse.format("YYYY-DD-MM hh-mm-ss")
        diff = now.diff(lastUse, "minutes")

        if diff < 5
          req.session = {}
          req.session.id = session.id
          req.session.user = session.user
          req.session.flash = session.flash
          if @config.security.groupTable isnt null
            req.session.group = session.group
          else
            req.session.group = 1
          req.session_in_database = {}
          for k,v of session
            req.session_in_database[k] = v
          if req.session.groupTable is null
            session.group = 1
          return callback()

      # Otherwise Generate a new one.
      return @generateSession req, res, callback


  handlePostLogin: (req, res)=>
    if not(req.body and req.body.hasOwnProperty('username') and req.body.hasOwnProperty('password') and req.body.username)
      req.addFlash "danger", @config.security.messages.incompleteLogin, ()=>
        return res.redirect(@config.security.paths.login)
      return

    username = req.body.username
    password = req.body.password

    esc_username = username.replace(/[^a-zA-Z0-9_@\-]/g, "_")


    @db.query "SELECT * FROM #{@config.security.userTable} WHERE #{@config.security.user.username} = '#{esc_username}' LIMIT 1", (err, users)=>
      return @sendError(req, res, err) if err

      if users.length < 1
        req.addFlash "danger", @config.security.messages.invalidLogin, ()=>
        return res.redirect(@config.security.paths.login)
      user = users[0]

      scrypt.verifyHash user[@config.security.user.password], password, (err, result)=>
        if err or result is false
          req.addFlash "danger", @config.security.messages.invalidLogin, ()=>
          return res.redirect(@config.security.paths.login)

        console.log("USER VERIFIED")
        # If Password was valid
        @generateSession req, res, ()=>
          req.session.user = user.id

          if @config.security.groupTable isnt null

            groupCol = @config.model[@config.security.groupTable].pk
            req.session.group = user[groupCol]
          else
            req.session.group = 1

          @hidrateSession req, res, ()=>
            console.log("SESSION HIDRATED")
            res.redirect(@config.security.paths.target)

  handleLogout: (req, res)=>
    req.session.user = null
    req.session.group = null
    @generateSession req, res, ()->
      res.redirect("/")

  handlePostSignup: (req, res)=>
    rejectSignup = (message)=>
      console.log("Signup Error", message)
      req.addFlash "danger", message, ()=>
        res.redirect(@config.security.paths.signup)

    username = req.body.username
    password = req.body.password
    password2 = req.body.password2

    if !username or username.length < 3
      return rejectSignup(@config.security.messages.usernameLength)

    if !password or password.length < 6
      return rejectSignup(@config.security.messages.passwordLength)

    if !password2 or password isnt password2
      return rejectSignup(@config.security.messages.passwordMatch)

    cond = {}
    cond[@config.security.user.username] = username
    @db.getEntity @config.security.userTable, cond, (err, user)=>
      return @sendError(req, res, err) if err
      return rejectSignup(@config.security.messages.usernameExists) if user

      scrypt.passwordHash password, 0.1, (err, pwdhash)=>
        return @sendError(req, res, err) if err
        @db.getCollection @config.security.groupTable, (err, groupCollection)=>
          return @sendError(req, res, err) if err
          groupObj = {}
          groupCollection.insert {}, groupObj, (err, groupObject)=>

            @db.getCollection @config.security.userTable, (err, userCollection)=>
              return rejectSignup(err) if err
              userObj = {}
              userObj[@config.security.user.username] = username
              userObj[@config.security.user.password] = pwdhash
              userObj[@config.security.groupTable + "_id"] = groupObject.id
              userCollection.insert {}, userObj, (err)=>
                return rejectSignup(err) if err
                @handlePostLogin(req, res)



  generateSession: (req, res, callback)=>
    # Generate a database session
    @db.getCollection @config.security.sessionTable, (err, sessionCollection)=>
      return @sendError(req, res, err) if err

      serializedSession = {}
      sessionCollection.insert {}, serializedSession, (err, result)=>
        return @sendError(req, res, err) if err
        console.log("Has new session", result)
        req.saveSession = (callback)=>
          changeset =
            user: req.session.user
            flash: req.session.flash
            last: req.session.last
          @db.update @config.security.sessionTable, {"pk": req.session.id, fieldset: "application"}, changeset, (err, res)=>
            console.log(err) if err
            console.log("Saved Session")
            callback()

        req.session = result
        req.session_in_database = {}
        for k,v of req.session
          req.session_in_database[k] = v
        val = ""+req.session.id
        val = 's:' + signature.sign(val, @config.security.siteSecret)
        val = cookie.serialize(@config.security.sessionCookie, val)
        res.setHeader('Set-Cookie', val)
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
        changeset =
          user: req.session.user
          flash: req.session.flash
          last: req.session.last
        sessionCollection.update {}, {"pk": req.session.id, fieldset: "application"}, changeset, (err)=>
          if err
            console.log(err)
          return origEnd.call(res, content)


    if not (req.session.user and req.session.group)
      console.log("No User / Group in session (2)")
      console.log req.session
      return next()

    @sessionRepository.getUserSession req.session, (err, userSession)=>
      return @sendError(req, res, err) if err
      @sessionRepository.getGroupSession req.session.group, (err, groupSession)=>
        return @sendError(req, res, err) if err
        req.sessionUser = userSession
        userSession.setGroup(groupSession)
        req.sessionGroup = groupSession
        next()

module.exports = SessionMiddleware
