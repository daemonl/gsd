
http = require('http')

config = require('./test_config')

gsd = require('../lib/app')

gsd(config)

req = (path, method, sessionCookie, callback)->
  options = {
    host: 'localhost'
    port: config.port
    path: path
    method: method
    headers: {}
  }



  if sessionCookie != null
    options.headers.cookie = config.security.sessionCookie + "=" + sessionCookie

  fn = (response)->
    str = ''
    response.on 'data',  (chunk)->
      str += chunk;


    response.on 'end',  ()->
      response.body = str
      callback(response)


  http.request(options, fn).end()

extractCookie = (res, name)->

  header = res.headers['set-cookie']
  return undefined if header is undefined
  for h in header
    hp = h.split("=")
    if hp[0] is name
      return hp[1]
  return undefined

sessionCookie = null
describe "App Test", ->
  it "Should establish a session", (done)->

    req '/', 'GET', null, (res)->
      sessionCookie = extractCookie(res, config.security.sessionCookie)
      expect(sessionCookie).toBeDefined()
      expect(res.body).toEqual("THIS IS THE INDEX PAGE")
      done()

  it "Should redirect from a non public url", (done)->
    req '/somePage', 'GET', sessionCookie, (res)->
      expect(extractCookie(res, config.security.sessionCookie)).toBeUndefined()
      expect(res.statusCode).toEqual(302)
      expect(res.headers['location']).toEqual('/login')
      done()

  it "Should get a login page", (done)->
    req '/login', 'GET', sessionCookie, (res)->
      expect(extractCookie(res, config.security.sessionCookie)).toBeUndefined()
      expect(res.body).toEqual("THIS IS THE LOGIN PAGE")
      done()

  #it "Should log in", (done)->
  #  req '/login', 'POST', sessionCookie, (res)->















