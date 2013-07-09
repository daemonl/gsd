dataTypes = require('./types')

class Collection
  constructor: (@databaseConnection, @config, @mysql, @collectionName, @log)->
    if not @config.model.hasOwnProperty(@collectionName)
      throw "Invalid Collection Name: "+@collectionName
    @tableDef = @config.model[@collectionName]
    @tableName = @tableDef.table or @collectionName
    @pk = @tableDef.pk or "id"


  makeWhereGroup: (list, andor, fieldMap)->
    strs = []
    for cond in list
      if typeof cond is "string"
        if cond.length > 0
          strs.push("(#{cond})")
      else
        cond.cmp = cond.cmp || "="
        if fieldMap is null
          tableRef = ""
        else
          tableRef = fieldMap[cond.field].tableRef + "."
        strs.push("#{tableRef}#{cond.field} #{cond.cmp} '#{cond.val}'")
    return strs.join(" #{andor} ")

  makeWhereString: (conditions, fieldMap = null)=>
    whereConditions = []
    orGroups = []

    if typeof conditions isnt "object"
      conditions = {pk: conditions}
    if conditions.hasOwnProperty('id')
      conditions.pk = conditions.id

    if conditions.hasOwnProperty('pk')
      whereConditions.push({field: @pk, cmp: "=", val: conditions.pk})

    if conditions.hasOwnProperty('where')
      for cond in conditions.where
        whereConditions.push(cond)
    
    if conditions.hasOwnProperty('filter')
      for k,v of conditions.filter
        whereConditions.push({field: k, val: c, cmp: "="})

    if conditions.hasOwnProperty('search')
      searchGroup = []
      for fieldName, def in @tableDef.fields
        if def.type in ['string', 'text']
          searchGroup.push({field: fieldName, cmp: "LIKE", val: "%#{searchTerm}%"})
      whereConditions.push(@makeWhereGroup(searchGroup, "OR", fieldMap))

    str = @makeWhereGroup(whereConditions, "AND", fieldMap)

    if str.length < 1
      return ""
    return "WHERE " + str

  getRefJoins: (t)=>
    joins = []
    symbols = {}
    j = 1
    for fieldName, def of @tableDef.fields
      continue if def.type isnt "ref"
            
    return {
      joinString: joins.join(" ")+" "
      symbols: symbols
    }
    



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
    
    @update({pk: id}, fieldsToUpdate, callback)

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
    
    # get Fieldset
    fieldset = conditions.fieldset or "default"

    if @tableDef.hasOwnProperty("fieldsets") and @tableDef.fieldsets.hasOwnProperty(fieldset)
      fieldList = @tableDef.fieldsets[fieldset]
    else if fieldset is "default"
      fieldList = []
      for k,v of @tableDef.fields
        fieldList.push(k)
    else
      return callback("Fieldset #{fieldset} doesn't exist for #{@tableName}")

    if @pk not in fieldList
      fieldList.push(@pk)
    i_table = 1 # 0 is the focus entity
    i_field = 0

    map_table = {}
    map_field = {}
    

    selectParts = []
    joinStrings = []

    
    for fieldName in fieldList
      s = fieldName.split(".")
      if s.length < 1
        continue
      if not @tableDef.fields.hasOwnProperty(s[0])
        continue
      def = @tableDef.fields[s[0]]
      field_index = i_field
      
      map_field[fieldName] =
        def: def
        key: "f"+field_index
        tableRef: "t0"

      i_field += 1
      if s.length is 1
        selectParts.push("t0.#{fieldName} as f#{field_index}")
      else if s.length is 2
        
        if not map_table.hasOwnProperty(s)
          table_index = i_table
          i_table += 1
          map_table[s] = table_index
          refDef = @config.model[def.collection]
          refPk = @tableDef.pk or "id"
          joinStrings.push("LEFT JOIN #{def.collection} t#{table_index} ON t#{table_index}.#{refPk} = t0.#{s[0]} ")

        table_index = map_table[s]
        subFieldName = s[1]
        map_field[fieldName].tableRef = "t#{table_index}"
        selectParts.push("t#{table_index}.#{subFieldName} as f#{field_index} ")

   
    query = "SELECT #{selectParts.join()} FROM #{@tableName} t0 #{joinStrings.join(' ')}"
    query = query + @makeWhereString(conditions, map_field)

    @log(query)
    @mysql.query query, (err, result)=>
      return callback(err) if err
      returnObject = {}
      for row in result
        o = {}
        for real, field of map_field
          type = dataTypes[field.def.type]
          o[real] = type.fromDb(row[field.key])
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
    @findOne {pk: id}, callback

  getChoicesFor: (id, fieldName, search, callback)=>
    if not @tableDef.fields.hasOwnProperty(fieldName)
      return callback("Field #{fieldName} doesn't exist in #{@tableName}")
    field = @tableDef.fields[fieldName]
    if field.type isnt 'ref'
      return callback("Field #{fieldName} in #{@tableName} isn't a ref type")

    collection = @databaseConnection.getCollection field.collection, (err, collection)->
      return callback(err) if err
      collection.find({search: search}, callback)


module.exports = Collection
