# The engine

Handles the game.
- Keeps track of the state of the game and the pieces on the board
- consumes moves - both regular and special moves.
- Sends relevant information about the game to the "listener" (most likely, the UI or game "handler" - those parts are not yet planned)


## Consuming moves 
- Gets a valid chess notation for a single turn, attempt to turn it into actual information about the game as a series of events.
- if the result is a valid series of events:
- Sends back an appropriate message to the handler (Possibly an enum: OK, INVALID_MOVE, ILLEGAL_MOVE)
- fail? do nothing
- succesful? manipulate the state. record the move.

## sending relevant information
In order to let the handler know about the game's status,
the engine will need either to make it an event listener and alert it after succesfully consuming a move, or keep a readily available status method that the handler can call.
I'm leaning towards an event system. The information relayed may look something like this:
- a piece moves to an unoccupied position: (MOVE g3 to h4)
- a piece is removed form the board: (REMOVE f2)
- The white king is in check: (CHECK white)
- A pawn has reached the board and has to choose a new piece(may not be needed, if the move already includes this info):
    (CHOOSE d8)

## An outline of the ChessEngine methods

instance variables
- @state - A GameState. keeps all of the game state in one place, and mutates it.
- @parser - A NotationParser. parses the consumed notation.

public methods
- consume(string move) -> message(OK, INVALID_MOVE, ILLEGAL_MOVE) - consume chess notation
- get_board() - current board representation. not strictly needed with a smart handler, except maybe the beginning

private methods
- send(listof info) -> nil