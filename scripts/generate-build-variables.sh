#!/bin/bash

if [ -z "$NAKAMA_SERVER_KEY" -o -z "$NAKAMA_HOST" -o -z "$NAKAMA_PORT" ]; then
	exit 0
fi

NAKAMA_SERVER_KEY=$(base64 -d <<< "$NAKAMA_SERVER_KEY")

# Use the Git hash if no CLIENT_VERSION is given.
if [ -z "$CLIENT_VERSION" ]; then
	# GitLab CI:
	if [ -n "$CI_COMMIT_SHA" ]; then
		CLIENT_VERSION="$CI_COMMIT_SHA"

	# GitHub Actions:
	elif [ -n "$GITHUB_SHA" ]; then
		CLIENT_VERSION="$GITHUB_SHA"
	fi
fi

cat << EOF > autoload/Build.gd
extends Node

const NAKAMA_HOST := '$NAKAMA_HOST'
const NAKAMA_PORT := $NAKAMA_PORT
const NAKAMA_SERVER_KEY := '$NAKAMA_SERVER_KEY'
const NAKAMA_USE_SSL := true

const CLIENT_VERSION := '$CLIENT_VERSION'

EOF

