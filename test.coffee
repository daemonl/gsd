
DatabaseConnection = require("./database_connection")

SessionRepository = require("./session_repository")

logger = {}
logger.critical = (message)->
  console.log("CRITICAL:", message)

config = {
  dbUri: "mongodb://localhost:27017/gsd_test"
  logger: logger
  port: 3000
  siteSecret: 'Not secret yet'
}

databaseConnection = new DatabaseConnection(config)
sessionRepository = new SessionRepository(databaseConnection)
db = databaseConnection

testItems = {
  person: {
    name: {
      title: "Mr"
      first: "Kermit"
      middle: "the"
      last: "Frog"
    }
  }
  user: {
    username: "kermit"
  }
  group: {
    username: "ACME"
    staff:[
      {
        role: "Practitioner"
        person: null
        user: null
      }
    ]
  }
}

makeFakeData = (callback)->
  db.getCollection "person", (err, personCollection)->
    return console.log("Z1:", err) if err
    personCollection.insert testItems.person, {w:1}, (err, r1)->
      return console.log("Z2:", err) if err
      testItems.person = r1[0]
      testItems.group.staff[0].person = testItems.person._id
      db.getCollection "user", (err, userCollection)->
        return console.log("A:", err) if err
        userCollection.insert testItems.user, {w:1}, (err, result)->
          return console.log("B:", err) if err
          testItems.user = result[0]
          testItems.group.staff[0].user = testItems.user._id
          db.getCollection "group", (err, groupCollection)->
            return console.log("C:", err) if err
            groupCollection.insert testItems.group, {w:1}, (err, result)->
              return console.log("D:", err) if err
              testItems.group = result[0]
              testItems.user.group = testItems.group._id
              userCollection.update {_id: testItems.user._id}, testItems.user, {w: 1}, (err, result)->
                callback(testItems.user)


makeFakeData (user)->

  sessionRepository.createNewUserSession user._id, (err, userSession)->
    console.log err, userSession

    console.log userSession.serialized._id
    sessionRepository.getUserSession userSession.serialized._id, (err, userSession)->
      console.log "Search: ", err, userSession