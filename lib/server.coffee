connect = require('connect')

nunjucks = require('nunjucks')

nenv = null

class Server
  helperFunctions = (req, res, next)->

    res.redirect = (url)->
      res.statusCode = 302
      res.setHeader('Location', url)
      res.setHeader('Content-Length', '0')
      res.end()
      return

    res.pipe = (stream)->
      stream.on 'data', (data)->
        res.write(data)

      stream.on 'end', ()->
        res.statusCode = 200
        res.end()

    res.send = (status, content)->
      if not content
        content = status
        status = 200
      res.statusCode = status
      res.end(content)
      return

    res.render = (templateName, parameters)->
      parameters.req = req
      parameters.flash = []

      if req.session and req.session.flash
        parameters.flash = req.session.flash
        req.session.flash = []
        if req.saveSession
          req.saveSession ()->
            null
      tpl = nenv.getTemplate(templateName)
      res.send(tpl.render(parameters))

    req.addFlash = (type, message, callback)->
      if req.session
        if not req.session.hasOwnProperty('flash')
          req.session.flash = []
        req.session.flash.push({type: type, message: message})
        callback()
    next()

  directRenderPaths = [
    {path: "/",      methods: ["GET"], template: "index.html"}
    {path: "/login", methods: ["GET"], template: "login.html"}
    {path: "/app",   methods: ["GET"], template: "app.html"}
  ]

  directRender = (req, res, next)->
    for p in directRenderPaths
      if req.method in p.methods and req._parsedUrl.path is p.path
        res.render(p.template, {})
        return
    next()


  constructor: (@config, middlewares)->
    nenv = new nunjucks.Environment(new nunjucks.FileSystemLoader(@config.templateDir))
    @app = connect()
    @app.use connect.logger('dev')
    @app.use connect.favicon()
    @app.use connect.bodyParser()
    @app.use connect.cookieParser(@config.security.siteSecret)
    @app.use helperFunctions
    for middleware in middlewares
      @app.use(middleware)
    @app.use directRender

  start: ()=>
    @server = @app.listen(@config.port);

module.exports = Server