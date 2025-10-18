// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BattleShip
 * @author Your Name
 * @notice A smart contract for a two-player battleship-style game.
 * Players create or join a game, secretly place 5 ship cells on a 64-cell grid,
 * and take turns shooting at each other's grid. The first player to sink all
 * 5 of the opponent's ship cells wins.
 */
contract BattleShip {

    // =============================================================
    //                           STRUCTS
    // =============================================================

    struct Board {
        bool set; // True if the player has submitted their board
        uint64 grid; // 64 bits, each bit represents a cell (1 = ship, 0 = empty)
        uint8 remaining; // Number of remaining ship cells that haven't been hit
    }

    struct Game {
        address[2] players;
        Board board0;
        Board board1;
        uint64 shots0; // A bitmask of player 0's shots on player 1's board
        uint64 shots1; // A bitmask of player 1's shots on player 0's board
        uint8 turn; // 0 for players[0], 1 for players[1]
        address winner;
        GameState state;
    }

    // =============================================================
    //                            ENUMS
    // =============================================================

    enum GameState {
        WAITING, // Waiting for a second player to join
        PLACING, // Players are placing their ships
        ACTIVE, // Game is in progress, players are taking shots
        FINISHED // Game has concluded with a winner
    }

    // =============================================================
    //                          CONSTANTS
    // =============================================================

    uint8 public constant SHIP_CELLS = 5;

    // =============================================================
    //                           STORAGE
    // =============================================================

    mapping(uint256 => Game) public games;
    uint256 public nextGameId;

    // =============================================================
    //                           EVENTS
    // =============================================================

    event GameCreated(uint256 indexed gameId, address indexed player0);
    event PlayerJoined(uint256 indexed gameId, address indexed player1);
    event BoardSubmitted(uint256 indexed gameId, address indexed player);
    event ShotFired(uint256 indexed gameId, address indexed player, uint8 cell);
    event ShotResult(uint256 indexed gameId, address indexed player, uint8 cell, bool hit);
    event GameWon(uint256 indexed gameId, address indexed winner);

    // =============================================================
    //                           ERRORS
    // =============================================================

    error NO_GAME();
    error FULL();
    error SAME();
    error NOT_READY();
    error ALREADY();
    error NOT_PLAYER();
    error NOT_ACTIVE();
    error NOT_YOUR_TURN();
    error INVALID_CELL();
    error BAD_STATE();
    error SHOT_BEFORE();
    error INVALID_BOARD();

    // =============================================================
    //                      GAME SETUP FUNCTIONS
    // =============================================================

    /**
     * @notice Creates a new game and sets the creator as the first player.
     * @return gameId The ID of the newly created game.
     */
    function createGame() external returns (uint256 gameId) {
        gameId = nextGameId++;
        Game storage g = games[gameId];
        g.players[0] = msg.sender;
        g.state = GameState.WAITING;
        emit GameCreated(gameId, msg.sender);
    }

    /**
     * @notice Allows a second player to join an existing game that is waiting for an opponent.
     * @param gameId The ID of the game to join.
     */
    function joinGame(uint256 gameId) external {
        Game storage g = games[gameId];
        if (g.state != GameState.WAITING) revert BAD_STATE();
        if (g.players[0] == address(0)) revert NO_GAME();
        if (g.players[1] != address(0)) revert FULL();
        if (msg.sender == g.players[0]) revert SAME();
        
        g.players[1] = msg.sender;
        g.state = GameState.PLACING;
        emit PlayerJoined(gameId, msg.sender);
    }

    /**
     * @notice Allows a player to submit their board layout.
     * @dev The board layout must contain exactly `SHIP_CELLS` number of ships.
     * The game transitions to ACTIVE state once both players have submitted their boards.
     * @param gameId The ID of the game.
     * @param boardGrid A uint64 bitmask representing the ship placements.
     */
    function submitBoard(uint256 gameId, uint64 boardGrid) external {
        Game storage g = games[gameId];
        if (g.state != GameState.PLACING) revert BAD_STATE();
        if (_countSetBits(boardGrid) != SHIP_CELLS) revert INVALID_BOARD();

        uint8 me;
        if (msg.sender == g.players[0]) {
            me = 0;
        } else if (msg.sender == g.players[1]) {
            me = 1;
        } else {
            revert NOT_PLAYER();
        }
        
        Board storage myBoard = (me == 0) ? g.board0 : g.board1;
        if (myBoard.set) revert ALREADY();

        myBoard.grid = boardGrid;
        myBoard.remaining = SHIP_CELLS;
        myBoard.set = true;
        
        emit BoardSubmitted(gameId, msg.sender);

        // If both players have set their boards, the game can start.
        if (g.board0.set && g.board1.set) {
            g.turn = 0; // Player 0 starts.
            g.state = GameState.ACTIVE;
        }
    }

    // =============================================================
    //                       GAMEPLAY FUNCTIONS
    // =============================================================

    /**
     * @notice Allows a player to take a shot at a specific cell on the opponent's board.
     * @dev Checks for hits, updates game state, and handles win conditions.
     * @param gameId The ID of the game.
     * @param cell The cell to target (0-63).
     */
    function shoot(uint256 gameId, uint8 cell) external {
        Game storage g = games[gameId];
        if (g.state != GameState.ACTIVE) revert NOT_ACTIVE();
        if (cell >= 64) revert INVALID_CELL();

        uint8 me;
        if (msg.sender == g.players[0]) {
            me = 0;
        } else if (msg.sender == g.players[1]) {
            me = 1;
        } else {
            revert NOT_PLAYER();
        }

        if (g.turn != me) revert NOT_YOUR_TURN();

        uint64 bit = (uint64(1) << cell);

        // Check if this cell has already been shot by the player
        if (me == 0) {
            if ((g.shots0 & bit) != 0) revert SHOT_BEFORE();
            g.shots0 |= bit;
        } else {
            if ((g.shots1 & bit) != 0) revert SHOT_BEFORE();
            g.shots1 |= bit;
        }

        emit ShotFired(gameId, msg.sender, cell);

        // Check for hit on the opponent's board
        Board storage targetBoard = (me == 0) ? g.board1 : g.board0;
        bool hit = (targetBoard.grid & bit) != 0;

        if (hit) {
            targetBoard.remaining--;
            emit ShotResult(gameId, msg.sender, cell, true);

            // Check for win condition
            if (targetBoard.remaining == 0) {
                g.state = GameState.FINISHED;
                g.winner = msg.sender;
                emit GameWon(gameId, msg.sender);
                return; // Game is over, no need to switch turn.
            }
        } else {
            emit ShotResult(gameId, msg.sender, cell, false);
        }

        // Switch turn to the other player
        g.turn = 1 - me;
    }

    // =============================================================
    //                        HELPER FUNCTIONS
    // =============================================================

    /**
     * @notice Counts the number of set bits (1s) in a uint64.
     * @dev Used to validate that a player's board submission has the correct number of ships.
     * @param n The uint64 value to count bits from.
     * @return count The number of set bits.
     */
    function _countSetBits(uint64 n) private pure returns (uint8 count) {
        while (n > 0) {
            // This operation clears the least significant set bit.
            n &= (n - 1);
            count++;
        }
    }
}
