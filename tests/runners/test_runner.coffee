testVars = {}

testVars.dateString = ""+new Date().getTime()
testVars.username = "USER"+testVars.dateString
testVars.password = "PASS"+testVars.dateString
testVars.database = "GSD_TEST_DATABASE_FRUENMUFFIN"


mysql = require('mysql')

gsd = require('../../lib/app')
syncdb = require('../../lib/syncdb')
helpers = require('./test_helpers')

gConfig = null

`
consoleColors = {
  black: "\033[30m",
  red: "\033[31m",
  green: "\033[32m",
  yellow: "\033[33m",
  blue: "\033[34m",
  pink: "\033[35m",
  cyan: "\033[36m",
  white: "\033[37m",
  reset: "\033[0m"
}
`
currentTest = null
testParts = []

tests = []
completedTests = []


teardown = ()->
  console.log("\n\n-- Keeping the server alive for manual tests --\n")
  null


removeDatabase = (callback = null)->
  db = mysql.createConnection {
    host: gConfig.db.host
    user: gConfig.db.user
    password: gConfig.db.password
  }
  db.connect (err)->
    return console.log(err) if err
    db.query "DROP DATABASE IF EXISTS #{gConfig.db.database}", (err)->
      return console.log(err) if err
      console.log("Teardown Complete")
      if callback
        callback()

testsEnded = ()->
  console.log ("\n~~~~~~~~~~~~~~~\nTESTS ENDED\n")
  for t in completedTests
    line = ""
    console.log t.description
    pass = 0

    for exp in t.results

      if exp.pass
        line += (consoleColors.green + "." + consoleColors.reset)
        pass += 1
      else
        line += (consoleColors.red + "F" + consoleColors.reset)
    line = "  " + pass + " / " +  t.results.length + "  " + line
    console.log(line)
  teardown()


nextTest = ()->
  return testsEnded() if not tests.length

  t = tests.shift()
  currentTest = t
  testParts = []
  t.results = []

  fnDone = ()->
    completedTests.push(t)
    nextTest()

  console.log("" + consoleColors.cyan)
  console.log("=============================================================")
  console.log("It " + t.description)
  console.log("-------------------------------------------------------------" + consoleColors.reset)

  testString = t.test.toString().split('\n')
  for ts in testString
    if (ts.trim().substr(0, 6) is "expect")
      testParts.push(ts.trim())

  try
    t.test(fnDone)
  catch err
    console.log("Test threw exception", err)
    teardown()

class expectWrapped
  constructor: (@test, @val)->
    @testPart = testParts.shift()

  pass: ()->
    @test.results.push({pass: true, message: ''})

    console.log(consoleColors.green + "PASS" + consoleColors.yellow + " " + @testPart + consoleColors.reset)
  fail: (message)->
    @test.results.push({pass: false, message: message})
    console.log(consoleColors.red + "FAIL" + consoleColors.reset + " - " + message +  consoleColors.yellow + " " + @testPart + consoleColors.reset)

  notToEqual: (val)=>
    if (val isnt @val)
      @pass()
    else
      @fail("Expected '#{@val}' toEqual '#{val}'")

  toEqual: (val)=>

    if (val is @val)
      @pass()
    else
      @fail("Expected '#{@val}' toEqual '#{val}'")

  toBeDefined: ()=>
    if @val isnt undefined
      @pass()
    else
      @fail("Expected undefined to be defined")

  toBeUndefined: ()=>
    if @val is undefined
      @pass()
    else
      @fail("Expected '#{@val}' to be undefined")


  toContain: (substr)=>
    if @val.indexOf(substr) != -1
      @pass()
    else
      @fail("Expected '#{@val}' toContain '#{substr}'")


test = (config, fnTests)->

  gConfig = config
  config.db.database = testVars.database

  helpers.setConfig(config)

  it = (description, test)->
    tests.push {
      description: description
      test: test
    }

  expect = (val)->

    return new expectWrapped(currentTest, val)

  # get the tests
  fnTests(config, testVars, helpers, it, expect)

  removeDatabase ()->
    syncdb config, ()->
      try
        gsd(config)
      catch error
        console.log("APP TERMINATED", error)
        teardown()

      console.log("\n=================================\nBEGIN TESTS\n=================================\n\n")
      nextTest()


module.exports = {
  test: test
}