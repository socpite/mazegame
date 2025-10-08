"""
Player loader for Python client using dynamic Python modules.
"""
import importlib.util
import sys

_module = None

def load_library(path):
    global _module
    spec = importlib.util.spec_from_file_location("bot_module", path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load module from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    _module = module


def prepare_solver():
    if _module is None:
        raise RuntimeError("Module not loaded")
    _module.prepare_solver()


def get_game(game):
    if _module is None:
        raise RuntimeError("Module not loaded")
    return _module.get_game(game)


def get_move(game):
    if _module is None:
        raise RuntimeError("Module not loaded")
    return _module.get_move(game)
