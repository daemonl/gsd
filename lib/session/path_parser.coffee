
bracketRemover = /\[[^\]]*\]/g
bracketAdder = /\[[0-9]*\]/g
pathPartExp = /([a-zA-Z_][a-zA-Z0-9_]*)(\[([0-9]*|\'.*\')\])?/

log = ()->
  log.info.apply(null, arguments)

log.info = ()->
  #console.log.apply(null, arguments)
  ll = ["INFO: "]
  for a in arguments
    ll.push(a)
  console.log.apply(null, ll)

parsePart = (part)->
  firstChar = part.substring(0,1)
  parsed = {}
  if part.trim() is "*"
    parsed.type = "fieldset"
    parsed.fieldset = "*"
    return parsed

  if firstChar is "["
    parsed.type = "fieldlist"
    subParts = part.substring(1, part.length - 1).split(",")
    parsed.fields = []
    for subPart in subParts
      parsed.fields.push(subPart.trim())
    return parsed

  if firstChar is "("
    parsed.type = "fieldset"
    parsed.fieldset = part.substring(1, part.length - 1)
    return parsed

  parsed.type = "field"

  r = pathPartExp.exec(part)
  parsed.name = r[1]

  if r[2] isnt undefined
    parsed.key =  r[3]
  #parsed.key = "'#{parsed.key}'"
  return parsed

class PathParser

  constructor: (@model)->


  parse: (path, callback)->
    log.info("Parse:", path)
    parsed = {}


    removedParts = []

    cleanedString = (""+path).replace bracketRemover, (x)->
      i = removedParts.length
      removedParts.push(x)
      return "[#{i}]"

    parts = cleanedString.split(".")
    for i of parts
      parts[i] = parts[i].replace bracketAdder, (x)->
        return removedParts[x.substring(1, x.length - 1)]

    rootPart = parsePart(parts.shift())

    tablesToInclude = []

    if not @model.hasOwnProperty(rootPart.name)
      return callback(rootPart.name + " doesn't exist")


    conditions = []
    tables = {}

    lastModel = null
    walkPart = (parentModel, parentPath, pathParts)->
      lastModel = parentModel
      #log("PP", parentModel.table, pathParts)
      if pathParts.length < 1
        return

      thisPart = pathParts.shift().trim()
      if thisPart is "*"
        thisPart = "(*)"

      if thisPart is "(id)"
        thisPart = parentModel.pk

      firstChar = thisPart.substring(0,1)
      lastChar = thisPart.substring(thisPart.length - 1)

      if firstChar is "("
        if lastChar isnt ")"
          return callback("syntax error. Found ( without )", null)
        fieldset = thisPart.substring(1, thisPart.length - 1).trim()
        if fieldset is "*"
          for name, field of parentModel.fields
            if (field.hasOwnProperty('type') and field.type is "model")
              walkPart(parentModel, parentPath, [name, "(*)"])
            else
              walkPart(parentModel, parentPath, [name])

        else
          if not parentModel.hasOwnProperty("fieldsets")
            return callback("model #{parentModel.table} has no fieldsets")
          if not parentModel.fieldsets.hasOwnProperty(fieldset)
            return callback("model #{parentModel.table} has no fieldset named #{fieldset}")

          fieldSetString = parentModel.fieldsets[fieldset]
          fieldList = fieldSetString.substring(1, fieldSetString.length - 1).trim().split(",")

          for part in fieldList
            walkPart(parentModel, parentPath, part.trim().split("."))



      else if firstChar is "["
        if lastChar isnt "]"
          return callback("syntax error. Found [ without ] (First: #{firstChar}, Last: #{lastChar}", null)
        fieldlist = thisPart.substring(1, thisPart.length - 1).trim().split(",")

        for part in fieldlist
          walkPart(parentModel, parentPath, part.trim().split("."))

      else
        if not parentModel.fields.hasOwnProperty(thisPart)
          return callback(parentModel.table + " has no property '" + thisPart + "'.")
        field = parentModel.fields[thisPart]
        if (field.hasOwnProperty('type'))
          if field.type is "model"

            modelPath = parentPath + "." + field.definition.table
            if not tables.hasOwnProperty(modelPath)
              tables[modelPath] = {
                fields: [],
                mapLabel: parentPath + "." + thisPart
                model: field.definition
                join: {
                  parent: parentPath
                  parentId: thisPart
                  childId: field.definition.pk
                  childTable: field.definition.table
                }
              }

            walkPart(field.definition, modelPath, pathParts)
            return

        if not (thisPart in tables[parentPath].fields)
          tables[parentPath].fields.push(thisPart)


      #if (pathParts.length)
      #  walkPart(pathParts)


    rootModel = @model[rootPart.name]
    rootPath = rootModel.table

    if rootPart.hasOwnProperty('key')
      rootPath = rootPath + "[#{rootPart.key}]"
      conditions.push({tablePath: rootPath, field: rootModel.pk, compare: "=", value: rootPart.key})
    else
      rootPath = rootPath + "[{f0}]"

    tables[rootPath] = {fields: [], mapLabel: rootPath, model: rootModel}

    walkPart(rootModel, rootPath, parts)

    for k, table of tables
      if not (table.model.pk in table.fields)
        table.fields.unshift(table.model.pk)


    return callback null, {
        root: rootModel
        final: lastModel
        tables: tables
        conditions: conditions
      }

module.exports = PathParser