dataTypes = require('./types')
dfd = require("node-promise")

class Query
  constructor: (@mysql, @context, @collections, @collectionName, @fieldList)->
    @tableDef = @getCollectionDef(@collectionName)

    # the uids for fields and tables t0, f0 etc
    @i_table = 0
    @i_field = 0

    @map_table = {}
    @map_field = {}

    @selectFields = []
    @joins = []
    null

  getCollectionDef: (name)=>
    if @collections.hasOwnProperty(name)
      @collections[name].name = name
      return @collections[name]
    return null


  includeCollection: (path, collectionName)=>
    alias = "t#{@i_table}"
    @map_table[path] =
      alias: alias
      def: @getCollectionDef(collectionName)

    @i_table += 1
    return alias
  
  includeField: (fullName, def, tableAlias)=>
    alias = "f#{@i_field}"

    @map_field[fullName] =
      alias: alias
      def: def
      tableAlias: tableAlias

    @i_field += 1
    return alias

  walkField: (baseTable, prefixPath, fieldDefRaw)=>

    type = "normal"
    
    if typeof fieldDefRaw is 'string'
      pathString = fieldDefRaw
    else
      pathString = fieldDefRaw.path
      if fieldDefRaw.hasOwnProperty('type')
        type = fieldDefRaw.type

    switch type
      when "normal" then return @walkFieldNormal(baseTable, prefixPath, pathString)
      when "aggregate" then return @walkFieldAggregate(baseTable, prefixPath, fieldDefRaw)
    return "Field Type not valid"


  walkFieldAggregate: (baseTable, prefixPath, fieldDef)=>
    console.log "WALK AGG"
    
    path = fieldDef.path.split(".")

    linkBaseTable = baseTable
    while baseTable.def.fields.hasOwnProperty(path[0])
      # This isn't the backref
      
      linkBaseTable = @walkFieldUtil_IncTable(baseTable, prefixPath, path)

    console.log "WALK AGG: Got to Non Linked: ", prefixPath, path

    
    collectionName = path[0]
    collectionDef = @getCollectionDef(collectionName)
    collectionAlias = @includeCollection(collectionName, collectionName)

    collectionRef = baseTable.def.name
    linkBasePk = linkBaseTable.def.pk or "id"
    
    @joins.push "LEFT JOIN #{collectionDef.name} #{collectionAlias} on #{collectionAlias}.#{collectionRef} = #{linkBaseTable.alias}.#{linkBasePk} "

    fieldName = path[1]
    endFieldDef = collectionDef.fields[fieldName]
    #TODO: Make recursive AFTER backjoining.
    fieldAlias = @includeField(prefixPath.concat(path).join("."), endFieldDef, collectionAlias)
    @selectFields.push("#{fieldDef.ag_type}(#{collectionAlias}.#{fieldName}) AS #{fieldAlias}")
    null




  walkFieldNormal: (baseTable, prefixPath, pathString)=>
    path = pathString.split(".")
    return null if path.length < 1

    baseDef = baseTable.def

    
    if not baseDef.fields.hasOwnProperty(path[0])
      return "Field #{path[0]} doesn't exist in #{baseDef.tableName}"


    if path.length is 1
      fieldDef = baseDef.fields[path[0]]
      # Include the field
      fieldAlias = @includeField(prefixPath.concat(path).join("."), fieldDef, baseTable.alias)
      @selectFields.push("#{baseTable.alias}.#{path[0]} as #{fieldAlias}")
      return null
    else
      newTable = @walkFieldUtil_IncTable(baseTable, prefixPath, path)
      return @walkFieldNormal(newTable, prefixPath, path.join("."))

  walkFieldUtil_IncTable: (baseTable, prefixPath, path)=>
    tableField = path.shift()
    fieldDef = baseTable.def.fields[tableField]
    prefixPath.push(tableField)
    if not fieldDef.type is "ref"
      return "Field #{tableField} isn't a ref type, but was used as root part of a path"

    # Ensure the table is included
    if not @map_table.hasOwnProperty(prefixPath.join())
      collectionForField = @getCollectionDef(fieldDef.collection)
      if collectionForField is null
        return "Collection #{tableDef.collection} not found"
      tableAlias = @includeCollection(prefixPath.join(), collectionForField.name)
      refPk = collectionForField.pk or "id"
      @joins.push "LEFT JOIN #{collectionForField.name} #{tableAlias}
        ON #{tableAlias}.#{refPk} = #{baseTable.alias}.#{tableField}"

    newTable = @map_table[prefixPath.join()]

    return newTable

      

  build: (conditions, callback)=>
    builder = @
    promises = []
    rootAlias = @includeCollection("", @collectionName)

    for fieldDef in @fieldList
      err = @walkField(@map_table[""], [], fieldDef)
      if err isnt null
        console.log(err)
        callback(err)
        return
       
    whereString = null
    whereStringPromise = new dfd.Promise()
    promises.push(whereStringPromise)
    @makeWhereString conditions, (err, _whereString)->
      if err
        whereStringPromise.reject(err)
        return
      whereString = _whereString
      whereStringPromise.resolve(_whereString)

    pageString = null
    pageStringPromise = new dfd.Promise()
    promises.push(pageStringPromise)
    @makePageString conditions, (err, _pageString)->
      if err
        pageStringPromise.reject(err)
        return
      pageString = _pageString
      pageStringPromise.resolve(_pageString)
       
    pk = @tableDef.pk or "id"
    groupBy = " GROUP BY t0.#{pk}"

    dfd.allOrNone(promises).then ()->
      sql = "SELECT #{builder.selectFields.join()} \n
  FROM #{builder.collectionName} #{rootAlias} \n 
  #{builder.joins.join("\n   ")} \n 
  #{whereString} \n
  #{groupBy} \n
  #{pageString} \n
      
      "
      process.nextTick ()->
        callback(null, sql)
    , (err)-> callback(err)

  buildUpdate: (conditions, changeset, callback)=>
    builder = @
    
    promises = []

    rootAlias = @includeCollection("", @collectionName)

    for fieldDef in @fieldList
      continue if typeof fieldDef isnt 'string'
      err = @walkField(@map_table[""], [], fieldDef)
      if err isnt null
        console.log(err)
        callback(err)
        return

    wherePromise = new dfd.Promise()
    promises.push(wherePromise)
    whereString = null
    @makeWhereString conditions, (err, _whereString)->
      whereString = _whereString
      wherePromise.resolve()

    #pageString = @makePageString(conditions)
    updates = []
    
    for path, value of changeset
      do (path, value)->
        if not builder.map_field.hasOwnProperty(path)
          return callback("Attempt to update field not in fieldset: #{path}")
      
        field = builder.map_field[path]
        a_tableRef = field.tableAlias
        a_fieldName = path.split(".").pop()
        type = dataTypes[field.def.type]

        promise = new dfd.Promise()
        promises.push(promise)
        builder.userValue value, type, (err, safeValue)->
          updates.push("#{a_tableRef}.#{a_fieldName} = #{safeValue}")
          promise.resolve()
        null

    dfd.allOrNone(promises).then ()->
      sql = "UPDATE #{builder.collectionName} #{rootAlias} SET #{updates.join(", ")} #{whereString} "
      callback(null, sql)
    , (err)-> callback(err)



  userValue: (input, type = null, callback)=>
    builder = @
    if input is "#me" or input is "#user"
      process.nextTick ()->
        callback(null, builder.context.user)
      return

    if input is "#user"
      process.nextTick ()->
        callback(null, builder.context.group)
      return
    
    if type isnt null
      #process.nextTick ()->
      #  callback(null, builder.mysql.escape( type.toDb(input) ) )
      type.toDb input, (err, dbVal)->
        callback(err) if err
        callback(null, builder.mysql.escape dbVal)
      return


    process.nextTick ()->
      callback(null, builder.mysql.escape input)
    return

  makeWhereGroup: (list, andor, callback)=>
    builder = @

    # A user must not be able to directly add to this list.
    # Field names may come directly from user input, but everything else must
    # be escaped already.

    strs = []
    for cond in list
      if typeof cond is "string"
        if cond.length > 0
          strs.push("(#{cond})")
      else
        cond.cmp = cond.cmp || "="
        if not @map_field.hasOwnProperty(cond.field)
          process.nextTick ()->
            callback("Condition references non mapped field '#{cond.field}' in #{builder.collectionName} ")
          return
        # since cond.field is in the map, it is safe to use directly.
        mapped = @map_field[cond.field]

        tableRef = @map_field[cond.field].tableAlias
        fieldName = cond.field.split(".").pop()

        strs.push("#{tableRef}.#{fieldName} #{cond.cmp} #{cond.val} \n")

    process.nextTick ()->
      callback(null, strs.join(" #{andor} ") )
    

  makeWhereString: (conditions, callback)=>
    builder = @

    groupBy = ""
    wherePromises = []
    
    # Expand some Shortcut Methods
    if typeof conditions isnt "object"
      conditions = {pk: conditions}
    if conditions.hasOwnProperty('id')
      conditions.pk = conditions.id
      delete conditions.id

    pk = @tableDef.pk or "id"

    if conditions.hasOwnProperty('pk')
      if not conditions.hasOwnProperty('where')
        conditions.where = []
      conditions.where.push({field: pk, cmp: "=", val: conditions.pk})

    # WHERE are simple query conditions
    if conditions.hasOwnProperty('where')
      for cond in conditions.where
        do (cond)->
          promise = new dfd.Promise()
          wherePromises.push(promise)
          builder.userValue cond.val, null, (err, escaped)->
            return promise.reject(err) if err
            cmp = cond.cmp || "="
            if cmp not in ["=", "!=", "<", "<=", ">", ">=", "IS", "LIKE"]
              cmp = "="

            # cmp and val are now query-safe, but not field
            # Field will not be directly included, it will be checked against the map
        
            promise.resolve
              field: cond.field
              val: escaped
              cmp: cmp

    if conditions.hasOwnProperty('filter')
      for fieldName, v of conditions.filter
        do (fieldName, v)->
          promise = new dfd.Promise()
          wherePromises.push(promise)
          builder.userValue v, null, (err, escaped)->
            if err
              promise.reject(err)
              return
            promise.resolve
              field: fieldName
              val: escaped
              cmp: "="
            

    if conditions.hasOwnProperty("search")
      for field, term of conditions.search
        do (field, term)->
          wherePromise = new dfd.Promise()
          wherePromises.push(wherePromise)

          partGroup = []

          term = term.replace(/[^a-zA-Z0-9]/g, " ") # now query safe.
          termParts = term.split(" ")
          
          if field is "*"

            if /^[0-9]*$/.test(term)
              id = +term
              whereConditions.push({field: @pk, cmp: "=", val: id})
            else

              searchGroupPromises = []
       
              for termPart in termParts
                do (termPart)->
                  tpPromise = new dfd.Promise()
                  searchGroupPromises.push(tpPromise)
                  partGroup = []
                  for fieldName, field of @map_field
                    if field.def.type in ['string', 'text']
                      partGroup.push({field: fieldName, cmp: "LIKE", val: "'%#{termPart}%'"})

                  builder.makeWhereGroup partGroup, "OR", (err, tp)->
                    return tpPromise.reject(err) if err
                    tpPromise.resolve(tp)

              dfd.allOrNone(searchGroupPromises).then (searchGroup)->

                builder.makeWhereGroup searchGroup, "AND", (err, whereGroup)->
                  return wherePromise.reject(err) if err
                  wherePromise.resolve(whereGroup)
              , (err)-> wherePromise.reject(err)

          else
            searchGroup = []
            for p in termParts
              searchGroup.push({field: field, cmp: "LIKE", val: "'%#{p}%'"})
            builder.makeWhereGroup searchGroup, "OR", (err, whereGroup)->
              return wherePromise.reject(err) if err
              wherePromise.resolve(whereGroup)

    dfd.allOrNone(wherePromises).then (whereConditions)->
      builder.makeWhereGroup whereConditions, "AND", (err, str)->
        return callback(err) if err

        if str.length < 1
          process.nextTick ()->
            callback(null, "")
          return
        process.nextTick ()->
          callback(null, "WHERE " + str + groupBy)

    , (err)-> callback(err)


  makePageString: (conditions, callback)=>
    str = ""
    limit = false
    
    if conditions.hasOwnProperty("sort")
      sorts = []
      for sort in conditions.sort
        if sort.direction and sort.direction is -1
          direction = "DESC"
        else
          direction = "ASC"

        if not @map_field.hasOwnProperty(sort.fieldName)
          console.log("Sort references non mapped field #{sort.fieldName}")
          process.nextTick ()->
             callback("Sort references non mapped field #{sort.fieldName}")
          return

        map = @map_field[sort.fieldName]
        col = map.alias

        sorts.push("#{col} #{direction}")
      if sorts.length
        str += "ORDER BY #{sorts.join(", ")}"

    if conditions.hasOwnProperty("limit")
      limit = parseInt(conditions.limit)
      str += " LIMIT #{limit}"
    if conditions.hasOwnProperty("offset")
      str += " OFFSET #{parseInt(conditions.offset)}"
    else if conditions.hasOwnProperty("page") and limit
      page = parseInt(conditions.page)
      str += " OFFSET #{page * limit}"

    process.nextTick ()->
      callback(null, str)


  unPack: (result, callback)=>
    promises = []
    obj = {}
    for real, field of @map_field
      do (real, field)->
        type = dataTypes[field.def.type]
        type.fromDb result[field.alias], (err, val)->
          obj[real] = val

    dfd.allOrNone(promises).then ()->
      callback(null, obj)
    , (err)-> callback(err)


module.exports = Query
