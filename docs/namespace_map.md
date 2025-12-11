# ChessEngine — Namespace Map
A high-level outline of the engine’s components and namespaces.  
Use this as a navigation index; detailed explanations live in the code comments.

**Everything is namespaced under `ChessEngine`.**

## 1. Engine (public interface)
- `Engine`  
- `Engine::GameUpdate`  
- `Engine::SessionInfo`  
- `Engine::GameOutcome`  

## 2. Core workflow
### Parsers
- `Parsers::IdentityParser`  
- `Parsers::ERANParser`  

### Formatters
- `Formatters::ERANLongFormatter`  
- `Formatters::ERANShortFormatter`  
- `Formatters::Validation`  

### Game Model
- `Game::State`  
- `Game::Query`  
- `Game::History`  

### Event Handlers
- `EventHandlers::BaseEventHandler`  
- `EventHandlers::MoveEventHandler`  
- `EventHandlers::EnPassantEventHandler`  
- `EventHandlers::CastlingEventHandler`  

## 3. Domain objects
- `Piece`  
- `Square`  
- `Board`  
- `Position`  

### Events
- `Events::BaseEvent`  
- `Events::MovePieceEvent`  
- `Events::EnPassantEvent`  
- `Events::CastlingEvent`  

## 4. Low-level data types
- `Colors`  
- `CastlingData`  
- `CoreNotation`  

## 5. Internal errors
- `Errors::InvariantViolationError`  
- `Errors::InvalidEventError`  
- `Errors::BoardManipulationError`  
- `Errors::InvalidSquareError`  
- `Errors::InternalError`  
