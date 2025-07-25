# `event_handlers/`

This folder contains all classes responsible for handling chess events.

## How the Event System Works

1. The `Engine` provides a sequence of events to the event handler. This sequence represents the current move as "understood" by the UI or user input.
2. One event must be designated as the *main* event (e.g. `MovePieceEvent`). The rest are *extra* events (e.g. `RemovePieceEvent`, `CheckEvent`) that provide additional intent or information.
3. The main event determines which specific event handler class is responsible for processing the sequence.
4. The handler validates the events against the current `GameState`, resolves ambiguities, fills in missing data, and returns a full, valid list of events.
5. If the event sequence is invalid (e.g. violates rules or is inconsistent), an error object is returned instead.

## Included Files

- `init.rb` – Entry point that requires all handlers. Includes a factory method for creating handlers.
- `event_handler.rb` – Base class for shared logic.
- `event_result.rb` - Data defintion for the proccessed handling result.
- Event-specific handlers:
  - `move_event_handler.rb`
  - `en_passant_event_handler.rb`
  - `castle_event_handler.rb` *(placeholder – not implemented yet)*
