connect = require('connect')
fs = require("fs")
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
          res.render(p.template, {flash: req.session.flash})
          return
      next()

  files = (req, res, next)->

    if req.method is "POST" and req._parsedUrl.path.substr(0,7) is "/upload"
      console.log("UPLOAD")
      parts = req._parsedUrl.path.split("/")
      if parts.length != 5
        res.send(404, "Not Found")

      fileCollection = parts[2]
      collectionRef = parts[3]
      collectionId = parts[4]

      return res.send(404, "Not Found") if not req.files.attachment
      console.log("FILES: ", req.files)
      newName = "files/" + new Date().getTime()

      attachment = req.files.attachment
      fs.rename attachment.path, newName, (err)->
        if err
          console.log(err)
        null

     
      changeset = {}
      changeset[collectionRef] = collectionId
      changeset.file = newName
      changeset.filename = attachment.name
      changeset.mime = attachment.type

      req.sessionUser.set fileCollection, null, changeset, (err, obj)->
        return res.send(err) if err
        script = "window.top.file_done(#{obj.id})"
        response = "<!DOCTYPE html><html><head><script type='text/javascript'>#{script}</script></head><body></body></html>"
        res.send(response)
      return


    if req.method is "GET" and req._parsedUrl.path.substr(0, 9) is "/download"
      console.log("DOWNLOAD")
      parts = req._parsedUrl.path.split("/")
      if parts.length < 4 #Allow extras at the end for friendly filenames. The filename has no actual effect.
        res.send(404, "Not Found (Parts Length = #{parts.length})")
        return
      fileCollection = parts[2]
      fileId = parts[3]

      req.sessionUser.get fileCollection, fileId, "download", (err, f)->
        return res.send(err) if err
        console.log("DOWNLOAD FILE " + f.file)

        # Stream f.file as f.filename
        if f.mime.substr(0, 6) isnt "image/"
          res.setHeader("content-disposition", "attachment; filename=#{f.filename}")
        res.setHeader("content-type", f.mime)

        fs.exists f.file, (exists)->
          if not exists
            res.send(404, "Not Found") 
            return

          try
            filestream = fs.createReadStream(f.file)
            filestream.pipe(res)
          catch e
            console.log(e)
            res.send(404, "Not Found")
      return
          

    next()


  constructor: (@config, middlewares)->
    nenv = new nunjucks.Environment(new nunjucks.FileSystemLoader(@config.templateDir))
    @app = connect()
    @app.use connect.logger('dev')
    @app.use connect.favicon()
    @app.use connect.middleware.bodyParser()
    @app.use connect.cookieParser(@config.security.siteSecret)
    @app.use helperFunctions
    
    for middleware in middlewares
      @app.use(middleware)
    if @config.hasOwnProperty('middleware')
      for middleware in @config.middleware
        @app.use(middleware)
    @app.use directRender(@config.directRenderPaths)
    @app.use files

  start: ()=>
    @server = @app.listen(@config.port);

module.exports = Server
