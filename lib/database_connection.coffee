dfd = require('node-promise')
path = require('path')

mysql = require('mysql')


dataTypes = {
  gid: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  id: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  ref: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  datetime: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  string: {
    toDb: (val)->
      return val
    fromDb: (val)->
      return val
  }
  array: {
    toDb: (val)->
      return JSON.stringify(val)
    fromDb: (val)->
      v =  JSON.parse(val)
      if v is null
        return []
      return v
  }
}



class Collection
  constructor: (@config, @mysql, @collectionName)->
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
    console.log(fieldsToUpdate, @tableDef)
    for k,v of fieldsToUpdate

      if @tableDef.fields.hasOwnProperty(k)
        setFields.push("t.#{k} = ?")
        def = @tableDef.fields[k]
        type = dataTypes[def.type]
        setValues.push(type.toDb(v))

    u = setFields.join(", ")

    query = "UPDATE #{@tableName} t SET #{u} #{c}"

    console.log("QS", query, setValues)

    @mysql.query query, setValues, callback


  insert: (fields, callback)=>

    postInsert = (err, res)=>
      if err
        console.log err
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
    console.log(query, fields)
    @mysql.query query, fields, postInsert

  find: (conditions, callback)->
    query = "SELECT t.* FROM #{@tableName} t "
    query = query + @makeWhereString(conditions)
    console.log(query)
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
      callback(null, returnArray)

  findOne: (conditions, callback)->
    @find conditions, (err, rows)->
      return callback(err) if err
      return callback(null, null) if not rows or rows.length < 1
      callback(null, rows[0])

class DatabaseConnection
  constructor: (@config)->
    @promiseDb = null;


  onDb: (callback)=>
    if @promiseDb is null
      @promiseDb = new dfd.Promise()
      connection = mysql.createConnection({
        host: @config.db.host
        user: @config.db.user
        password: @config.db.password
        database: @config.db.database
      })
      connection.connect (err)=>
        if err
          console.log(err)
          @promiseDb.reject(err)
        else
          @promiseDb.resolve(connection)
    @promiseDb.then(callback)

  getObjectId: (idString)=>
    return new ObjectId(idString)

  getCollection: (collectionName, callback)=>
    @onDb (db)=>
      callback(null, new Collection(@config, db, collectionName))

  update: (collectionName, conditions, entitySerialized, callback)=>
    @getCollection collectionName, (err, collection)=>
      return callback(err) if err

      console.log(entitySerialized)

      collection.update conditions, entitySerialized, (err, result)->
        return callback(err) if err
        callback(null, result)


  getEntity: (collectionName, conditions, callback)=>
    @getCollection collectionName, (err, collection)=>
      return callback(err) if err

      collection.findOne conditions, (err, serializedEntity)=>
        return callback(err) if err
        callback(null, serializedEntity)



module.exports = DatabaseConnection