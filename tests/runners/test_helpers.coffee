
querystring = require('querystring')

http = require('http')
io = require('socket.io-client')

sessionCookie = null
config = null
socket = null

httpDefaultOptions = (path)->

  options = {
    host: 'localhost'
    port: config.port
    path: path
    method: 'GET'
    headers: {}
  }

  if sessionCookie != null
    options.headers.cookie = config.security.sessionCookie + "=" + sessionCookie

  return options

httpResponseHandler = (callback)->
  return (response)->
    str = ''
    response.on 'data',  (chunk)->
      str += chunk;

    response.on 'end',  ()->
      if (response.statusCode is 302)
        console.log("Redirect -> " + response.headers['location'])
      response.body = str
      cookieSent = extractCookie(response, config.security.sessionCookie)
      if cookieSent isnt undefined
        console.log("GOT NEW SESSION COOKIE", cookieSent)
        sessionCookie = cookieSent
      callback(response)


httpGet = (path, callback)->
  options = httpDefaultOptions(path)
  fn = httpResponseHandler(callback)
  http.request(options, fn).end()

httpPostForm = (path, post_data, callback)->
  options = httpDefaultOptions(path)
  options.method = "POST"
  body = querystring.stringify(post_data)
  options.headers['Content-Type'] = 'application/x-www-form-urlencoded'
  options.headers['Content-Length'] = body.length
  fn = httpResponseHandler(callback)
  req = http.request(options, fn)
  req.write(body)
  req.end()

extractCookie = (res, name)->
  header = res.headers['set-cookie']
  return undefined if header is undefined
  for h in header
    hp = h.split("=")
    if hp[0] is name
      return hp[1]
  return undefined

socketUtil = require('../../node_modules/socket.io-client/lib/util')
socketUtil.request = ()->
  console.log("USED")
  XMLHttpRequest = require('xmlhttprequest').XMLHttpRequest;
  XMLHttpRequest.setRequestHeader('cookieTest', config.security.sessionCookie + "=" + sessionCookie)
  return new XMLHttpRequest();

connectSocket = (callback)->

  socket = io.connect('localhost', {
    port: config.port,
    headers: {'cookietest': config.security.sessionCookie + "=" + sessionCookie}
  })

  socket.on 'connect', ()->
    console.log("socket connected")
    callback()

module.exports = {
  httpGet: httpGet
  httpPostForm: httpPostForm
  httpDefaultOptions: httpDefaultOptions
  extractCookie: extractCookie
  connectSocket: connectSocket
  setSessionCookie: (cookie)->
    sessionCookie = cookie
  setConfig: (sconfig)->
    config = sconfig

}