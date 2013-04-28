gsd
=========

MySQL Abstraction in node.js
---------
connect for http
socket.io for data sync
nunjucks for template rendering
scrypt for password hashing

A very opinionated data access framework (/server).

Very early development, it doesn't actually work yet.

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
Data access model (which is kind of the whole point)

Allow extension with templates, views, and other actions on top of the Connect middleware pattern.

Backbone extended models to handle socket.io sync and the data model.

Configuration default, and parser/checker - it's a complicated structure


Ideas:
--------
Other databases, SQL or otherwise.
