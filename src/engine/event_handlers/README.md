# `event_handlers/`

This folder contains all classes responsible for handling chess events.

## How the Event System Works

1. The `Engine` provides an event. This event represents the current move as "understood" by the UI or user input.
2. The `event_handler_for` factory produces the specific event handler for the provided event.
3. The handler validates the event against the current `GameState`, resolves ambiguities, fills in missing data, and returns an   appropriate `EventResult`:
    - If processing was succseful, an `EventResult.success` with a full, valid event.
    - If processing failed, an `EventResult.failure` with an error message.

## Included Files

- `init.rb` – Entry point that requires all handlers. Includes a factory method for creating handlers.
- `event_handler.rb` – Base class for shared logic.
- `event_result.rb` - Data defintion for the proccessed handling result.
- Event-specific handlers:
  - `move_event_handler.rb`
  - `en_passant_event_handler.rb`
  - `castling_event_handler.rb` *(placeholder – not implemented yet)*
