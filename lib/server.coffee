connect = require('connect')

nunjucks = require('nunjucks')

nenv = null

class Server
  helperFunctions = (req, res, next)=>

    origEnd = res.end

    res.end = (content = null)->
      if req.hasOwnProperty('saveSession')
        req.saveSession ()->
          origEnd(content)
      else
        origEnd(content)

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

      tpl = nenv.getTemplate(templateName)
      res.send(tpl.render(parameters))

    req.addFlash = (type, message, callback)->
      if req.session
        if not req.session.hasOwnProperty('flash')
          req.session.flash = []
        req.session.flash.push({type: type, message: message})
        callback()
    next()

  directRender = (directRenderPaths)->
    return (req, res, next)->
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
    if @config.hasOwnProperty('middleware')
      for middleware in @config.middleware
        @app.use(middleware)
    @app.use directRender(@config.directRenderPaths)

  start: ()=>
    @server = @app.listen(@config.port);

module.exports = Server