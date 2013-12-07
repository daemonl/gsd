mysql = require('mysql')
dfd = require('node-promise')

db = null

fixTableEngine = (tableName, callback)->
  console.log("Fix Engine on #{tableName}")
  db.query "ALTER TABLE #{tableName} ENGINE = 'InnoDB'", callback

optionsWithDefaults = (def, overide)->
  r = {}
  for k,v of def
    if overide.hasOwnProperty(k)
      r[k] = overide[k]
    else
      r[k] = def[k]
  return r

getDefForField = (field)->


  if field.type is 'string'
    def = {
      length: 100
      nullable: true
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"

    return "VARCHAR(#{opt.length}) #{nullPart}"
  if field.type is 'password'
    def = {
      length: 512
      nullable: true
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"
    return "VARCHAR(#{opt.length}) #{nullPart}"

  if field.type in ['text', 'markdown']
    return "TEXT NULL"


  # JSON Storage types:
  if field.type in ['address', 'array', 'rich_text', 'file']
    return "TEXT NULL"


  if field.type is 'id'
    return "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT"


  if field.type is 'ref'
    def = {
      nullable: true
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"
    return "INT(11) UNSIGNED #{nullPart}"

  if field.type is 'model'
    def = {
      nullable: true
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"
    return "INT(11) UNSIGNED #{nullPart}"

  if field.type is 'date'
    def = {
      nullable: true
    }
    opt = optionsWithDefaults def, field

    nullPart = if opt.nullable then "NULL" else "NOT NULL"
    return "DATE #{nullPart}"

  if field.type is 'datetime'
    def = {
      nullable: true
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"
    return "INT(32) UNSIGNED #{nullPart}"

  if field.type is 'int'
    return "INT(11) UNSIGNED"

  if field.type is 'float'
    return "FLOAT"
    
  if field.type is 'bool'
    return "TINYINT"

  if field.type is 'auto_timestamp'
    return "TIMESTAMP"

  if field.type is 'enum'
    def = {
      nullable: true
      choices: []
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"

    # the number of characters required to describe the top index of choices
    intLen = (""+(field.choices.length - 1)).length

    return "INT(#{intLen}) UNSIGNED #{nullPart}"

  throw "Type not found: #{field.type}"


createTable = (table, callback)->
  parts = []

  console.log("CREATE", table)

  pk = null
  for field in table.fields

    if field.type is 'id'
      pk = field
    parts.push("`#{field.field}` #{getDefForField(field)}")

  if pk isnt null
    parts.push("PRIMARY KEY (`#{pk.field}`)")

  sql = "CREATE TABLE #{table.table} (#{parts.join(',')});"

  console.log(sql)
  db.query sql, callback

checkColumns = (table, callback)->
  parts = []

  db.query "SHOW COLUMNS FROM #{table.table}", (err, res)->
    
    db.query "SHOW INDEXES FROM `#{table.table}`", (err, index_res)->

      existing = {}
      
      for r in res
        r.indexes = {}
        existing[r.Field] = r

      for r in index_res
        existing[r.Column_name].indexes[r.Key_name] = r
        

      console.log("CHECK COLUMNS FOR #{table.table}")
      pk = null
      for field in table.fields
        if field.type is 'id'
          pk = field

        if existing.hasOwnProperty(field.field)
         
          parts.push("CHANGE COLUMN `#{field.field}` `#{field.field}` #{getDefForField(field)}")

          if field.type not in ['ref']
            for key_name, index of existing[field.field].indexes
              parts.push("DROP INDEX `#{index.Key_name}`")
              for field_k, e of existing
                if e.indexes.hasOwnProperty(index.Key_name)
                  delete e.indexes[index.Key_name]

        else
          parts.push("ADD `#{field.field}` #{getDefForField(field)}")
          

      if pk isnt null
        parts.push("ADD PRIMARY KEY (`#{pk.field}`)")

      
      sql = "ALTER TABLE #{table.table} #{parts.join(', ')};"
      
      console.log(sql)

      do(sql)->
        db.query sql, (err, res)->
          if err
            console.log("------\nERROR IN SQL:\n")
            console.log(sql)
            console.log("\n-----\n")
          callback(err, res)


doAllThen = (arr, oneach, callback)->
  pending = []

  queueEvent = (object, promise)->
    oneach object, (err)->
      if err
        console.log(err)
      promise.resolve()

  for o in arr
    p = new dfd.Promise()
    pending.push(p)
    queueEvent(o, p)

  ap = dfd.all pending
  ap.then callback

onEachRow = (query, f, callback)->
  db.query query, (err, res)->
    throw err if err
    doAllThen(res, f, callback)



module.exports = (config, callback)->

  db = mysql.createConnection {
    host: config.db.host
    user: config.db.user
    password: config.db.password
  }

  structure = config.model

  db.connect (err)->
    return console.log(err) if err

    console.log("BEGIN Database Sync")

    db.query "CREATE DATABASE IF NOT EXISTS #{config.db.database}", (err)->
      return console.log(err) if err

      db.query "USE #{config.db.database}", (err)->
        return console.log(err) if err

        # Ensure InnoDB for all tables.
        f = (t, callback)->
          fixTableEngine(t.Name, callback)

        onEachRow "SHOW TABLE STATUS WHERE Engine != 'InnoDB'", f, ()->

          pendingTables = {}

          addTable = (tableName, def)->
            console.log(tableName)
            nd = {}
            nd.table = tableName
            nd.fields = []
            for name, field of def.fields
              field.field = name
              nd.fields.push(field)
              #if field.hasOwnProperty('type') and field.type is 'model'
              #  addTable(field.definition.table, field.definition)
            pendingTables[tableName] = nd

          for tableName, def of structure
            addTable(tableName, def)


          f = (t, callback)->
            if not pendingTables.hasOwnProperty(t.Name)
              console.log("Table '#{t.Name}' not in definition. Skipped.")
              return callback()

            thisTable = pendingTables[t.Name]
            delete pendingTables[t.Name]
            checkColumns thisTable, callback


          onEachRow "SHOW TABLE STATUS", f, ()->



            f = (table, callback)->
              createTable(table)
              callback()

            addQueue = []
            for k,table of pendingTables
              console.log("ADD TABLE")
              addQueue.push(table)

            doAllThen addQueue, f, ()->
             db.end()
             callback()
