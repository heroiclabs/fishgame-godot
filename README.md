"Fish Game" for Godot
=====================

**"Fish Game" for Godot** is an online multiplayer game, created as a
demostration of [Nakama](https://heroiclabs.com/), an open-source scalable game
server, using the [Godot](https://godotengine.org/) game engine.

The game design is heavily inspired by [Duck Game](https://store.steampowered.com/app/312530/Duck_Game/).

Playing the game from source
----------------------------

The game has a couple of dependencies:

* [Godot](https://godotengine.org/download) 3.2.3 or later.
* A Nakama server to connect to. For testing/learning purposes, it's recommended to [install Nakama locally with Docker](https://heroiclabs.com/docs/install-docker-quickstart/).

To run the game:

1. Download the source code to your computer
2. Open Godot and "Import" the project
3. Edit the [autoload/Build.gd](https://github.com/heroiclabs/fishgame-godot/blob/main/autoload/Build.gd) file and replace the constants with the right values for your Nakama server. If you're running a Nakama server locally with the default settings, then you shouldn't need to change anything.
4. Press F5 or click the play button in the upper-right corner to start the game

