# Color
The engine has no concept of a player, and instead differentiates between "players" with their repspective color.

This is to avoid confusion later-on with the UI, player, which also includes additional info like a name.

Colors are simple symbols: :black, :white

# Piece types
A piece type is the kind of chess piece it represents - a bishop, rook, etc.

It is a simple enum/enum-like defintion, and does not include the movement patterns.

# Move rules
Describes the movement pattern of a piece.

Does not account for special moves like castling, and pawn movement.

Kept together in a hash or something similar, where each element corresponds to one piece type.

A single element consists of:
- Deltas: a sequence of possible movement deltas. should be used with the actual piece's position to calculate the possible movements.
- repeat: a boolean indicating whether or not the piece can move until it encounters another piece.

# Events
Defined in `./chess_event.md`