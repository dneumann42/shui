import options, fusion/matching, sugar, terminal
import shui/[widgets, shui, theme]
{.experimental: "caseStmtMacros".}

type
  TuiError = object of ValueError

  State = object
    todos: seq[string]

  TodoActionKind = enum
    add
    remove
    complete

  TodoAction = object
    case kind: TodoActionKind
      of add: title: string
      of remove, complete:
        id: string

method measure(b: Text): (float, float) =
  result = (b.text.len.float, 1.0)

proc tuiDrawButton(x, y, w, h: int, text: string) =
  setCursorPos(x, y)
  stdout.write(text)

proc tuiDrawLabel(x, y, w: int, text: string) =
  setCursorPos(x, y)
  stdout.write(text)

proc tuiTheme(): Theme =
  result = Theme(
    measureElement: proc(e: Element): auto = e.measure(),
    values: ThemeValues(
      verticalSpacing: 0.0
    ),
    windowSize: proc(): auto = (terminalWidth().float, terminalHeight().float),
    drawButton: proc(x, y, w, h: float, button: Button) = tuiDrawButton(x.int,
        y.int, w.int, h.int, button.text),
    drawLabel: proc(x, y, w, _: float, label: Label) = tuiDrawLabel(x.int,
        y.int, w.int, label.text))

var ui = initUI[State, TodoAction](tuiTheme(), () => State(todos: @[]))

ui.update (action: TodoAction) =>
  none(State)

ui.layout proc(emit: (TodoAction) -> void): Widget =
  doVertical:
    label("Are you sure?")
    doHorizontal:
      button("Cancel") do(): 
        discard
      button("Confirm") do(): 
        discard
    doHorizontal:
      button("aaa") do(): 
        discard
      button("bbb") do(): 
        discard

when isMainModule:
  ui.render(
    preRender = proc() =
    eraseScreen()
    setCursorPos(1, 1))
