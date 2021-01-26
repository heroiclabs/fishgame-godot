"Fish Game" for Godot
=====================

**"Fish Game" for Godot** is a 2-4 player online game built in the
[Godot](https://godotengine.org/) game engine, created as a demostration of
[Nakama](https://heroiclabs.com/), an open-source scalable game server.

![Animated GIF showing gameplay](assets/screenshots/fishgame-godot-art1.gif)

You can download playable builds for Windows, Linux and MacOS from the
[Releases page](https://github.com/heroiclabs/fishgame-godot/releases).

**"Fish Game"** demonstrates the following Nakama features:

- [User authentication](https://heroiclabs.com/docs/authentication/)
- [Matchmaking](https://heroiclabs.com/docs/gameplay-matchmaker/)
- [Leaderboards](https://heroiclabs.com/docs/gameplay-leaderboards/)
- [Realtime Multiplayer](https://heroiclabs.com/docs/gameplay-multiplayer-realtime/)

The game design is heavily inspired by [Duck Game](https://store.steampowered.com/app/312530/Duck_Game/).

Controls
--------

### Playing Online ###

#### Gamepad: ####

- **D-PAD** or **LEFT ANALOG STICK** = move your fish
- **A (XBox)** or **Cross (PS)** = jump
- **Y (XBox)** or **Triangle (PS)** = pickup/throw weapon
- **X (XBox)** or **Square (PS)** = use weapon
- **B (Xbox)** or **Circle (PS)** = blub

#### Keyboard: ####

- **W**, **A**, **S**, **D** = move your fish
- **C** = pickup/throw weapon
- **V** = use weapon
- **E** = blub

### Playing Locally ###

#### Gamepad: ####

*Same as the "Playing Online" controls above.*

#### Keyboard: ####

| Action               | Player 1                   | Player 2   |
| -------------------- | -------------------------- | ---------- |
| move your fish       | **W**, **A**, **S**, **D** | Arrow keys |
| pickup/throw weapon  | **C**                      | **L**      |
| use weapon           | **V**                      | **;**      |
| blub                 | **E**                      | **P**      |

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

### Setting up the leaderboard ###

If you're connecting to your own Nakama server, the "Leaderboard" won't work
until you first create it on your server.

To do that:

1. Create a file called `fish_game.lua` with the following contents:

    ```lua
    local nk = require("nakama")
    
    nk.run_once(function(context)
    	nk.leaderboard_create("fish_game_wins", false, "desc", "incr")
    end)
    ```
2. Place it in the `modules/` directory where your Nakama server keeps its
data. If you're using the [docker-compose configuration from the Nakama
documentation](https://heroiclabs.com/docs/install-docker-quickstart/#running-nakama-with-docker-compose)
this will be under the same directory with the `docker-compose.yml` file.

3. Then restart your Nakama server.

_Note: The game will play fine without the leaderboard._

