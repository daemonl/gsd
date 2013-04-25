mysql = require('mysql')
dfd = require('node-promise')

db = mysql.createConnection {
  host: 'localhost'
  user: 'root'
  password: ''
  database: 'test'
}

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
      nullable: false
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"

    return "VARCHAR(#{opt.length}) #{nullPart}"

  if field.type is 'id'
    return "INT(11) UNSIGNED NOT NULL AUTO_INCREMENT"

  if field.type is 'choice'
    def = {
      nullable: false
      choices: []
    }
    opt = optionsWithDefaults def, field
    nullPart = if opt.nullable then "NULL" else "NOT NULL"

    # the number of characters required to describe the top index of choices
    intLen = (""+(field.choices.length - 1)).length

    return "INT(#{intLen}) UNSIGNED #{nullPart}"


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
    existing = {}
    for r in res
      existing[r.Field] = r

    console.log("ALTER")
    pk = null
    for field in table.fields

      if existing.hasOwnProperty(field.field)
        parts.push("MODIFY `#{field.field}` #{getDefForField(field)}")
      else
        parts.push("ADD `#{field.field}` #{getDefForField(field)}")
        if field.type is 'id'
          pk = field

    if pk isnt null
      parts.push("ADD PRIMARY KEY (`#{pk.field}`)")

    sql = "ALTER TABLE #{table.table} #{parts.join(',')};"

    db.query sql, callback


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


structure = {
  person: {
      fields: [
        {
          field: 'id'
          type: 'id'
        },
        {
          field: 'title'
          type: 'choice'
          label: "Title"
          choices: [
            "Mr", "Mrs", "Ms", "Dr"
          ]
        },
        {
          field: 'first_name'
          type: 'string'
          label: 'First'
        },
        {
          field: 'last_name'
          type: 'string'
          label: "Last"
        }
      ]
    }
}

db.connect ()->
  # Ensure InnoDB for all tables.
  f = (t, callback)->
    fixTableEngine(t.Name, callback)

  onEachRow "SHOW TABLE STATUS WHERE Engine != 'InnoDB'", f, ()->

    pendingTables = {}
    for tableName, def of structure
      nd = {}
      nd.table = tableName
      nd.fields = []
      for f in def.fields
        nd.fields.push(f)
      pendingTables[tableName] = nd

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
        addQueue.push(table)

      doAllThen addQueue, f, ()->
       db.end()