


collections = {
  session: {
    table: "session"
    pk: "session_id"
    fields: {
      session_id: {type: 'id'}
      user:  {type: 'ref', collection: 'user'}
      group: {type: 'ref', collection: 'user'}
      flash: {type: 'array'}
      last:  {type: 'datetime'}
    }
  }
  staff: {
    table: "staff"
    pk: 'staff_id'
    fields: {
      staff_id: {type: 'id'}
      tenant_id: {type: 'ref', collection: 'tenant'}
      user_name: {type: 'string', length: 255}
      user_password: {type: 'string', length: 255}
      salt:     {type: 'string', length: 255}
    }
  }
  tenant: {
    table: "tenant"
    pk: 'tenant_id'
    fields: {
      tenant_id: {type: 'id'}
      name: {type: 'string'}
    }
  }
}



config = {
  db:{
    host: "localhost"
    user: "root"
    password: ""
    database: "cesoft"
  }
  dbLog: 'default'

  directRenderPaths: [
    {path: "/",       methods: ["GET"], template: "index.html"}
    {path: "/login",  methods: ["GET"], template: "login.html"}
    {path: "/signup", methods: ["GET"], template: "signup.html"}
    {path: "/app",    methods: ["GET"], template: "app.html"}
  ]

  model: collections
  publicDir: "tests/runners/public"
  templateDir: "tests/runners/templates"
  security:{
    paths: {
      login: "/login"
      logout: "/logout"
      signup: "/signup"
      target: "/app"
    }
    messages: {
      unknownError: "An unknown error occurred"

      invalidLogin: "The username or password you entered is incorrect"
      incompleteLogin: "Please enter a username and password"
      notLoggedIn: "You must be logged in to access this page"

      passwordLength: "Your password must be at least 6 characters long"
      usernameLength: "Your username must be at least 3 characters long"
      usernameExists: "That username is already taken"
      passwordMatch: "Passwords must match"
    }
    publicUrls: ["/style.css", "/"]
    userTable: 'staff'
    user: {
      username: 'user_name'
      password: 'user_password'
      method: 'plain'
    }
    groupTable: 'tenant'
    sessionTable: 'session'
    siteSecret: "Not Secret Yet"
    sessionCookie: "gsd_session"
  }
  port: 8080
}

module.exports = config