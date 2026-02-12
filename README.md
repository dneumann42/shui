# Shui

A headless immediate-mode UI library with flexbox-style layout.

## What is Shui?

Shui is a UI library that handles layout, input, and widget state without rendering. You provide the paint functions, Shui provides the structure. It uses an immediate-mode API where you rebuild your UI every frame.

## Features

- Declarative DSL with the `elem` and `widget` macros
- Immediate-mode API
- Flexbox-style layout (Row/Column, Fixed/Fit/Grow sizing)
- Headless (renderer-agnostic)
- Multiple UI roots for layered interfaces
- Widget state management with signals
- Absolute and floating positioning
- Input handling (mouse, keyboard, scroll)
- Compile-time debug mode

## Installation

```nim
requires "shui"
requires "chroma"  # For colors
```

## Basic Usage

### Setup

```nim
import shui

# Set your painter type (once, at startup)
type MyPainter = object
  # Your renderer state

setPainterType(MyPainter)

# Create UI instance
var ui = UI()
```

### Build UI with the DSL

The `elem` macro provides a clean declarative syntax:

```nim
ui.begin()  # Start frame

elem:
  size = (w: Grow, h: Grow)
  dir = Col
  style = style(bg = color(0.2, 0.2, 0.3), padding = 10)

  # Header
  elem:
    size = (w: Grow, h: Fixed)
    text = "My App"
    style = style(padding = 5)

  # Content
  elem:
    size = (w: Grow, h: Grow)
    dir = Row
    style = style(gap = 8)

    # Left panel
    elem:
      size = (w: Fixed, h: Grow)
      style = style(bg = color(0.3, 0.3, 0.4))

    # Right panel
    elem:
      size = (w: Grow, h: Grow)
      style = style(bg = color(0.25, 0.25, 0.35))

ui.updateLayout((0, 0, 800, 600))
```

### Sizing Modes

```nim
# Fixed: Exact size (defaults to max value if not specified)
size = (w: Fixed, h: Fixed)  # Uses min/max from parent context

# Fit: Size to content
size = (w: Fit, h: Fit)

# Grow: Fill available space
size = (w: Grow, h: Grow)

# Mixed
size = (w: Fixed, h: Grow)
```

### Layout Example

```nim
import shui

var ui = UI()
ui.begin()

elem:
  size = (w: Fixed, h: Fixed)
  dir = Col
  align = Center
  crossAlign = Center
  style = style(
    bg = color(0.15, 0.15, 0.2),
    padding = 10,
    gap = 5
  )

  # Header
  elem:
    size = (w: Grow, h: Fit)
    text = "Header"
    style = style(bg = color(0.2, 0.2, 0.3), padding = 8)

  # Content area
  elem:
    size = (w: Grow, h: Grow)
    dir = Row
    style = style(gap = 10)

    # Sidebar
    elem:
      size = (w: Fixed, h: Grow)
      style = style(bg = color(0.18, 0.18, 0.25))

    # Main content
    elem:
      size = (w: Grow, h: Grow)
      style = style(bg = color(0.22, 0.22, 0.3))

  # Footer
  elem:
    size = (w: Grow, h: Fit)
    text = "Footer"
    style = style(bg = color(0.2, 0.2, 0.3), padding = 8)

ui.updateLayout((0, 0, 800, 600))
```

### Buttons with onClick

```nim
import shui

elem:
  size = (w: Grow, h: Grow)
  dir = Col
  align = Center

  button("Click Me", ElemId"my-button"):
    onClick:
      echo "Button clicked!"

  button("Toggle", ElemId"toggle-btn"):
    toggle = On  # or Off
    onClick:
      echo "Toggled"
```

### Stateful Widgets

The `widget` macro creates reusable components with local state and signals:

```nim
import shui

widget Counter:
  state:
    count: int = 0

  signals:
    onIncrement()
    onDecrement()

  render():
    elem:
      size = (w: Fit, h: Fit)
      dir = Col
      align = Center
      style = style(bg = color(0.2, 0.2, 0.3), padding = 10, gap = 5)

      elem:
        text = "Count: " & $state.count
        size = (w: Grow, h: Fit)

      elem:
        size = (w: Grow, h: Fit)
        dir = Row
        style = style(gap = 5)

        button("−", ElemId"dec-btn"):
          onClick:
            state.count -= 1
            emit onDecrement

        button("+", ElemId"inc-btn"):
          onClick:
            state.count += 1
            emit onIncrement

# Usage
var counter = Counter()

# Connect to signals
counter.onIncrement.connect(proc() =
  echo "Incremented!"
)

ui.begin()
counter.render()
ui.updateLayout((0, 0, 800, 600))
```

### Widget with Events

Widgets can define custom events for internal logic:

```nim
widget TodoList:
  state:
    items: seq[string] = @[]
    inputText: string = ""

  event:
    AddItem
    RemoveItem(index: int)
    UpdateInput(text: string)

  handle(evt):
    case evt.kind
    of AddItem:
      state.items.add(state.inputText)
      state.inputText = ""
    of RemoveItem:
      state.items.delete(evt.index)
    of UpdateInput:
      state.inputText = evt.text

  render():
    elem:
      size = (w: Grow, h: Grow)
      dir = Col
      style = style(padding = 10, gap = 5)

      # Input area
      elem:
        size = (w: Grow, h: Fit)
        dir = Row
        style = style(gap = 5)

        # Text input would go here
        button("Add", ElemId"add-btn"):
          onClick:
            emit AddItem

      # Item list
      for i, item in state.items:
        elem:
          size = (w: Grow, h: Fit)
          dir = Row
          text = item

          button("X", ElemId("remove-" & $i)):
            onClick:
              emit RemoveItem(index: i)
```

### Input Handling

```nim
var input = BasicInput()

# Update input state (from your event loop)
input.mousePosition = (x: 100, y: 50)
input.actionPressed = true

# Use in UI logic
if input.actionPressed:
  echo "Action pressed"
```

### Absolute Positioning

```nim
elem:
  size = (w: Fixed, h: Fixed)
  absolute = true
  pos = (x: 50, y: 50)
  style = style(bg = color(0.4, 0.4, 0.6))
```

### Multiple Roots

Multiple roots create layered interfaces:

```nim
ui.begin()

# Background layer
elem:
  size = (w: Grow, h: Grow)
  # Background UI here

# Overlay layer
elem:
  size = (w: Grow, h: Grow)
  absolute = true
  pos = (x: 0, y: 0)
  # Overlay UI here

ui.updateLayout((0, 0, 800, 600))

# Render all roots
for root in ui.roots:
  # Paint this root's tree
```

## Rendering

Shui is headless. You provide paint functions:

```nim
proc paintElem(painter: var MyPainter, elem: Elem) =
  # Draw background
  painter.drawRect(elem.box.x, elem.box.y, elem.box.w, elem.box.h, elem.style.bg)

  # Draw text
  if elem.text.len > 0:
    painter.drawText(elem.box.x, elem.box.y, elem.text, elem.style.fg)

  # Draw border
  if elem.style.border > 0:
    painter.drawBorder(elem.box, elem.style.border, elem.style.borderColor)

# Paint all elements
for elem in ui.elems:
  painter.paintElem(elem)
```

## Widget Box API

Track widget positions for hit testing:

```nim
let id = ElemId("button")

# Boxes are automatically tracked during layout
if ui.hasBox(id):
  let box = ui.getBox(id)
  # Check if mouse is inside
  let mouseInside =
    mx >= box.x and mx < box.x + box.w and
    my >= box.y and my < box.y + box.h
```

## Debug Mode

Enable debug visualization:

```nim
# Compile with -d:shuiDebug
nim c -d:shuiDebug myapp.nim
```

Debug mode adds:
- Layout calculation logging
- Element creation/destruction logs
- Statistics (element count, roots, etc.)

## Style Properties

```nim
style(
  bg = color(r, g, b, a)      # Background color
  fg = color(r, g, b, a)      # Foreground/text color
  borderColor = color(...)    # Border color
  border = 2                  # Border width
  padding = 10                # Inner spacing
  gap = 8                     # Space between children
  borderRadius = 0.05         # Corner rounding
  rotation = 0.0              # Rotation in radians
)
```

## Layout Properties

Inside `elem` blocks:

```nim
elem:
  dir = Col              # or Row
  align = Center         # Start, Center, End (main axis)
  crossAlign = Start     # Cross axis alignment
  textAlign = Center     # Text alignment
  size = (w: Grow, h: Fit)
  style = style(...)
```

## Complete Example

```nim
import shui

# Setup
type MyPainter = object
setPainterType(MyPainter)

var ui = UI()

# Define a counter widget
widget AppWidget:
  state:
    count: int = 0
    showOverlay: bool = false

  render():
    elem:
      size = (w: Grow, h: Grow)
      dir = Col
      align = Center
      crossAlign = Center
      style = style(bg = color(0.1, 0.1, 0.15), padding = 20, gap = 10)

      elem:
        text = "Counter Example"
        size = (w: Grow, h: Fit)
        style = style(fg = color(1.0, 1.0, 1.0), padding = 10)

      elem:
        text = "Count: " & $state.count
        size = (w: Grow, h: Fit)
        style = style(fg = color(0.8, 0.8, 0.8))

      elem:
        size = (w: Fit, h: Fit)
        dir = Row
        style = style(gap = 5)

        button("Decrement", ElemId"dec"):
          onClick:
            state.count -= 1

        button("Increment", ElemId"inc"):
          onClick:
            state.count += 1

        button("Reset", ElemId"reset"):
          onClick:
            state.count = 0

      button("Toggle Overlay", ElemId"overlay-btn"):
        toggle = (if state.showOverlay: On else: Off)
        onClick:
          state.showOverlay = not state.showOverlay

    # Overlay
    if state.showOverlay:
      elem:
        size = (w: Grow, h: Grow)
        absolute = true
        pos = (x: 0, y: 0)
        style = style(bg = color(0.0, 0.0, 0.0, 0.7))
        align = Center
        crossAlign = Center

        elem:
          size = (w: Fixed, h: Fixed)
          style = style(bg = color(0.2, 0.2, 0.3), padding = 20)
          text = "Overlay Active"

          button("Close", ElemId"close-overlay"):
            onClick:
              state.showOverlay = false

# Main loop
var app = AppWidget()

while running:
  # Handle events and update input
  # ...

  ui.begin()
  app.render()
  ui.updateLayout((0, 0, 800, 600))

  # Render
  for elem in ui.elems:
    painter.paintElem(elem)
```

## API Reference

### Core Macros

- `elem: body` - Create an element with declarative syntax
- `widget Name: ...` - Define a stateful widget
- `button(text, id): ...` - Create a button with onClick handler

### Widget Sections

- `state:` - Define widget state fields
- `signals:` - Define outgoing signals
- `event:` - Define custom event types
- `handle(evt):` - Handle custom events
- `init:` - Initialization code
- `render():` - Render function

### Element Properties

Set inside `elem` blocks using `=`:

- `size` - `(w: SizingKind, h: SizingKind)`
- `dir` - `Row` or `Col`
- `align` - `Start`, `Center`, `End`
- `crossAlign` - Cross axis alignment
- `textAlign` - Text alignment
- `text` - Element text content
- `style` - Style properties
- `absolute` - Absolute positioning flag
- `pos` - `(x: int, y: int)` for absolute position
- `floating` - Floating element flag
- `scrollable` - Enable scrolling

### UI Methods

- `begin()` - Start new frame
- `updateLayout(container)` - Compute layout
- `hasBox(id): bool` - Check if widget has box
- `getBox(id): tuple[x,y,w,h]` - Get widget position
- `setState(id, state)` - Set widget state
- `getState(id, Type): Type` - Get widget state
- `hasState(id): bool` - Check if widget has state

## Performance

Shui is designed for game UIs with hundreds of elements:
- Tested with 1000+ elements
- Deep nesting supported (50+ levels)
- Immediate-mode overhead is minimal
- No retained state except widget data

## License

MIT
