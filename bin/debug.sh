#!/bin/bash


WEB_DEBUG_PORT=9001
node-inspector --web-port=$WEB_DEBUG_PORT &

nodemon --ext '.coffee' --debug app.coffee


