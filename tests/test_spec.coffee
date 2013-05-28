
config = require('./runners/test_config')

testRunner = require('./runners/test_runner')

testRunner.test config, (config, testVars, fn, it, expect)->

  it "Should establish a session", (done)->

    fn.httpGet '/',  (res)->
      sessionCookie = fn.extractCookie(res, config.security.sessionCookie)
      fn.setSessionCookie(sessionCookie)
      expect(sessionCookie).toBeDefined()
      expect(res.body).toContain("THIS IS THE INDEX PAGE")
      done()

  it "Should redirect from a non public url", (done)->
    fn.httpGet '/somePageNotInThePublicUrls', (res)->
      expect(fn.extractCookie(res, config.security.sessionCookie)).toBeUndefined()
      expect(res.statusCode).toEqual(302)
      expect(res.headers['location']).toEqual(config.security.paths.login)
      done()

  it "Should get a signup page", (done)->
    fn.httpGet config.security.paths.signup, (res)->
      expect(res.body).toContain("THIS IS THE SIGNUP PAGE")
      done()

  it "Should attempt to post new user without a body", (done)->
    postvars = {}
    fn.httpPostForm config.security.paths.signup, postvars, (res)->
      expect(res.statusCode).toEqual(302)
      done()

  it "Should create a new user", (done)->
    postvars = {
      username: testVars.username
      password: testVars.password
      password2: testVars.password
    }
    fn.httpPostForm config.security.paths.signup, postvars, (res)->
      expect(res.statusCode).toEqual(302)
      expect(res.headers['location']).toEqual('/app')
      done()

  it "Should get the app screen", (done)->
    fn.httpGet config.security.paths.target, (res)->
      expect(res.statusCode).toEqual(200)
      expect(res.body).toContain("THIS IS THE APP PAGE")
      done()

  it "Should get a login page", (done)->
    fn.httpGet config.security.paths.login, (res)->
      expect(fn.extractCookie(res, config.security.sessionCookie)).toBeUndefined()
      expect(res.body).toContain("THIS IS THE LOGIN PAGE")
      done()

  it "Should log in, giving a new session", (done)->
    postvars = {username: testVars.username, password: testVars.password}
    fn.httpPostForm config.security.paths.login, postvars, (res)->
      oldSession = sessionCookie

      sessionCookie = fn.extractCookie(res, config.security.sessionCookie)
      expect(sessionCookie).toBeDefined()
      fn.setSessionCookie(sessionCookie)
      expect(oldSession).notToEqual(sessionCookie)
      expect(res.statusCode).toEqual(302)
      expect(res.headers['location']).toEqual(config.security.paths.target)
      done()

  it "Should get the app screen", (done)->
    fn.httpGet config.security.paths.target, (res)->
      expect(res.statusCode).toEqual(200)
      expect(res.body).toContain("THIS IS THE APP PAGE")
      done()

  it "Should connect on a socket", (done)->
    fn.connectSocket (socket)->
      done()

  it "Should logout", (done)->
    fn.httpGet config.security.paths.logout, (res)->
      expect(res.statusCode).toEqual(302)
      done()

  it "Should redirect from a non public url, Now that it's logged out again", (done)->
    fn.httpGet config.security.paths.target, (res)->
      expect(fn.extractCookie(res, config.security.sessionCookie)).toBeUndefined()
      expect(res.statusCode).toEqual(302)
      expect(res.headers['location']).toEqual(config.security.paths.login)
      done()

  it "Should fail creating the same user again", (done)->
    postvars = {
      username: testVars.username
      password: testVars.password
      password2: testVars.password
    }
    fn.httpPostForm config.security.paths.signup, postvars, (res)->
      expect(res.statusCode).toEqual(302)
      expect(res.headers['location']).toEqual(config.security.paths.signup)
      fn.httpGet res.headers['location'], (res)->
        expect(res.body).toContain(config.security.messages.usernameExists)
        done()
























