# Mazegame 

Wellcome to the Mazegame repository! This is a game where you will write a bot to generate and navigate a maze.

## Installation

The game currently only support bots written in c++. More will be added as time goes on.

### Requirements

- C++ compiler. To check if this is installed, run the following command in your terminal:

```bash
g++ --version
```

- Windows or Linux. The game is currently only supported on these platforms. MacOS support will be added in the future.

### Installation

Head to the `release` section of this repository and download the latest client version of the game matching your platform.

## Usage

The game has 2 components: the client and the visualizer. The guide below is for Windows users. For Linux users, the process is very similar.

### Client

To implement a bot, please read the example bot in the example folder.

Edit the `settings.txt` file to adjust your name and the server ip you want to connect to. Your name should match the name of the folder that contains your bot. After that, run `start_client.bat` to start the client. The client will connect to the server and start queuing for a game. Once the game finishes, you should expect to see a `(your_name)vs(enemy_name)_(time).mg25` file in the `logs` folder.

### Visualizer

The visualizer is a seperate program to review you game. To use the visualizer, just run visualizer.exe.

## Self-hosted server

Download the latest server version of the game matching your platform from the `release` section of this repository. Edit the `settings.txt` file to adjust the server settings. After that, run `start_server.bat` to start the server. The server will start listening for clients and you can connect to it using the client. The server will create a `logs` folder in the same directory as the server executable. The logs folder will contain all the game logs.
