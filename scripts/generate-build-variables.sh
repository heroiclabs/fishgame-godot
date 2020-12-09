#!/bin/bash

if [ -z "$NAKAMA_SERVER_KEY" -o -z "$NAKAMA_HOST" -o -z "$NAKAMA_PORT" ]; then
	exit 0
fi

NAKAMA_SERVER_KEY=$(base64 -d <<< "$NAKAMA_SERVER_KEY")

cat << EOF > autoload/Build.gd
extends Node

var NAKAMA_HOST = '$NAKAMA_HOST'
var NAKAMA_PORT = $NAKAMA_PORT
var NAKAMA_SERVER_KEY = '$NAKAMA_SERVER_KEY'
var NAKAMA_USE_SSL = true

var DVORAK := false

EOF

