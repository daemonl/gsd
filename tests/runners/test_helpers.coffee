
querystring = require('querystring')

http = require('http')

sessionCookie = null
config = null

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

module.exports = {
  httpGet: httpGet
  httpPostForm: httpPostForm
  httpDefaultOptions: httpDefaultOptions
  extractCookie: extractCookie
  setSessionCookie: (cookie)->
    sessionCookie = cookie
  setConfig: (sconfig)->
    config = sconfig
}