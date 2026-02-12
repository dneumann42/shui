# Shui

A headless immediate-mode UI library with flexbox-style layout.

## What is Shui?

Shui is a simple UI library that handles layout, input, and widget state without rendering. You provide the paint functions, Shui provides the structure. It uses an immediate-mode API where you rebuild your UI every frame.

## Features

- Immediate-mode API
- Flexbox-style layout (Row/Column, Fixed/Fit/Grow sizing)
- Headless (renderer-agnostic)
- Multiple UI roots for layered interfaces
- Widget state management
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
import shui/elements

# Set your painter type (once, at startup)
type MyPainter = object
  # Your renderer state

setPainterType(MyPainter)

# Create UI instance
var ui = UI()
```

### Build UI Each Frame

```nim
ui.begin()  # Start frame

let root = ui.beginElem(Elem(
  size: (
    w: Sizing(kind: Grow),
    h: Sizing(kind: Grow)
  ),
  dir: Col
))

# Add children...

ui.updateLayout((0, 0, 800, 600))  # Layout with viewport size
```

### Sizing Modes

```nim
# Fixed: Exact size
Sizing(kind: Fixed, min: 100, max: 100)

# Fit: Size to content
Sizing(kind: Fit)

# Grow: Fill available space
Sizing(kind: Grow)
```

### Layout Example

```nim
import shui/elements

var ui = UI()
ui.begin()

# Container
let container = ui.beginElem(Elem(
  size: (
    w: Sizing(kind: Fixed, min: 400, max: 400),
    h: Sizing(kind: Fixed, min: 300, max: 300)
  ),
  dir: Col,
  style: Style(
    bg: rgb(40, 40, 40),
    padding: 10,
    gap: 5
  )
))

# Header (fixed height)
let header = ui.beginElem(Elem(
  size: (
    w: Sizing(kind: Grow),
    h: Sizing(kind: Fixed, min: 50, max: 50)
  ),
  text: "Header",
  style: Style(bg: rgb(60, 60, 60))
), container)
ui.add(container, header)

# Content (grows to fill space)
let content = ui.beginElem(Elem(
  size: (
    w: Sizing(kind: Grow),
    h: Sizing(kind: Grow)
  ),
  text: "Content",
  style: Style(bg: rgb(50, 50, 50))
), container)
ui.add(container, content)

# Footer (fixed height)
let footer = ui.beginElem(Elem(
  size: (
    w: Sizing(kind: Grow),
    h: Sizing(kind: Fixed, min: 30, max: 30)
  ),
  text: "Footer",
  style: Style(bg: rgb(60, 60, 60))
), container)
ui.add(container, footer)

ui.updateLayout((0, 0, 800, 600))
```

### Widget State

Widgets can store state across frames using unique IDs:

```nim
type ButtonState = ref object
  clickCount: int

let buttonId = ElemId("my-button")

# Get or create state
if not ui.hasState(buttonId):
  ui.setState(buttonId, ButtonState(clickCount: 0))

var state = ui.getState(buttonId, ButtonState)

# Use widget box for hit testing
if ui.hasBox(buttonId):
  let box = ui.getBox(buttonId)
  # Check if mouse is in box...
  if clicked:
    state.clickCount += 1
```

### Input Handling

```nim
var input = BasicInput()

# Update input state (from your event loop)
input.mousePosition = (x: 100, y: 50)
input.actionPressed = true

# Check input in UI logic
if input.actionPressed:
  echo "Action pressed"
```

### Absolute Positioning

```nim
let overlay = ui.beginElem(Elem(
  size: (
    w: Sizing(kind: Fixed, min: 200, max: 200),
    h: Sizing(kind: Fixed, min: 100, max: 100)
  ),
  absolute: true,
  pos: (x: 50, y: 50),
  style: Style(bg: rgb(100, 100, 200))
))
```

### Multiple Roots

Multiple roots create layered interfaces:

```nim
ui.begin()

# Background UI
let background = ui.beginElem(Elem(
  size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
))

# Overlay UI (rendered on top)
let overlay = ui.beginElem(Elem(
  size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow)),
  absolute: true,
  pos: (x: 0, y: 0)
))

ui.updateLayout((0, 0, 800, 600))

# Iterate all roots
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

# Set box (usually after layout)
ui.setBox(id, 10, 20, 100, 50)

# Get box
if ui.hasBox(id):
  let box = ui.getBox(id)
  echo box.x, ", ", box.y, ", ", box.w, ", ", box.h

# Remove box
ui.removeBox(id)
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
Style(
  bg: Color           # Background color
  fg: Color           # Foreground/text color
  borderColor: Color  # Border color
  border: int         # Border width
  padding: int        # Inner spacing
  gap: int            # Space between children
  borderRadius: float # Corner rounding
  rotation: float     # Rotation in radians
)
```

## Layout Properties

- `dir: Direction` - Row or Col
- `align: Align` - Start, Center, or End (main axis)
- `crossAlign: Align` - Cross axis alignment
- `textAlign: Align` - Text alignment

## Example: Button Widget

```nim
import shui/elements
import chroma

proc button(ui: var UI, id: ElemId, label: string, x, y: int): bool =
  type ButtonState = ref object
    hovered: bool
    pressed: bool

  if not ui.hasState(id):
    ui.setState(id, ButtonState())

  var state = ui.getState(id, ButtonState)
  let input = ui.input

  # Create element
  let elem = ui.beginElem(Elem(
    size: (
      w: Sizing(kind: Fixed, min: 120, max: 120),
      h: Sizing(kind: Fixed, min: 40, max: 40)
    ),
    text: label,
    style: Style(
      bg: if state.pressed: rgb(80, 80, 80)
          elif state.hovered: rgb(60, 60, 60)
          else: rgb(50, 50, 50),
      fg: rgb(255, 255, 255),
      padding: 10
    )
  ))

  # Store position for next frame
  ui.setBox(id, x, y, 120, 40)

  # Check hover and click
  let box = ui.getBox(id)
  let mx = input.mousePosition.x
  let my = input.mousePosition.y

  state.hovered = mx >= box.x and mx < box.x + box.w and
                  my >= box.y and my < box.y + box.h
  state.pressed = state.hovered and input.actionDown

  result = state.hovered and input.actionPressed

# Usage
if ui.button(ElemId("play-btn"), "Play", 100, 100):
  echo "Play button clicked"
```

## Performance

Shui is designed for game UIs with hundreds of elements:
- Tested with 1000+ elements
- Deep nesting supported (50+ levels)
- Immediate-mode overhead is minimal
- No retained state except widget data

## License

MIT
