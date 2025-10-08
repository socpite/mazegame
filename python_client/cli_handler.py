"""
CLI handler for Python client.
"""

import argparse
import os
import sys

server_ip = "127.0.0.1"
bot_name = ""

def init():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ip", default="127.0.0.1", help="Server IP address")
    parser.add_argument("--name", required=True, help="Bot directory name")
    args = parser.parse_args()
    global server_ip, bot_name
    server_ip = args.ip
    bot_name = args.name

def deinit():
    pass

def get_bot_path():
    bot_dir = os.path.join(os.getcwd(), bot_name)
    return os.path.join(bot_dir, "bot.py")
