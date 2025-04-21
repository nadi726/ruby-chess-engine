Represents a single piece, with all relevant informatiom
A piece does not hold the logic of handling any of the piece's moves - only the available positions

# Outline

instance variables
- @color
- @type - pawn, bishop, etc. (enum)
- @position

methods
- readers for instance variables
- writer for @position
- possible_moves
- attacking - what positions its attacking(uses @type and @position)
