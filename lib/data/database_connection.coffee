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
      callback(null, new Collection(@, @config, db, collectionName, @log))

  query: (query, callback)=>
    console.log("QUERY: '#{query}'")
    @onDb (db)=>

      db.query query, {}, (err, res)->
        callback(err, res)

  update: (collectionName, conditions, entitySerialized, callback)=>
    @getCollection collectionName, (err, collection)=>
      return callback(err) if err
      collection.update conditions, entitySerialized, (err, result)->
        return callback(err) if err
        callback(null, result)

  updateOne: (collectionName, pk, entitySerialized, callback)=>
    @getCollection collectionName, (err, collection)=>
      return callback(err) if err
      collection.updateOne pk, entitySerialized, (err, result)->
        return callback(err) if err
        callback(null, result)

  getEntity: (collectionName, conditions, callback)=>
    @getCollection collectionName, (err, collection)=>
      return callback(err) if err
      collection.findOne conditions, (err, serializedEntity)=>
        return callback(err) if err
        callback(null, serializedEntity)

  escape: (string, callback)=>
    @onDb (db)=>
      db.escape(string, callback)

  escapeAll: (strings, callback)=>
    #ToDo: ASYNCRIFY!
    rStrings = []
    next = ()->
      if strings.length < 1
        return callback(rStrings)
      str = strings.shift()

      @escape str, (err, esc)->
        if err
          return callback(err)
        rStrings.push(esc)
        next()








module.exports = DatabaseConnection
