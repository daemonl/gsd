

module.exports = (config)->
	fn = (req, res, next)->
		if req._parsedUrl.path.substr(0,4) is "/csv"
			console.log("MATCH")
			parts = req._parsedUrl.path.split("/")
			if parts.length < 4
				res.send(404, "Not Found (Parts Length = #{parts.length})")
				return

			collection = parts[2]

			query = JSON.parse(decodeURIComponent(parts[3]))

			console.log query

			req.sessionUser.list collection, query, (err, data)->
				if err
					console.log(err)
					res.send("ERROR")
					return

				columnHeaders = []

				for x, row of data
					for k, v of row
						if k != "sortIndex"
							columnHeaders.push(k)
					break

				responseString = ""

				responseString += columnHeaders.join() + "\n"
				for id, row of data
					fields = []
					for col in columnHeaders
						val = row[col]
						stringVal = ""
						if val == null
							
						else if typeof val.sort == "function"
							stringVal = val.join(" ").replace(/[^a-zA-Z0-9 _\(\)\-]/, " ")

						else if typeof val == "object"
							for k, v of val
								stringVal += "\"#{k}: #{v.replace(/[^a-zA-Z0-9 _\(\)\-]/, " ")}\""
		
						else
							stringVal = "\"" + (""+val).replace(/[^a-zA-Z0-9 _\(\)\-]/, " ") + "\""

						fields.push stringVal
					responseString += fields.join() + "\n"

				res.setHeader('Content-type', "text/csv")
				res.setHeader('Content-disposition', "attachment;filename=#{collection}.csv")
				res.send(responseString)
		else
			next()
