fs = require('fs')
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

module.exports = (config)->
  return files