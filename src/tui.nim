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
    updateButton: proc(button: var Button) =
      discard,
    drawButton: proc(button: Button) =
      let (x, y, w, h) = button.toTuple
      tuiDrawButton(x.int, y.int, w.int, h.int, button.text),
    drawLabel: proc(label: Label) =
      let (x, y, w, _) = label.toTuple
      tuiDrawLabel(x.int, y.int, w.int, label.text))

when isMainModule:
  var ui = initUI[State, TodoAction](tuiTheme(), () => State(todos: @[]))

  ui.update (action: TodoAction) =>
    none(State)

  ui.layout proc(emit: (TodoAction) -> void): Widget =
    vertical(
      label("Are you sure?"),
      button("HERER?") do(): discard,
      horizontal(
        button("Cancel") do(): discard,
        button("Confirm") do(): discard),
      button("aaa") do(): discard,
      button("bbb") do(): discard)