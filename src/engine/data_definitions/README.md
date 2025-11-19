# `data_definitions/`

This folder contains the core data types used within the engine.
Those include immutable value objects that model engine entities, and primitive static definitions.

# structure
- **Top-level:** meaningful value objects - `Piece`, `Square`, `Board`, `Position`, and events.
- **Subfolders:**
  - `primitives/` - static definitions of core concepts, such as colors and core notation.
  - `components/` - internal dependencies of the top-level types, such as the persistent array underpinning `Board`.