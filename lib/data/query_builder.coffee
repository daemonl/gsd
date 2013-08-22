dataTypes = require('./types')

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

  walkField: (baseTable, prefixPath, pathString)=>

    path = pathString.split(".")
    return null if path.length < 1

    baseDef = baseTable.def

    if not baseDef.fields.hasOwnProperty(path[0])
      return "Field #{path[0]} doesn't exist in #{baseDef.tableName}"

    fieldDef = baseDef.fields[path[0]]

    if path.length is 1
      # Include the field
      fieldAlias = @includeField(prefixPath.concat(path).join("."), fieldDef, baseTable.alias)
      @selectFields.push("#{baseTable.alias}.#{path[0]} as #{fieldAlias}")
      return null

    else
      tableField = path.shift()
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

      return @walkField(newTable, prefixPath, path.join("."))
      

  build: (conditions, callback)=>

    rootAlias = @includeCollection("", @collectionName)

    for fieldName in @fieldList
      err = @walkField(@map_table[""], [], fieldName)
      if err isnt null
        console.log(err)
        callback(err)
        return

    try
      whereString = @makeWhereString(conditions)
      pageString = @makePageString(conditions)
    catch e
      callback(e)
      return


    sql = "SELECT #{@selectFields.join()} 
    FROM #{@collectionName} #{rootAlias} 
    #{@joins.join(" ")} 
    #{whereString} 
    #{pageString} 
    "
    callback(null, sql)

  buildUpdate: (conditions, changeset, callback)=>
    rootAlias = @includeCollection("", @collectionName)

    for fieldName in @fieldList
      err = @walkField(@map_table[""], [], fieldName)
      if err isnt null
        console.log(err)
        callback(err)
        return

    whereString = @makeWhereString(conditions)
    #pageString = @makePageString(conditions)
    updates = []

    for path, value of changeset
      if not @map_field.hasOwnProperty(path)
        return callback("Attempt to update field not in fieldset: #{path}")
      
      field = @map_field[path]
      tableRef = field.tableAlias
      fieldName = path.split(".").pop()
      type = dataTypes[field.def.type]
      safeValue = @userValue(value, type) #.fromDb(@userValue(value))

      updates.push("#{tableRef}.#{fieldName} = #{safeValue}")

    sql = "UPDATE #{@collectionName} #{rootAlias} SET #{updates.join(", ")} #{whereString} "
    callback(null, sql)


  userValue: (input, type = null)->

    if input is "#me" or input is "#user"
      return @context.user

    if input is "#user"
      return @context.group
    
    if type isnt null
      return @mysql.escape type.toDb(input)

    return @mysql.escape input

  makeWhereGroup: (list, andor)=>

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
          throw "Condition references non mapped field '#{cond.field}' in #{@collectionName} "
        # since cond.field is in the map, it is safe to use directly.
        mapped = @map_field[cond.field]

        tableRef = @map_field[cond.field].tableAlias
        fieldName = cond.field.split(".").pop()

        strs.push("#{tableRef}.#{fieldName} #{cond.cmp} #{cond.val}")
    return strs.join(" #{andor} ")
    

  makeWhereString: (conditions)=>
    whereConditions = []
    orGroups = []
    
    # Expand some Shortcut Methods
    if typeof conditions isnt "object"
      conditions = {pk: conditions}
    if conditions.hasOwnProperty('id')
      conditions.pk = conditions.id
      delete conditions.id
    if conditions.hasOwnProperty('pk')
      pk = @tableDef.pk or "id"
      whereConditions.push({field: pk, cmp: "=", val: conditions.pk})


    # WHERE are simple query conditions
    if conditions.hasOwnProperty('where')
      for cond in conditions.where
        val = @userValue(cond.val)
        cmp = cond.cmp || "="
        if cmp not in ["=", "!=", "<", "<=", ">", ">=", "IS", "LIKE"]
          cmp = "="

        # cmp and val are now query-safe, but not field
        # Field will not be directly included, it will be checked against the map
        
        whereConditions.push
          field: cond.field
          val: val
          cmp: cmp

    if conditions.hasOwnProperty('filter')
      for fieldName, v of conditions.filter
        whereConditions.push
          field: fieldName
          val: @userValue(v)
          cmp: "="

    if conditions.hasOwnProperty("search")
      for field, term of conditions.search

        partGroup = []

        term = term.replace(/[^a-zA-Z0-9]/g, " ") # now query safe.
        termParts = term.split(" ")
        
        if field is "*"

          if /^[0-9]*$/.test(term)
            id = +term
            whereConditions.push({field: @pk, cmp: "=", val: id})
          else

            searchGroup = []
     
            for termPart in termParts
              partGroup = []
              for fieldName, field of @map_field
                if field.def.type in ['string', 'text']
                  partGroup.push({field: fieldName, cmp: "LIKE", val: "'%#{termPart}%'"})

              searchGroup.push(@makeWhereGroup(partGroup, "OR"))
            whereConditions.push(@makeWhereGroup(searchGroup, "AND"))

        else
          searchGroup = []
          for p in termParts
            searchGroup.push({field: field, cmp: "LIKE", val: "'%#{p}%'"})
          whereConditions.push(@makeWhereGroup(searchGroup, "OR"))

    str = @makeWhereGroup(whereConditions, "AND")
    if str.length < 1
      return ""
    return "WHERE " + str


  makePageString: (conditions)=>
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
          throw "Sort references non mapped field #{sort.fieldName}"

        map = @map_field[sort.fieldName]
        col = map.alias

        sorts.push("#{col} #{direction}")
      str += "ORDER BY #{sorts.join(", ")}"

    if conditions.hasOwnProperty("limit")
      limit = parseInt(conditions.limit)
      str += " LIMIT #{limit}"
    if conditions.hasOwnProperty("offset")
      str += " OFFSET #{parseInt(conditions.offset)}"
    else if conditions.hasOwnProperty("page") and limit
      page = parseInt(conditions.page)
      str += " OFFSET #{page * limit}"
    return str



  unPack: (result)=>
    obj = {}
    for real, field of @map_field
      type = dataTypes[field.def.type]
      obj[real] = type.fromDb(result[field.alias])
    return obj




module.exports = Query
