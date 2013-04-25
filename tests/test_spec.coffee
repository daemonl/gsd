
http = require('http')

config = require('./test_config')

gsd = require('../lib/app')

gsd(config)

req = (path, method, callback)->
  options = {
    host: 'localhost'
    port: config.port
    path: path
    method: method
  }
  fn = (response)->
    str = ''
    response.on 'data',  (chunk)->
      str += chunk;


    response.on 'end',  ()->
      response.body = str
      callback(response)


  http.request(options, fn).end()


describe "App Test", ->
  it "Should establish a session", (done)->

    req '/', 'GET', (res)->
      expect(res.headers['set-cookie']).toBeDefined()
      console.log(res.headers['set-cookie'])
      expect(res.body).toEqual("THIS IS THE INDEX PAGE")
      done()










