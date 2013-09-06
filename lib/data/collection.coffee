dataTypes = require('./types')
Query = require('./query_builder')
dfd = require("node-promise")

debug = true

class Collection
  constructor: (@databaseConnection, @config, @mysql, @collectionName, @log)->
    if not @config.model.hasOwnProperty(@collectionName)
      throw "Invalid Collection Name: "+@collectionName
    @tableDef = @config.model[@collectionName]
    @tableName = @tableDef.table or @collectionName
    @pk = @tableDef.pk or "id"

  getQuery: (context, fieldList)=>
    return new Query(@mysql, context, @config.model, @collectionName, fieldList)
  
  getFieldList: (fieldset)=>
    # get Fieldset
    if @tableDef.hasOwnProperty("fieldsets") and @tableDef.fieldsets.hasOwnProperty(fieldset)
      fieldList = @tableDef.fieldsets[fieldset]
    else if fieldset is "default"
      fieldList = []
      for k,v of @tableDef.fields
        fieldList.push(k)
    else if fieldset is "identity"
      if @tableDef.hasOwnProperty("identityFields")
        fieldList = @tableDef.identityFields
      else
        fieldList = ["name"]
    else
      throw "Fieldset #{fieldset} doesn't exist for #{@tableName}"

    if @pk not in fieldList
      fieldList.push(@pk)

    return fieldList


  update: (context, conditions, fieldsToUpdate, callback)=>

    fieldset = "form"
    if conditions.hasOwnProperty('fieldset')
      fieldset = conditions.fieldset
    try

      query = @getQuery(context, @getFieldList(fieldset))
    catch e
      return callback(e)

    query.buildUpdate conditions, fieldsToUpdate, (err, sql)=>
      if err
        console.log(err)
        callback(err)
        return

      if debug then console.log("=========\n", sql.replace("\n\n", "\n"), "\n=========")
      @mysql.query sql, (err, res)->
        return callback(err) if err
        callback(null, fieldsToUpdate)

  updateOne: (context, id, fieldsToUpdate, callback)=>
    if id is null or id is 'null' or not id
      @insert(context, fieldsToUpdate, callback)
      return
    
    @update context, {pk: id}, fieldsToUpdate, (err, res)=>
      return callback(err) if err
      fieldsToUpdate[@pk] = id
      callback(null, fieldsToUpdate)

  insert: (context, fields, callback)=>
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

    setFields = {}
    promises = []

    for k,v of fields
      if @tableDef.fields.hasOwnProperty(k)
        promise = new dfd.Promise()
        promises.push(promise)
        def = @tableDef.fields[k]
        type = dataTypes[def.type]
        do (setFields, k, v, promise)->
          type.toDb v, (err, val)->
            setFields[k] = val
            promise.resolve()

    dfd.allOrNone(promises).then ()=>
      query = "INSERT INTO #{@tableName} SET ?"
      @log(query)
      @mysql.query query, setFields, postInsert

  delete: (context, id, callback)=>
    sql = "DELETE FROM #{@tableName} WHERE #{@pk} = #{id};"
    @mysql.query sql, (err, res)=>
      return callback(err) if err
      return callback(null, res)

    
  find: (context, conditions, callback)->
    try
      fieldList = @getFieldList(conditions.fieldset or "default")
      query = @getQuery(context, fieldList)
    catch e
      return callback(e)

    query.build conditions, (err, sql)=>
      if err
        console.log(err)
        callback(err)
        return
      if debug then console.log("=========\n", sql, "\n=========")

      @mysql.query sql, (err, result)=>
        if err
          return callback(err)
        ret = {}
        sortIndex = 0

        doNext = ()->

          if result.length < 1
            callback(null, ret)
          else
            row = result.shift()
            query.unPack row, (err, obj)->
              callback(err) if err
              obj.sortIndex = sortIndex
              sortIndex += 1
              ret[obj.id] = obj
              doNext()
        doNext()


  getIdentityString: (id, callback)=>
    conditions =
      limit: 1
      fieldset: "identity"
      pk: id
    @find {}, conditions, (err, rows)->
      return callback(err) if err
      for id, row of rows
        fields = []
        for k,v of row
          if k and k != "id" and k != "sortIndex" and k.length > 0 and (""+k).indexOf(".id") is -1
            fields.push(v)
        return callback(null, fields.join(", "))
      return callback(null, "?")

  findOne: (context, conditions, callback)=>
    conditions.limit = 1
    @find context, conditions, (err, rows)->
      return callback(err) if err
      for id, row of rows
        return callback(null, row)
      return callback(null, null)

  findOneById: (context, id, fieldset, callback)=>
    @findOne context, {pk: id, fieldset: fieldset}, callback

  getChoicesFor: (context, id, fieldName, search, callback)=>
    if not @tableDef.fields.hasOwnProperty(fieldName)
      process.nextTick ()->
        callback("Field #{fieldName} doesn't exist in #{@tableName}")
      return

    field = @tableDef.fields[fieldName]
    if field.type isnt 'ref'
      process.nextTick ()->
        callback("Field #{fieldName} in #{@tableName} isn't a ref type")
      return

    collection = @databaseConnection.getCollection field.collection, (err, collection)->
      return callback(err) if err
      if collection.tableDef.fieldsets.hasOwnProperty('search')
        fieldset = 'search'
      else if collection.tableDef.fieldsets.hasOwnProperty('table')
        fieldset = 'table'
      else
        fieldset = 'identity'
      collection.find(context, {fieldset: fieldset, search: {"*": search}}, callback)


module.exports = Collection
