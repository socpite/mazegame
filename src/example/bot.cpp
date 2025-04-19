#include <bits/stdc++.h>
#include "cppstubs.h"
using namespace std;
/*
    * This is an example for the bot.
    * You can use this file to write your bot.
    * The bot will be compiled and run in a separate process.
    * The bot will be given the game state as input and should output the move to make.
*/

// You can define any variable or function, but you should wrap them in a namespace to avoid name clashes with the game engine.

namespace example {
    int example_variable = 0;
}

// This function should return a game, given an intial game state.
// game.horizontal_walls is a 2D array of size (n-1) x m, where each element determines if there is a wall between the cell (i, j) and (i+1, j).
// game.vertical_walls is a 2D array of size n x (m-1), where each element determines if there is a wall between the cell (i, j) and (i, j+1).
// game.item_board is a 2D array of size n x m, where each element is the item name in the cell (i, j).
Game create_maze(Game game) {
    game.vertical_walls[0][0] = true;
    return game;
}

// This function should return a move, given the game state.
GameMove get_move(Game game) {
    GameMove move;
    if (game.start_pos.first < game.end_pos.first) {
        move.type = DOWN;
    } else if (game.start_pos.first > game.end_pos.first) {
        move.type = UP;
    } else if (game.start_pos.second < game.end_pos.second) {
        move.type = RIGHT;
    } else if (game.start_pos.second > game.end_pos.second) {
        move.type = LEFT;
    }
    return move;
}
