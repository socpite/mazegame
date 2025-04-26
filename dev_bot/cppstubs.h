#include<bits/stdc++.h>
#include "stdio.h"
using namespace std;

struct GameRule {
    bool predetermined_walls = false; // Walls must not be changed
    bool predetermined_items = false; // Items must not be changed
    int min_item_count = 0; // Minimum number of items
};


struct Game {
    int n, m;
    vector<vector<bool>> vertical_walls;
    vector<vector<bool>> horizontal_walls;	
    vector<vector<string>> item_board;
    pair<int, int> start_pos = {0, 0};
    pair<int, int> end_pos = {0, 0};
    vector<string> item_types;
    GameRule rule;

    Game(int n, int m) : n(n), m(m){
        vertical_walls.assign(n, vector<bool>(m-1, false));
        horizontal_walls.assign(n-1, vector<bool>(m, false));
        item_board.assign(n, vector<string>(m, ""));
        end_pos = {n-1, m-1};
    }
    
    // Fuctions bellow are only for following the C ABI. You can directly modify the Game object

    void set_start_pos(int x, int y) {
        start_pos = {x, y};
    }
    void set_end_pos(int x, int y) {
        end_pos = {x, y};
    }
    void add_item_type(const char* item) {
        item_types.push_back(string(item));
    }
    void set_item_board(int x, int y, const char* item) {
        item_board[x][y] = string(item);
    }
    void set_vertical_wall(int x, int y, bool wall) {
        vertical_walls[x][y] = wall;
    }
    void set_horizontal_wall(int x, int y, bool wall) {
        horizontal_walls[x][y] = wall;
    }
};

enum MoveType {
    UP,
    DOWN,
    LEFT,
    RIGHT,
    ITEM,
};

struct GameMove {
    MoveType type;
    string item_name;
};

Game create_maze(Game game); 

GameMove get_move(Game game); 


#ifdef __cplusplus
extern "C" {
#endif

    void prepare_solver();
    void test() {
        cout << "Test function called" << endl;
    }
    Game* create_game(int n, int m) {
        return new Game(n, m);
    }
    GameMove* get_move(Game* game) {
        GameMove* move = new GameMove();
        *move = get_move(*game);
        return move;
    }
    Game* get_maze(Game* game) {
        return new Game(create_maze(*game));
    }
    void set_start_pos(Game* game, int x, int y) {
        game->set_start_pos(x, y);
    }
    void set_end_pos(Game* game, int x, int y) {
        game->set_end_pos(x, y);
    }
    void add_item_type(Game* game, const char* item) {
        game->add_item_type(item);
    }
    void set_item(Game* game, int x, int y, const char* item) {
        game->set_item_board(x, y, item);
    }
    void set_game_rule(Game* game, bool predetermined_walls, bool predetermined_items, int min_item_count) {
        game->rule.predetermined_walls = predetermined_walls;
        game->rule.predetermined_items = predetermined_items;
        game->rule.min_item_count = min_item_count;
    }
    void set_vertical_wall(Game* game, int x, int y, bool wall) {
        game->set_vertical_wall(x, y, wall);
    }
    void set_horizontal_wall(Game* game, int x, int y, bool wall) {
        game->set_horizontal_wall(x, y, wall);
    }
    const char* get_item_name(GameMove* move) {
        return move->item_name.c_str();
    }
    const char* get_move_type(GameMove* move) {
        switch (move->type) {
            case UP: return "Up";
            case DOWN: return "Down";
            case LEFT: return "Left";
            case RIGHT: return "Right";
            case ITEM: return "Item";
        }
        return "";
    }
    int* get_start_pos(Game* game) {
        int* pos = new int[2];
        pos[0] = game->start_pos.first;
        pos[1] = game->start_pos.second;
        return pos;
    }
    int* get_end_pos(Game* game) {
        int* pos = new int[2];
        pos[0] = game->end_pos.first;
        pos[1] = game->end_pos.second;
        return pos;
    }
    bool get_vertical_wall(Game* game, int x, int y) {
        return game->vertical_walls[x][y];
    }
    bool get_horizontal_wall(Game* game, int x, int y) {
        return game->horizontal_walls[x][y];
    }
    const char* get_item(Game* game, int x, int y) {
        return game->item_board[x][y].c_str();
    }
    int get_width(Game* game) {
        return game->m;
    }
    int get_height(Game* game) {
        return game->n;
    }

#ifdef __cplusplus
}
#endif
