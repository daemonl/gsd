Server = require('./server')
DatabaseConnection = require("./data/database_connection")
SessionMiddleware = require("./session/middleware")
SessionRepository = require("./session/repository")
SocketSession = require("./session/socket_session")

connect = require("connect")
socketIo = require('socket.io')

start = (config)->
  databaseConnection = new DatabaseConnection(config)
  sessionRepository = new SessionRepository(config, databaseConnection)
  sessionMiddleware = new SessionMiddleware(config, sessionRepository, databaseConnection)
  socketSession = new SocketSession(config, sessionRepository, databaseConnection)
  server = new Server(config, [sessionMiddleware.middleware])
  server.app.use(connect['static'](config.publicDir))

  server.start()

  io = socketIo.listen(server.server, {log: false})
  socketSession.bindSocket(io)

start.sync = require("./data/syncdb")
start.passwd = (password, callback)->
  scrypt = require('scrypt')
  scrypt.passwordHash password, 0.1, callback


module.exports = start
