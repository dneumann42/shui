# Shui Debug Mode

Comprehensive debugging and visualization tools for testing and validating Shui layouts.

## Enabling Debug Mode

Debug mode is controlled by a compile-time constant. Enable it when compiling:

```bash
nim c -d:shuiDebug your_app.nim
```

## Features

### 1. Console Logging

When debug mode is enabled, Shui logs:
- Element creation with IDs
- Root additions
- Layout statistics

Example output:
```
[Shui Debug] Created elem 0: @oid12345
[Shui Debug] Added root 0 (total roots: 1)
[Shui Debug] Created elem 1: @oid12346
```

### 2. Visual Debug Overlay

Draw colored boxes around all UI elements with detailed information:

```nim
import shui

when shuiDebug:
  # Set up debug drawing (call once during initialization)
  setDebugDrawProc proc(x, y, w, h: int, color: Color, text: string) =
    # Draw a rectangle outline
    drawing.drawRect(x, y, w, h, color)
    # Draw debug text
    if text.len > 0:
      drawing.drawText(x + 2, y + 2, text, color)

# After drawing UI
ui.draw()
when shuiDebug:
  ui.drawDebugOverlay()  # Draws debug visualization on top
```

**Color Coding:**
- 🟢 **Green** - Normal flow elements
- 🟡 **Yellow** - Root elements
- 🟠 **Orange** - Floating elements
- 🟣 **Magenta** - Absolute positioned elements

**Information Displayed:**
- Element index number
- Sizing constraints (Fixed/Fit/Grow)
- Actual box dimensions (WxH @ X,Y)
- Special flags (Float, Abs, ROOT)

### 3. Layout Tree Dump

Print the entire UI hierarchy to console:

```nim
when shuiDebug:
  ui.dumpLayoutTree()
```

Example output:
```
========== Shui Layout Tree ==========
Total Elements: 15
Roots: 2

--- Root 0 (Element 0) ---
Elem 0 [ROOT]:
  Size: Grow x Grow
  Box: 800x600 @ (0,0)
  Style: dir=Col, align=Start, gap=8
  Children: 3
    Elem 1:
      Size: Grow x Fit
      Box: 800x40 @ (0,0)
      Text: 'Debug Menu'
      Children: 2
        Elem 2:
          Size: Fit x Fit
          Box: 60x30 @ (0,5)
          Text: 'Button'
...
```

### 4. Debug Statistics

Access runtime statistics:

```nim
when shuiDebug:
  echo "Elements created: ", ui.debug.elemCount
  echo "Active roots: ", ui.debug.rootCount
  echo "Draw calls: ", ui.debug.drawCalls
```

## Testing Checklist

Use debug mode to validate:

- ✅ **Multiple Roots** - Each root shows as yellow with "ROOT" label
- ✅ **Layout Flow** - Check that Row/Col direction works correctly
- ✅ **Sizing** - Verify Fixed/Fit/Grow calculations
- ✅ **Absolute Positioning** - Magenta boxes should be at exact coordinates
- ✅ **Floating Elements** - Orange boxes should overlay properly
- ✅ **Gaps & Padding** - Visual spacing between elements
- ✅ **Alignment** - Start/Center/End alignment within containers
- ✅ **Nesting** - Deep hierarchies display correctly
- ✅ **Z-Order** - Later roots appear on top

## Performance Impact

Debug mode has **zero overhead** when disabled (compile-time `when` blocks).

When enabled:
- Adds ~1-2ms per frame for logging
- Visual overlay adds ~0.5ms for drawing
- No runtime cost in release builds

## Example Integration

```nim
import beyond, shui

when isMainModule:
  # ... initialize window, renderer ...

  when shuiDebug:
    # Set up debug visualization
    setDebugDrawProc proc(x, y, w, h: int, color: Color, text: string) =
      var rect = SDL_FRect(x: x.float, y: y.float, w: w.float, h: h.float)
      SDL_SetRenderDrawColor(renderer,
        uint8(color.r * 255), uint8(color.g * 255),
        uint8(color.b * 255), uint8(color.a * 255))
      SDL_RenderRect(renderer, addr rect)

      if text.len > 0:
        # Draw text with your text rendering system
        discard

  # Main loop
  while running:
    ui.begin()

    # Build UI...
    elem:
      size = (w: Grow, h: Grow)
      # ...

    # Layout and draw
    ui.updateLayout((0, 0, 800, 600))
    ui.draw()

    when shuiDebug:
      ui.drawDebugOverlay()  # Visualize layout

      # Log tree periodically
      if frameCount mod 60 == 0:
        ui.dumpLayoutTree()
```

## Tips

1. **Start Simple** - Test with single root before adding complexity
2. **Check Boundaries** - Visual overlay shows exact element boxes
3. **Validate Roots** - Ensure expected number of roots are created
4. **Test Edge Cases** - Try empty elements, zero sizes, deep nesting
5. **Performance** - Use stats to track element count growth
