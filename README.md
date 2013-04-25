gsd
===

#GSD Node MySQL Abstraction with Sockets

Very early development, it doesn't actually work yet.

Developed because I am constantly re-writing the same code to sync MySQL databases to client Javascript applications, and authenticate users.

It will be:
-----------
A very opinionated RESTish framework (/server)

Create a data model, Sync to MySQL

Define templates, views, and other actions on top of the Connect middleware pattern

Sync data models using socket.io, shared sessions between http requests and sockets.

Sessions create an in-memory object linked to a dabase object for each user currently active

Users are grouped in to tennant groups, groups share data

Backbone extended models to handle socket.io sync and the data model
