# Explicit Readable Algebraic Notation

Explicit Readable Algebraic Notation, or ERAN, is a custom chess notation made specifically for this engine.
It is heavily inspired by LAN(Long Algebraic Notation) - especially the human-leaning flavors - and also takes notes from SAN(Standard Algebraic Notation).
It is designed to be easy to parse, human-readable, and to represent chess moves as intuitively as possible.
In short: it is mostly verbose, except where it isn't.

# Core principles
Since the notation aims to be both easy to parse and easy to read, it is:
- Deterministic - there are never any ambiguities.
- Explicit for regular moves - includes piece type(even for pawns), origin and destination squares, and an explicit capture indicator.
- Includes special identifiers for castling and enpassant, replacing regular move notation.
- Flexible in readability - most constructs have both shortform and longform.

# Examples

| Move Type                  | ERAN (verbose)             | ERAN (short)          | Traditional human LAN          | SAN (official, no ambiguity) |
|----------------------------|----------------------------|-----------------------|--------------------------------|------------------------------|
| Quiet pawn move            | `Pawn e2-e4`               | `P e2-e4`             | `e2-e4`                        | `e4`                         |
| Quiet piece move           | `Knight b1-c3`             | `N b1-c3`             | `Nb1-c3` or `N b1-c3`          | `Nc3`                        |
| Normal capture (non-pawn)  | `Rook a1xa8`               | `R a1xa8`             | `Ra1xa8` or `R a1xa8`          | `Rxa8`                       |
| Pawn capture               | `Pawn f5xe6`               | `P f5xe6`             | `f5xe6`                        | `fxe6`                       |
| Promotion                  | `Pawn g7-g8 ->Queen`       | `P g7-g8 >Q`           | `g7-g8=Q` or `g7g8Q`           | `g8=Q`                       |
| Kingside castling          | `castling-kingside`        | `ck`                  | `O-O` (rarely `e1-g1`)         | `O-O`                        |
| Queenside castling         | `castling-queenside`       | `cq`                  | `O-O-O` (rarely `e1-c1`)       | `O-O-O`                      |
| En passant (as regular move)| `Pawn e5xd6`              | `P e5xd6`             | `e5xd6` (sometimes + e.p.)     | `exd6` (rarely + e.p.)       |
| En passant (as explicit)  | `en-passant`                | `ep`                  | — (no shortcut)                | — (no shortcut)              |

# A detailed explanation
Regular moves - everything except the special move identifiers for castling and enpassant(`ck`, `ep`, etc) - are always verbose.
This means that:
- the piece type is always required - even for pawns.
- full origin and destination squares are required.
- Specifying whether its a capture or not is required.

However, the notation is less verbose than some in parts:
- check, checkmate and other annotations are never specified.
- Not only castling, but enpassant can be written in a special form - `ep` or `en-passant`.
  It can also be written as a regular move with capture.

It should also be noted that everything is case-insensitive.

Regular moves start with the moving piece's type, separated by space from the movement info.
Piece names can be either shortform(`b`, `n`, etc, like in standard), or longform - the full piece name (e.g. `Pawn`).

Like in LAN, origin and destination squares are separated by `-` for silent moves, and `x` for captures.
A promotion is specified in a separate optional field, separated by space, with either `->` or `>` followed directly by the piece type.

## Formal specification
See the [EBNF file](ERAN.ebnf).