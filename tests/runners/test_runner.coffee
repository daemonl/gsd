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
  red: "\033[31m",
  green: "\033[32m",
  blue: "\033[34m",
  reset: "\033[0m"
}
`
currentTest = null

tests = []
completedTests = []


teardown = ()->
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
  console.log ("\nTESTS ENDED\nTeardown\n")
  for t in completedTests
    console.log(t.description)
    for exp in t.results
      if exp.pass
        console.log(consoleColors.green + "PASS" + consoleColors.reset)
      else
        console.log(consoleColors.red + "FAIL" + consoleColors.reset + " - " + exp.message)

  teardown()

nextTest = ()->
  return testsEnded() if not tests.length

  t = tests.shift()
  currentTest = t
  t.results = []

  fnDone = ()->
    completedTests.push(t)
    nextTest()

  console.log("")
  console.log("=============================================================")
  console.log("It " + t.description)
  console.log("-------------------------------------------------------------")

  try
    t.test(fnDone)
  catch err
    console.log("Test threw exception", err)
    teardown()

class expectWrapped
  constructor: (@test, @val)->

  pass: ()->
    @test.results.push({pass: true, message: ''})
    console.log(consoleColors.green + "PASS" + consoleColors.reset)
  fail: (message)->
    @test.results.push({pass: false, message: message})
    console.log(consoleColors.red + "FAIL" + consoleColors.reset + " - " + message)

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