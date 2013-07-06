dataTypes = require('./types')

class Collection
  constructor: (@config, @mysql, @collectionName, @log)->
    if not @config.model.hasOwnProperty(@collectionName)
      throw "Invalid Collection Name: "+@collectionName
    @tableDef = @config.model[@collectionName]
    @tableName = @tableDef.table or @collectionName
    @pk = @tableDef.pk or "id"


  makeWhereString: (conditions)=>

    whereBits = []
    for k,v of conditions
      if k is "id"
        k = @pk
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

  updateOne: (id, fieldsToUpdate, callback)=>
    if id is null or id is 'null' or not id
      @insert(fieldsToUpdate, callback)
      return
    console.log("Non null id: ", id)
    conditions = {}
    conditions[@pk] = id
    
    @update(conditions, fieldsToUpdate, callback)

  insert: (fields, callback)=>
    postInsert = (err, res)=>
      if err
        @log err
        return callback(err)
      returnObject = {}
      for k,v of fields
        returnObject[k] = v
      returnObject[@pk] = res.insertId
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

    @log(query)
    @mysql.query query, (err, result)=>
      return callback(err) if err
      returnObject = {}
      for row in result
        o = {}
        for field,def of @tableDef.fields
          type = dataTypes[def.type]
          o[field] = type.fromDb(row[field])
        o.id = o[@pk]
        returnObject[o.id] = o

      callback(null, returnObject)

  findOne: (conditions, callback)=>
    @find conditions, (err, rows)->
      return callback(err) if err
      for id, row of rows
        return callback(null, row)
      return callback(null, null)

  findOneById: (id, callback)=>
    conditions = {}
    conditions[@pk] = id
    @findOne conditions, callback


module.exports = Collection
