import options, fusion/matching, sugar, widgets, theme, print, macros
{.experimental: "caseStmtMacros".}

type
  UI*[T, A] = ref object
    root: Widget
    theme: Theme
    shouldRerender = true
    when T isnot void:
      state: T
    when A isnot void:
      actions: seq[A]

  StatelessUI*[A] = UI[void, A]
  StaticUI* = StatelessUI[void]

  LayoutError = object of ValueError
  WidgetError = object of ValueError
  NotElem = object of ValueError

method render(w: Widget, theme: Theme): void {.base.} = 
  discard

method measureLayout(l: Layout, cursor: var float, theme: Theme): (float, float) {.base.} =
  discard

proc initUI*[T, A](theme: Theme, blk: proc(): T): UI[T, A] =
  result = UI[T, A](state: blk(), theme: theme)

proc initUI*[A](theme: Theme, blk: proc(): void): StatelessUI[A] =
  result = StatelessUI[A](theme: theme)
  blk()

proc initUI*[A](theme: Theme): StatelessUI[A] =
  result = StatelessUI[A](theme: theme)

proc initStaticUI*(theme: Theme, blk: proc(): void): StaticUI =
  result = StaticUI(theme: theme)

proc emit*[T, A](ui: UI[T, A], action: A) =
  ui.actions.add(action)

proc measureSize*(theme: Theme, widget: Widget): (float, float)

proc maxSize*(theme: Theme, layout: Layout): (float, float) =
  for child in layout.nodes:
    var (w, h) = theme.measureSize(child)
    result = (max(result[0], w), max(result[1], h))

method measureLayout(layout: Horizontal, cursor: var float, theme: Theme): (float, float) =
  let (_, my) = theme.maxSize(layout)
  for y in layout.nodes:
    cursor += theme.measureSize(y)[1] ## handle margin + padding
  (cursor, my)

method measureLayout(layout: Vertical, cursor: var float, theme: Theme): (float, float) =
  let (mx, _) = theme.maxSize(layout)
  for x in layout.nodes:
    cursor += theme.measureSize(x)[0] ## handle margin + padding
  (mx, cursor)

method measureLayout(layout: Panel, cursor: var float, theme: Theme): (float, float) =
  let (mx, _) = theme.maxSize(layout)
  for x in layout.nodes:
    cursor += theme.measureSize(x)[0] ## handle margin + padding
  layout.fixedSize.get((mx, cursor))

proc measureSize*(theme: Theme, widget: Widget): (float, float) =
  var cursor = 0.0
  if widget of Layout:
    measureLayout(widget.Layout, cursor, theme)
  elif widget of Element:
    theme.measureElement(widget.Element)
  elif widget of Dialog:
    measureLayout(widget.Dialog.layout, cursor, theme)
  else:
    raise WidgetError.newException("expected element")

proc parentBounds(theme: Theme, widget: var Widget): auto =
  if Some(@base) ?= widget.base:
    (base, base.toTuple)
  else:
    let (w, h) = theme.windowSize()
    (nil, (0.0, 0.0, w, h))

proc updateWidget*(theme: Theme, widget: var Widget, cursor: var (float, float),
    inDialog = false)
proc updateLayout*(theme: Theme, layout: var Layout, inDialog = false)

proc updateDialogAux*(theme: Theme, dialog: var Dialog) =
  dialog.size = theme.measureSize(dialog)
  dialog.pos = (0.0, 0.0)
  theme.updateDialog(dialog)
  theme.updateLayout(dialog.layout, inDialog = true)

proc updateLayout*(theme: Theme, layout: var Layout, inDialog = false) =
  var cursor = (0.0, 0.0)
  for node in layout.nodes.mitems:
    theme.updateWidget(node, cursor, inDialog = inDialog)

proc updateWidget*(theme: Theme, widget: var Widget, cursor: var (float, float),
    inDialog = false) =
  if widget.isNil:
    return

  if widget of Dialog:
    theme.updateDialogAux(widget.Dialog)
    return

  let size = theme.measureSize(widget)
  let (base, (px, py, _, _)) = theme.parentBounds(widget)

  widget.pos = (px, py) + cursor
  widget.size = size

  if widget of Layout:
    theme.updateLayout(widget.Layout, inDialog = inDialog)
  elif widget of Button:
    widget.lastState = widget.state

    # if (not inDialog and not dialogOpen) or (inDialog and dialogOpen):
    theme.updateButton(widget.Button)

    if widget.lastState == active and widget.state != active:
      widget.Button.callback()

  if not base.isNil:
    if base of Horizontal:
      cursor[0] += size[0] + theme.values.horizontalSpacing
    elif base of Vertical:
      cursor[1] += size[1] + theme.values.verticalSpacing
    elif base of Panel:
      # cursor[]
      discard
    else:
      raise LayoutError.newException("Unexpected layout of parent")

proc updateWidget*(theme: Theme, widget: var Widget) =
  var cursor = (0.0, 0.0)
  theme.updateWidget(widget, cursor)

proc update*[T, A](ui: UI[T, A], blk: proc(action: A, state: T): Option[T]) =
  ui.theme.updateWidget(ui.root)
  for action in ui.actions:
    if Some(@newT) ?= blk(action, ui.state):
      ui.state = newT
  ui.actions.setLen(0)

template handle*[A](ui: StatelessUI[A], blk: untyped) =
  ui.theme.updateWidget(ui.root)
  for action in ui.actions:
    blk(action)
  ui.actions.setLen(0)

template handle*[A, O](ui: StatelessUI[A], state: var O, blk: untyped) =
  ui.theme.updateWidget(ui.root)
  for action in ui.actions:
    blk(action, state)
  ui.actions.setLen(0)

proc isOpen*[T, A](ui: UI[T, A], dialogId: string): bool =
  if Some(@dialog) ?= ui.root.getDialogById(dialogId):
    return dialog.open

proc open*[T, A](ui: UI[T, A], dialogId: string) =
  if Some(@dialog) ?= ui.root.getDialogById(dialogId):
    dialog.open = true

proc close*[T, A](ui: UI[T, A], dialogId: string) =
  if Some(@dialog) ?= ui.root.getDialogById(dialogId):
    dialog.open = false

proc toggleOpen*[T, A](ui: UI[T, A], dialogId: string) =
  if ui.isOpen(dialogId):
    ui.close(dialogId)
  else:
    ui.open(dialogId)

method render(layout: Layout, theme: Theme) =
  for i, node in layout.nodes:
    render(node, theme)

method render(dialog: Dialog, theme: Theme) =
  if not dialog.open:
    return
  theme.drawDialog(dialog)
  render(dialog.layout, theme)

method render(elem: Element, theme: Theme) =
  if elem of Button:
    theme.drawButton(elem.Button)
  elif elem of Label:
    theme.drawLabel(elem.Label)
  else:
    raise newException(NotElem, "Not an element")

method render(panel: Panel, theme: Theme) =
  for i, node in panel.nodes:
    render(node, theme)

proc render[T, A](ui: UI[T, A]) =
  if not ui.root.isNil:
    render(ui.root, ui.theme)

proc layout*[T, A](ui: UI[T, A], blk: proc(emit: proc(
    action: A): void): Widget) =
  if ui.shouldRerender:
    ui.root = blk((action: A) => ui.actions.add(action))
    ui.shouldRerender = false
  ui.render()

proc layout*(staticUI: StaticUI, blk: proc(): Widget) =
  if staticUI.shouldRerender:
    staticUI.root = blk()
    staticUI.shouldRerender = false
  staticUI.render()

macro layout*[T, A](ui: UI[T, A], blk: untyped): auto =
  quote do:
    if `ui`.shouldRerender:
      `ui`.root = block:
        `blk`
      `ui`.shouldRerender = false
    `ui`.render()