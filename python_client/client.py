"""
Client for Python maze game.
"""
import socket
import json
from python_client.cli_handler import init, deinit, server_ip, get_bot_path
from . import playerloader

REQUEST_MAZE_PROTOCOL = "Request maze"
REQUEST_MOVE_PROTOCOL = "Request move"
PREPARE_SOLVER_PROTOCOL = "Prepare solver"

def main():
    init()
    try:
        bot_path = get_bot_path()
        playerloader.load_library(bot_path)
        with socket.create_connection((server_ip, 8080)) as sock:
            file = sock.makefile("rwb")
            while True:
                line = file.readline()
                if not line:
                    break
                message = line.strip().decode()
                if message == PREPARE_SOLVER_PROTOCOL:
                    playerloader.prepare_solver()
                elif message == REQUEST_MAZE_PROTOCOL:
                    raw = file.readline().strip().decode()
                    game = json.loads(raw)
                    new_game = playerloader.get_game(game)
                    resp = json.dumps(new_game)
                    file.write(resp.encode() + b"\n")
                    file.flush()
                elif message == REQUEST_MOVE_PROTOCOL:
                    raw = file.readline().strip().decode()
                    game = json.loads(raw)
                    move = playerloader.get_move(game)
                    resp = json.dumps(move)
                    file.write(resp.encode() + b"\n")
                    file.flush()
                else:
                    print(f"Unknown message: {message}")
    finally:
        deinit()

if __name__ == "__main__":
    main()
