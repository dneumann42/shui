import options, fusion/matching, sugar, widgets, theme, print, macros, sets, tables
import std/macrocache, strutils
{.experimental: "caseStmtMacros".}

type
  UI*[T, A] = ref object
    root: Widget
    theme: Theme
    shouldRerender = true
    openDialogs: HashSet[string]
    dialogSizes: Table[string, (float, float)]
    buttons: Table[string, Button]
    when T isnot void:
      state: T
    when A isnot void:
      actions: seq[A]

  StatelessUI*[A] = UI[void, A]
  StaticUI* = StatelessUI[void]

  LayoutError = object of ValueError
  WidgetError = object of ValueError
  NotElem = object of ValueError

const buttonChecks = CacheTable"buttonChecks"

var layoutId {.compileTime.} = ""

method render(w: Widget, theme: Theme): void {.base.} =
  discard

method measureLayout(l: Layout, theme: Theme): (float, float) {.base.} =
  raise newException(CatchableError, "")

proc initUI*[T, A](theme: Theme, blk: proc(): T): UI[T, A] =
  result = UI[T, A](
    state: blk(),
    theme: theme,
    openDialogs: initHashSet[string](),
    dialogSizes: initTable[string, (float, float)]())

proc initUI*[A](theme: Theme, blk: proc(): void): StatelessUI[A] =
  result = StatelessUI[A](theme: theme)
  blk()

proc initUI*[A](theme: Theme): StatelessUI[A] =
  result = StatelessUI[A](theme: theme)

proc initStaticUI*(theme: Theme, blk: proc(): void): StaticUI =
  result = StaticUI(theme: theme)

proc emit*[T, A](ui: UI[T, A], action: sink A) =
  ui.actions.add(action)

proc mgetState*[T, A](ui: UI[T, A]): lent T =
  ui.state

proc measureSize*(theme: Theme, widget: Widget): (float, float)

proc maxSize*(theme: Theme, layout: Layout): (float, float) =
  for child in layout.nodes:
    var (w, h) = theme.measureSize(child)
    result = (max(result[0], w), max(result[1], h))

method measureLayout(layout: Horizontal, theme: Theme): (float, float) =
  var cursor = 0.0
  let (_, my) = theme.maxSize(layout)
  for y in layout.nodes:
    cursor += theme.measureSize(y)[1] ## handle margin + padding
  (cursor, my)

method measureLayout(layout: Vertical, theme: Theme): (float, float) =
  var cursor = 0.0
  let (mx, _) = theme.maxSize(layout)
  for x in layout.nodes:
    cursor += theme.measureSize(x)[0] ## handle margin + padding
  (mx, cursor)

method measureLayout(layout: Panel, theme: Theme): (float, float) =
  var cursor = 0.0
  let (mx, _) = theme.maxSize(layout)
  for x in layout.nodes:
    cursor += theme.measureSize(x)[0] ## handle margin + padding
  layout.fixedSize.get((mx, cursor))

proc measureSize*(theme: Theme, widget: Widget): (float, float) =
  if widget of Layout:
    measureLayout(widget.Layout, theme)
  elif widget of Element:
    theme.measureElement(widget.Element)
  elif widget of Dialog:
    theme.measureSize(widget.Dialog.layout)
  else:
    raise WidgetError.newException("expected element")

proc parentBounds(theme: Theme, widget: Widget): auto =
  if Some(@base) ?= widget.base:
    (base, base.toTuple)
  else:
    let (w, h) = theme.windowSize()
    (nil, (0.0, 0.0, w, h))

proc updateWidget*(theme: Theme, widget: Widget, cursor: var (float, float),
    inDialog = false)

proc updateLayout*(theme: Theme, layout: Layout, inDialog = false)

proc updateDialogAux*(theme: Theme, dialog: Dialog) =
  # if not dialog.layout.isNil:
  #   dialog.size = theme.measureSize(dialog)
  #   dialog.pos = (0.0, 0.0)
  #   theme.updateLayout(dialog.layout, inDialog = true)
  discard

proc updateLayout*(theme: Theme, layout: Layout, inDialog = false) =
  var cursor = (0.0, 0.0)
  for node in layout.nodes.mitems:
    theme.updateWidget(node, cursor, inDialog = inDialog)

proc updateWidget*(theme: Theme, widget: Widget, cursor: var (float, float),
    inDialog = false) =
  if widget.isNil:
    return

  if widget of Dialog and not widget.isNil:
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
    widget.Button.clicked = widget.lastState == active and widget.state != active

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

proc updateWidget*(theme: Theme, widget: Widget) =
  var cursor = (0.0, 0.0)
  theme.updateWidget(widget, cursor)

template withState*[T, A](ui: UI[T, A], blk: untyped) =
  when T isnot void:
    block:
      var state {.inject.} = ui.state
      blk
      ui.state = state

macro update*[T, A](ui: UI[T, A], id: untyped, blk: untyped) =
  quote do:
    `ui`.theme.updateWidget(`ui`.root)
    for act in `ui`.actions:
      let `id` {.inject.} = act
      let maybeState = `blk`
      if maybeState.isSome:
        `ui`.state = maybeState.get()
    if `ui`.actions.len > 0:
      `ui`.shouldRerender = true
    `ui`.actions.setLen(0)

macro handle*[T, A](ui: UI[T, A], id: untyped, blk: untyped) =
  quote do:
    `ui`.theme.updateWidget(`ui`.root)
    for act in `ui`.actions:
      let `id` {.inject.} = act
      `blk`
    if `ui`.actions.len > 0:
      `ui`.shouldRerender = true
    `ui`.actions.setLen(0)

proc isOpen*[T, A](ui: UI[T, A], dialogId: string): bool =
  result = ui.openDialogs.contains(dialogId)

proc open*[T, A](ui: UI[T, A], dialogId: string) =
  ui.openDialogs.incl(dialogId)
  ui.shouldRerender = true

proc close*[T, A](ui: UI[T, A], dialogId: string) =
  ui.openDialogs.excl(dialogId)
  ui.shouldRerender = true

proc toggleOpen*[T, A](ui: UI[T, A], dialogId: string) =
  if ui.isOpen(dialogId):
    ui.close(dialogId)
  else:
    ui.open(dialogId)

proc dialogSize*[T, A](ui: UI[T, A], dialogId: string): (float, float) =
  if not ui.dialogSizes.hasKey(dialogId):
    return (0.0, 0.0)
  ui.dialogSizes[dialogId]

method render(layout: Layout, theme: Theme) =
  for i, node in layout.nodes:
    render(node, theme)

method render(dialog: Dialog, theme: Theme) =
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

proc registerButton*[T, A](u: UI[T, A], newBtn: Button): Button =
  if u.buttons.hasKey(newBtn.id):
    var old = u.buttons[newBtn.id]
    if old.text != newBtn.text:
      u.buttons[newBtn.id] = newBtn
  u.buttons.mgetOrPut(newBtn.id, newBtn)

macro buttonAux*[T, A](u: UI[T, A], id, label: string, blk: untyped): auto =
  buttonChecks[layoutId & "|" & $id] = quote do: `blk`
  quote do:
    block: registerButton(`u`, initButton(`label`, `id`))

macro buttonAux*[T, A](u: UI[T, A], label: string, blk: untyped): auto =
  let id = $label
  buttonChecks[layoutId & "|" & id] = quote do: `blk`
  quote do:
    block: registerButton(`u`, initButton(`label`, `id`))

template button*[T, A](u: UI[T, A], label: string, blk: untyped): auto =
  buttonAux(u, label, blk)
template button*[T, A](u: UI[T, A], id, label: string, blk: untyped): auto =
  buttonAux(u, id, label, blk)

macro panel*(fixedSize: (float, float), blk: untyped): auto =
  quote do:
    Panel(nodes: @[`blk`.Widget], fixedSize: `fixedSize`.some)

macro layoutButtons*[T, A](ui: UI[T, A]): untyped =
  var items = nnkStmtList.newTree()
  for rawId, check in buttonChecks.pairs:
    if rawId.startsWith(layoutId & "|"):
      let buttonId = (rawId.split {'|'})[1]
      items.add(
        quote do:
        if `ui`.buttons.hasKey(`buttonId`) and `ui`.buttons[`buttonId`].clicked:
          (`check`)
      )
  quote do:
    `items`

macro layoutAux*[T, A](ui: UI[T, A], blk: untyped): untyped =
  quote do:
    if `ui`.shouldRerender:
      `ui`.root = block:
        `blk`
      `ui`.shouldRerender = false
    `ui`.render()

macro layout*(ui: untyped, id: string, blk: untyped) =
  layoutId = $id
  quote do:
    layoutAux(`ui`, `blk`)
    layoutButtons(`ui`)

macro dialog*[T, A](ui: UI[T, A], id: string, blk: untyped): auto =
  quote do:
    if `ui`.isOpen(`id`):
      let node = `blk`
      Dialog(id: `id`, layout: node)
    else:
      nil

macro customDialog*[T, A](ui: UI[T, A], id: string, blk: untyped): auto =
  quote do:
    if `ui`.isOpen(`id`):
      let node = `blk`
      Dialog(id: `id`, layout: node, noBackdrop: true)
    else:
      nil
