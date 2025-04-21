The GameState is responsible solely for the manipluation of the state and giving information about it.
It does not include any rule-checking logic, for example.

- Keeps track of all of the state - available pieces, positions, moves that can be performed, etc
- receives a series of moves and updates accordingly
- queries for checking where is what and what moves are available

# Outline
 instance variables
 - @board - the board, organized by ranks and files (maybe gnerate it on-demand from the pieces? or the inverse?)
 - @white - pieces for white
 - @black - pieces for black
 - @current_player - points to @black/@white, depending on turn
 - @other_player - points to the other player
 - @move_history - a record of all moves performed

 public methods
 - apply_events(events) - assumes a valid series of moves. perform the moves, manipulate the state, record the move, and switch the active player.
 - query methods
    - attacking(position, color) - array of pieces of color attacking the position
    - occupying(position) - piece occupying, or nil
    - possibly more. will become clearer as design advances

private methods
- switch_player