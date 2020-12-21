#!/bin/bash

if [ -z "$NAKAMA_SERVER_KEY" -o -z "$NAKAMA_HOST" -o -z "$NAKAMA_PORT" ]; then
	exit 0
fi

NAKAMA_SERVER_KEY=$(base64 -d <<< "$NAKAMA_SERVER_KEY")

cat << EOF > autoload/Build.gd
extends Node

const NAKAMA_HOST := '$NAKAMA_HOST'
const NAKAMA_PORT := $NAKAMA_PORT
const NAKAMA_SERVER_KEY := '$NAKAMA_SERVER_KEY'
const NAKAMA_USE_SSL := true

EOF

