dfd = require("node-promise")
fs = require("fs")
nunjucks = require('nunjucks')

nenv = null

expand = (flatArray)->
	o = {}
	for k,v of flatArray
		parts = k.split(".")
		current = o
		lastPart = parts.pop()
		for p in parts
			if not current.hasOwnProperty(p)
				current[p] = {}
			if current[p] is null or typeof current[p] isnt "object" # Some objects are placeholders for their FK
				current[p] = {pk: current[p]}

			current = current[p]
		current[lastPart] = v
	return o

getEmailString = (user, settings, id, callback)->
	promises = []
	parameters = {}
	parameters.user = user.serialized
	pFocus = new dfd.Promise()
	promises.push(pFocus)
	user.get settings.collection, id, "email", (err, f)->
		parameters[settings.collection] = expand(f)
		pFocus.resolve()

	if settings.hasOwnProperty("queries")
		for name, options of settings.queries
			pQuery = new dfd.Promise()
			promises.push(pQuery)
			do (pQuery, name, options)->
				filter = {}
				for k, v of options.filter
					if v is "#id"
						v = id
					filter[k] = v
					
				user.list options.collection, {filter: filter, fieldset: "email", where: options.where}, (err, list)->
					parameters[name] = list
					pQuery.resolve()

	dfd.allOrNone(promises).then ()->
		tpl = nenv.getTemplate(settings.templateFile + ".swig.html")
		callback(tpl.render(parameters), parameters)
		
#sendEmail
module.exports = (config)->
	if not config.hasOwnProperty('email')
		return (req, res, next)->
			next()
	nenv = new nunjucks.Environment(new nunjucks.FileSystemLoader(config.email.templateDir))
	fn = (req, res, next)->
		# /emailpreview/service_call/4
		#req._parsedUrl.path.substr(0,6) is "/email"
		if req._parsedUrl.path.substr(0,13) is "/emailpreview"
			parts = req._parsedUrl.path.split("/")
			if parts.length < 4
				res.send(404, "Not Found (Parts Length = #{parts.length})")
				return

			templateName = parts[2]
			id = parts[3]

			if not config.email.templates.hasOwnProperty(templateName)
				res.send(404, "Template '#{templateName}' Not Found")
				return

			settings = config.email.templates[templateName]

			getEmailString req.sessionUser, settings, id, (email)->
				lines = email.split("\n")
				subject = lines.shift()
				email = lines.join("\n")
				res.send(email)
			return
		if req._parsedUrl.path.substr(0, 9) is "/sendmail"
			console.log("MATCH")
			parts = req._parsedUrl.path.split("/")
			if parts.length < 6
				res.send(404, "Not Found (Parts Length = #{parts.length})")
				return

			templateName = parts[2]
			id = parts[3]
			recipient = parts[4]
			notes = decodeURIComponent(parts[5])

			if not config.email.templates.hasOwnProperty(templateName)
				res.send(404, "Template '#{templateName}' Not Found")
				return

			settings = config.email.templates[templateName]

			getEmailString req.sessionUser, settings, id, (email)->
				email = email.replace("--- NOTES HERE ---", notes)
				req.sessionUser.group.sendEmail(recipient, email)
				res.send("Done")
			return
		next()
	return fn

module.exports.getEmailString = getEmailString