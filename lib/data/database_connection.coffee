dfd = require('node-promise')
path = require('path')

mysql = require('mysql')

Collection = require('./collection')

dataTypes = require('./types')

class DatabaseConnection
  constructor: (@config)->
    @promiseDb = null;
    if @config.hasOwnProperty('dbLog')
      if @config.dbLog is "default"
        @log = (query)=>
          console.log("Q: ", query)
      else
        @log = @config.dbLog

  log: (query)=>
    null

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
          @log("Database Connection Error: " + err)
          @promiseDb.reject(err)
        else
          @promiseDb.resolve(connection)
    @promiseDb.then(callback)

  getObjectId: (idString)=>
    return new ObjectId(idString)

  getCollection: (collectionName, callback)=>
    @onDb (db)=>
      callback(null, new Collection(@config, db, collectionName, @log))

  query: (query, callback)=>
    @onDb (db)=>
      db.query query, {}, (err, res)->
        console.log(err)
        console.log(res)
        callback(null, res)

  update: (collectionName, conditions, entitySerialized, callback)=>
    @getCollection collectionName, (err, collection)=>
      return callback(err) if err
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