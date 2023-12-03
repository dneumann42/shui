import options, fusion/matching, sugar, widgets, theme, print
{.experimental: "caseStmtMacros".}

type
  UI*[T, A] = ref object
    root: Widget
    theme: Theme
    when T isnot void:
      state: T
    when A isnot void:
      actions: seq[A]

  StatelessUI[A] = UI[void, A]
  StaticUI = StatelessUI[void]

  LayoutError = object of ValueError
  WidgetError = object of ValueError
  NotElem = object of ValueError

proc initUI*[T, A](theme: Theme, blk: proc(): T): UI[T, A] =
  result = UI[T, A](state: blk(), theme: theme)

proc initUI*[A](theme: Theme, blk: proc(): void): StatelessUI[A] =
  result = StatelessUI[A](theme: theme)

proc initStaticUI*(theme: Theme, blk: proc(): void): StaticUI =
  result = StaticUI(theme: theme)

proc size*(theme: Theme, widget: Widget): (float, float)
proc render(theme: Theme, w: Widget, index: int): void

proc maxSize*(theme: Theme, layout: Layout): (float, float) =
  for child in layout.children:
    var (w, h) = theme.size(child)
    result = (max(result[0], w), max(result[1], h))

proc measureLayout*(theme: Theme, layout: Layout): (float, float) =
  var (mx, my) = theme.maxSize(layout)
  var cursor = 0.0
  if layout of Horizontal:
    for y in layout.children:
      cursor += theme.size(y)[1] ## handle margin + padding
    (cursor, my)
  elif layout of Vertical:
    for x in layout.children:
      cursor += theme.size(x)[0] ## handle margin + padding
    (mx, cursor)
  else:
    raise newException(LayoutError, "missing measure for layout")

proc size*(theme: Theme, widget: Widget): (float, float) =
  if widget of Layout:
    theme.measureLayout(widget.Layout)
  elif widget of Element:
    theme.measureElement(widget.Element)
  else:
    raise newException(WidgetError, "expected element")

proc position(theme: Theme, widget: Widget, index = 0): (float, float) =
  case widget.parent
  of None():
    result = (0.0, 0.0)
  of Some(@p):
    var layout: Layout = p.Layout
    let
      size = theme.size(widget)
      parentPos = theme.position(p)
    result = parentPos + layout.cursor
    if layout of Vertical:
      layout.cursor = (0.0, size[1] + theme.values.verticalSpacing)
    elif layout of Horizontal:
      layout.cursor = (size[0] + theme.values.horizontalSpacing, 0.0)
    else:
      raise newException(LayoutError, "expected layout")

proc update*[T, A](ui: UI[T, A], blk: proc(action: A): Option[T]) =
  for action in ui.actions:
    if Some(@newT) ?= blk(action):
      ui.state = newT

proc render(theme: Theme, layout: Layout, index: int) =
  for i, child in layout.children:
    theme.render(child, index = i)
  layout.cursor = (0.0, 0.0)

proc renderElem(theme: Theme, elem: Widget, index: int) =
  var (w, h) = theme.size(elem)
  var (x, y) = theme.position(elem, index = index)
  if elem of Button:
    theme.drawButton(x, y, w, h, elem.Button)
  elif elem of Label:
    theme.drawLabel(x, y, w, h, elem.Label)
  else:
    raise newException(NotElem, "Not an element")

proc render(theme: Theme, w: Widget, index: int) =
  if w of Layout:
    theme.render(w.Layout, index)
  else:
    theme.renderElem(w, index)

proc render*[T, A](ui: UI[T, A], preRender: proc(): void = proc() = discard) =
  preRender()
  ui.theme.render(ui.root, 0)

proc layout*[T, A](ui: UI[T, A], blk: proc(emit: proc(
    action: A): void): Widget) =
  ui.root = blk((action: A) => ui.actions.add(action))

proc layout*(staticUI: StaticUI, blk: proc(): Widget) =
  staticUI.root = blk()

proc label*(text = ""): Label =
  result = Label(text: text)

proc button*(text = ""): Button =
  result = Button(text: text)

proc vertical*(children: varargs[Widget]): Layout =
  result = Vertical(children: @[])
  result.addChildren(children)

proc horizontal*(children: varargs[Widget]): Layout =
  result = Horizontal(children: @[])
  result.addChildren(children)
