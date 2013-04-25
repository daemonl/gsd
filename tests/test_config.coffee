


collections = {
  session: {
    table: "session"
    pk: "session_id"
    fields: {
      session_id: {type: 'gid'}
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

  model: collections
  publicDir: "tests/public"
  templateDir: "tests/templates"
  security:{
    publicUrls: ["/style.css", "/login", "/signup", "/index", "/"]
    userTable: 'staff'
    user: {
      username: 'user_name'
      password: 'user_password'
      method: 'plain'
    }
    groupTable: 'tenant'
    sessionTable: 'session'
    siteSecret: "Not Secret Yet"

  }
  port: 8080
}

module.exports = config