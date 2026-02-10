# Shui Widget Macro Tests

Comprehensive test suite for the Shui widget macro system.

## Running Tests

```bash
# From the shui directory
nim c -r tests/twidgets.nim

# Or using nimble
nimble test
```

## Test Coverage

### Basic Widget Features (Tests 1-7)

1. **Widget with state** - Basic widget creation and state initialization
2. **Stateless widget** - Widgets without state section
3. **Widget with events** - Event definitions and event types
4. **Parameterless render** - `render:` without parameters (auto-adds `ui: var UI`)
5. **Render with custom parameters** - Custom parameter lists
6. **Widget with slot** - Template generation for `slot: untyped` parameter
7. **Stateless widget with slot** - Combining stateless + slot features

### Child Widget Communication (Tests 8-9, 16)

8. **Child widget events** - Parent handling child widget events via `onEvent`
9. **Multiple child widgets** - Multiple children with independent event handling
16. **Widget with own and child events** - Both `handle(evt):` and `handle:` sections

### Event System (Tests 3, 10, 14)

3. **Widget with events** - Event enumeration and event types
10. **Events with data** - Events carrying data fields
14. **Complex event hierarchy** - Nested events, child-to-parent propagation

### State Management (Tests 11-13, 19)

11. **State field type inference** - Automatic type inference from default values
12. **State field with explicit type** - Explicit type annotations
13. **Nested widget composition** - Three-level widget nesting
19. **Widget with complex state types** - Custom objects, sequences, options

### Type System (Tests 1, 18)

1. **Type alias** - Both `WidgetName` and `WidgetNameState` work
18. **Type alias interchangeability** - Full compatibility between both forms

### Multiple Widgets (Test 20)

20. **Multiple widgets in same scope** - Multiple widget definitions in one file

## Test Statistics

- **Total Tests**: 34
- **Widgets Defined**: 20
- **All Tests Passing**: ✓

## Key Features Tested

✅ State management (with and without defaults)
✅ Event system (simple and with data)
✅ Parent-child event handling (`onEvent` template)
✅ Slot/children support (template generation)
✅ Type inference
✅ Type aliases
✅ Nested widget composition
✅ Parameterless render sections
✅ Custom render parameters
✅ Stateless widgets
✅ Complex state types (objects, sequences, options)
✅ Multiple event handlers (own and child)
✅ Widget isolation (multiple widgets in same file)

## Example Widget Tests

### Simple Widget
```nim
widget Counter:
  state:
    count: int = 0
  render(ui: var UI):
    discard

var state = Counter(count: 5)
```

### Widget with Events
```nim
widget EventCounter:
  state:
    count: int = 0
  event:
    Increment
    SetValue(value: int)
  handle(evt):
    case evt.kind
    of Increment: state.count += 1
    of SetValue: state.count = evt.value
  render(ui: var UI):
    discard
```

### Parent-Child Communication
```nim
widget ChildButton:
  event:
    Click
  render(ui: var UI):
    discard

widget Container:
  state:
    button = ChildButton()
    clickCount: int = 0
  handle:
    onEvent state.button, Click:
      state.clickCount += 1
  render(ui: var UI):
    discard
```

### Widget with Slot
```nim
widget Container:
  state:
    padding: int = 0
  render(ui: var UI, slot: untyped):
    discard
```

## Notes

- All state fields should have default values for proper initialization
- Widgets can be stateless (no state section)
- Type aliases allow using `WidgetName` or `WidgetNameState` interchangeably
- The `slot: untyped` parameter triggers template generation instead of proc
- Parent widgets can handle child events using `onEvent` in `handle:` section
- Widgets can have both own event handlers and child event handlers
