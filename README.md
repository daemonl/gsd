Get Stuff Done
=========

Goal: Create a configuration based socket.io relational database server. 
Next time I am making a web app, I can write a config file, sync it to a database, then start writing client side javascript.

Contribut(ions/ers) more than welcome!

Server Config:
```javascript
    config = {}; // see the example in tests/runners/test_config.coffee for all options
    
    config.model = [
      "person": {
        "fields": {
          "id": {"type": "id"},
          "name_given": {"type": "string", "important": true},
          "name_given_other": {"type": "string"},
          "name_family": {"type": "string", "important": true},
          "phones": {"type": "array", "fields": {"type": {"type": "string"}, "number": {"type": "string"}}},
          "company": {"type": "ref", "collection": "company"}
        },
        "fieldsets": {
          "table": ["name_given", "name_family", "company.name"],
          "form": ["name_given", "name_given_other", "name_family", "company.id", "company.name", "phones"]
        },
        "identityFields": ["name_given", "name_family"]
      }
      // ... etc
    ]
    
    gsd = require("gsd");
    gsd(config);
```    
    
Client Side:
```coffeescript
    # Retreive one object
    socket.emit "get", "person", 1, "form", (err, person)->
      console.log person
      
    # Search all textish fields in the fieldset:
    socket.emit "list", "person", {fieldset: "list", search: "bob"}, (err, people)->
      for person in people
        console.log(person)
    
    # Show all people
    socket.emit "list", "person", {fieldset: "list"}, (err, people)->
      for person in people
        console.log(person) 
        
    # Bind to any model change: (Flags the change, doesn't give the new derails)
    socket.on "update" (collection, id)->
      # If something cares:
      socket.emit "get", collection, id, (err, obj)->
        console.log "UPDATE", collection, id, obj
        
    # Change an object:
    socket.emit "set", "person", "1", {name_family: "smith"}, (err, data)->
      console.log(err) if err
    
    # Create a new object (null ID)
    socket.emit "set", "person", null, {name_given: "bob", name_family: "smith"}, (err, data)->
      console.log(data.id)
```  
  
3rd party components:
- connect for http
- socket.io for data sync
- nunjucks for template rendering
- scrypt for password hashing
- MySQL for... database stuff

This is *not built with massive scalability* in mind: It is for enterprise applications, or apps with a (relatively)
small number of users, each with heavy use of the system.

Developed because I am constantly re-writing the same code to sync MySQL databases to client Javascript applications,
and authenticate users.

Completed:
---------
User and group management with sessions: signup, login, logout.

Sessions create an in-memory object linked to a database object for each user currently active.

Sockets tap in to the same session object as HTTP requests

A test suite for testing the app from a fake client.

MySQL Database creation (Almost sync) for a few data types (The framework is in place)



Under Construction:
---------
Multi Tennancy / Access Masks

Allow extension with templates, views, and other actions on top of the Connect middleware pattern.

Configuration default, and parser/checker - it's a complicated structure
