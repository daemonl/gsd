dataTypes = require('./types')

class Collection
  constructor: (@config, @mysql, @collectionName, @log)->
    if not @config.model.hasOwnProperty(@collectionName)
      throw "Invalid Collection Name: "+@collectionName
    @tableDef = @config.model[@collectionName]
    @tableName = @tableDef.table

  makeWhereString: (conditions)=>

    whereBits = []
    for k,v of conditions
      if k is "id"
        k = @tableDef.pk
      whereBits.push("t.#{k} = '#{v}'")
    if whereBits.length < 1
      return ""
    return "WHERE " + whereBits.join(" AND ")

  update: (conditions, fieldsToUpdate, callback)=>
    c = @makeWhereString(conditions)
    setFields = []
    setValues = []
    for k,v of fieldsToUpdate
      if @tableDef.fields.hasOwnProperty(k)
        setFields.push("t.#{k} = ?")
        def = @tableDef.fields[k]
        type = dataTypes[def.type]
        setValues.push(type.toDb(v))
    u = setFields.join(", ")
    query = "UPDATE #{@tableName} t SET #{u} #{c}"
    @log query
    @mysql.query query, setValues, callback

  insert: (fields, callback)=>
    postInsert = (err, res)=>
      if err
        @log err
        return callback(err)
      returnObject = {}
      for k,v of fields
        returnObject[k] = v
      returnObject[@tableDef.pk] = res.insertId
      returnObject.id = res.insertId
      callback(err, returnObject)

    if Object.keys(fields).length < 1
      return @mysql.query "INSERT INTO #{@tableName} VALUES ()", null, postInsert

    query = "INSERT INTO #{@tableName} SET ?"
    @log(query)
    @mysql.query query, fields, postInsert

  find: (conditions, callback)->
    query = "SELECT t.* FROM #{@tableName} t "
    query = query + @makeWhereString(conditions)

    @mysql.query query, (err, result)=>
      return callback(err) if err
      returnArray = []
      for row in result
        o = {}
        for field,def of @tableDef.fields
          type = dataTypes[def.type]
          o[field] = type.fromDb(row[field])
        o.id = o[@tableDef.pk]
        returnArray.push(o)
      @log(query + " - Found " + returnArray.length)
      callback(null, returnArray)

  findOne: (conditions, callback)->
    @find conditions, (err, rows)->
      return callback(err) if err
      return callback(null, null) if not rows or rows.length < 1
      callback(null, rows[0])

module.exports = Collection