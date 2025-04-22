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
// Avoid using stdin and stdout. Please print to a file or use cerr for debugging.

namespace example{
    int example_variable = 0;
    mt19937 rng(chrono::steady_clock::now().time_since_epoch().count());
    bool vis[105][105];
    pair<int, int> prv[105][105];
    bool check_inbound(Game &game, pair<int, int> pos) {
        return pos.first >= 0 && pos.first < game.n && pos.second >= 0 && pos.second < game.m;
    }
    pair<int, int> random_pos(Game &game) {
        return {rng() % game.n, rng() % game.m};
    }
    const pair<int, int> mv[4] = {
        {1, 0}, // DOWN
        {-1, 0}, // UP
        {0, 1}, // RIGHT
        {0, -1} // LEFT
    };

    MoveType get_move_type(pair<int, int> start_pos, pair<int, int> end_pos) {
        if (start_pos.first < end_pos.first) {
            return DOWN;
        } else if (start_pos.first > end_pos.first) {
            return UP;
        } else if (start_pos.second < end_pos.second) {
            return RIGHT;
        } else if (start_pos.second > end_pos.second) {
            return LEFT;
        }
        return ITEM; // Default case
    }
    void reset() {
        memset(vis, 0, sizeof(vis));
    }
}

// This function should return a game, given an intial game state.
// game.horizontal_walls is a 2D array of size (n-1) x m, where each element determines if there is a wall between the cell (i, j) and (i+1, j).
// game.vertical_walls is a 2D array of size n x (m-1), where each element determines if there is a wall between the cell (i, j) and (i, j+1).
// game.item_board is a 2D array of size n x m, where each element is the item name in the cell (i, j).
Game create_maze(Game game) {
    example::reset();
    for (auto &row : game.horizontal_walls) {
        row.assign(row.size(), true);
    }
    for (auto &row : game.vertical_walls) {
        row.assign(row.size(), true);
    }
    game.start_pos = example::random_pos(game);
    game.end_pos = example::random_pos(game);

    while (game.start_pos == game.end_pos) {
        game.end_pos = example::random_pos(game);
    }

    queue<pair<int, int>> q;
    q.push(game.start_pos);
    example::vis[game.start_pos.first][game.start_pos.second] = true;

    while(!q.empty()) {
        auto cur = q.front();
        q.pop();
        vector<pair<int, int>> next_pos;
        for (int i = 0; i < 4; i++) {
            int x = cur.first + example::mv[i].first;
            int y = cur.second + example::mv[i].second;
            if (example::check_inbound(game, {x, y}) && !example::vis[x][y]) {
                next_pos.push_back({x, y});
                example::vis[x][y] = true;
            }
        }
        shuffle(next_pos.begin(), next_pos.end(), example::rng);
        for (auto &pos : next_pos) {
            int x = pos.first;
            int y = pos.second;
            if (cur.first == x) {
                game.vertical_walls[cur.first][min(cur.second, y)] = false;
            } else {
                game.horizontal_walls[min(cur.first, x)][cur.second] = false;
            }
            q.push(pos);
        }
    }
    return game;
}

void prepare_solver() {
    // This function is called before solving a new maze.
    // You can use this function to initialize any variables or data structures.
    example::reset();
}

// This function should return a move, given the game state.
GameMove get_move(Game game) {
    example::vis[game.start_pos.first][game.start_pos.second] = true;
    for (auto nw: example::mv) {
        int x = game.start_pos.first + nw.first;
        int y = game.start_pos.second + nw.second;

        // Check if the move is within bounds
        if (!example::check_inbound(game, {x, y}) || example::vis[x][y]) continue;

        // Check if there is a wall in the direction of the move
        if (nw.first == 1 && game.horizontal_walls[game.start_pos.first][game.start_pos.second]) continue;
        if (nw.first == -1 && game.horizontal_walls[game.start_pos.first - 1][game.start_pos.second]) continue;
        if (nw.second == 1 && game.vertical_walls[game.start_pos.first][game.start_pos.second]) continue;
        if (nw.second == -1 && game.vertical_walls[game.start_pos.first][game.start_pos.second - 1]) continue;

        example::prv[x][y] = game.start_pos;
        return GameMove{example::get_move_type(game.start_pos, {x, y}), ""};
    }

    // If no move is possible, go back
    return GameMove{example::get_move_type(game.start_pos, example::prv[game.start_pos.first][game.start_pos.second]), ""};
}
