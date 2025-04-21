# Chess event
Each move is first translated from chess notation into a command for the board.
The board then attempts to use this single action and determine what series of
actions are needed to turn this action into a valid chess move, complete with all of the board manipulations needed.
For example, let's say the white queen is at g4, and it's white's turn. this move "Qg5" is interpreted as:
1. Try to move the white queen to g5
2. If this is not a valid move, for whatever reason(for example, it is occupied by a piece of the same color), stop
3. if the given position is empty, we're done. the series of moves is simply [[move, g4, g5]]
4. If the position is occupied by a black piece, add [remove g5] to the front of the list
5. if the black king is now at check, add [check black]
So, the result can be either none, [[move, g4, g5]],[[remove g5], [move, g4, g5]], [[remove g5], [move, g4, g5], [check black]] or [[move, g4, g5], [check black]]

## The events

### Board manipulation events
* MovePiece(from, to) # Doesn't remove existing piece at "to"
* RemovePiece(position)
* Promote(Position, new_piece)
* castling
    * Castling(side)
    * Castling(king_end_position, rook_start_position, rook_end_position)
* EnPessant
    * EnPassant(from, to)
    * EnPassant(from, to, captured_position)

### Game state change events
* check(color)
* checkmate(color)
* Draw(optional: reason)

### Special input events
* ChoosePromotion(position)