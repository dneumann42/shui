# import std/hashes

import chroma, macros
export chroma, macros

type
  SizingKind* = enum
    Fixed
    Fit
    Grow

  Sizing* = object
    min*, max*: int
    kind*: SizingKind

  WidgetState* = enum
    Dead
    Visible
    Disabled

  Direction* = enum
    Row
    Col

  Style* = object
    bg*, fg*, border*: Color
    bordered* = false
    padding* = 8
    gap* = 8

  Widget* = object
    size*: tuple[w, h: Sizing]
    state*: WidgetState
    text*: string
    style*: Style
    dir*: Direction
    children: seq[WidgetIndex]
    box*: tuple[x, y, w, h: int]

  WidgetIndex* = distinct int

  UI* = object
    root = WidgetIndex(-1)
    widgets: seq[Widget]
    drawWidget: proc(widget: Widget): void
    measureText: proc(text: string): tuple[w, h: int]

proc `onDraw=`*(ui: var UI, fn: proc(widget: Widget): void) =
  ui.drawWidget = fn

proc `onMeasureText=`*(ui: var UI, fn: proc(text: string): tuple[w, h: int]) =
  ui.measureText = fn

proc hasDraw*(ui: var UI): bool =
  ui.drawWidget.isNil == false

proc hasMeasureText*(ui: var UI): bool =
  ui.measureText.isNil == false

proc `[]=`*(ui: var UI, index: WidgetIndex, widget: Widget) =
  ui.widgets[int(index)] = widget

proc `[]`*(ui: var UI, index: WidgetIndex): var Widget =
  result = ui.widgets[int(index)]

proc get*(ui: var UI, index: WidgetIndex): var Widget {.inline.} =
  ui[index]

iterator items*(ui: var UI, widget: WidgetIndex): WidgetIndex =
  for child in ui.get(widget).children:
    yield child

iterator items*(ui: var UI): WidgetIndex =
  for child in ui.items(ui.root):
    yield child

proc createWidget*(ui: var UI): WidgetIndex =
  ui.widgets.add(Widget())
  result = WidgetIndex(ui.widgets.len - 1)

proc beginWidget*(ui: var UI, widget: Widget, parent = WidgetIndex(-1)): WidgetIndex =
  result = ui.createWidget()
  ui[result] = widget
  if parent.int == -1:
    ui.root = result

proc add*(ui: var UI, parent, child: WidgetIndex) =
  ui.get(parent).children.add(child)

proc updateDimensions*(ui: var UI, widgetIndex: WidgetIndex) =
  let w = ui.get(widgetIndex)

  if w.text.len > 0:
    let (tw, th) = ui.measureText(w.text)
    ui.get(widgetIndex).box.w = tw
    ui.get(widgetIndex).box.h = th
    return

  var
    totalWidth = 0
    totalHeight = 0
    maxWidth = 0
    maxHeight = 0

  for child in ui.items(widgetIndex):
    let (_, _, w, h) = ui.get(child).box
    totalWidth += w
    totalHeight += h
    maxWidth = max(maxWidth, w)
    maxHeight = max(maxHeight, h)

  if w.dir == Row:
    if w.size.w.kind == Fit:
      ui.get(widgetIndex).box.w = max(w.size.w.min, totalWidth)
    if w.size.h.kind == Fit:
      ui.get(widgetIndex).box.h = max(w.size.h.min, maxHeight)
  else:
    if w.size.w.kind == Fit:
      ui.get(widgetIndex).box.w = max(w.size.w.min, maxWidth)
    if w.size.h.kind == Fit:
      ui.get(widgetIndex).box.h = max(w.size.h.min, totalHeight)

proc endWidget*(ui: var UI, parent, widgetIndex: WidgetIndex) =
  if parent.int != -1:
    ui.add(parent, widgetIndex)
  ui.updateDimensions(widgetIndex)

proc updateWidget(blk: NimNode): auto =
  result = blk
  for i in 0 ..< blk.len:
    if blk[i].kind == nnkAsgn:
      let dot = nnkDotExpr.newTree(newIdentNode("ui"), newIdentNode("get"))
      let call = nnkCall.newTree(dot, newIdentNode("widgetIndex"))
      blk[i] = nnkAsgn.newTree(nnkDotExpr.newTree(call, blk[i][0]), blk[i][1])

macro widget*(blk: untyped) =
  let newBlk = updateWidget(blk)
  quote:
    block:
      when compiles(widgetIndex):
        let parent {.inject.} = widgetIndex
      else:
        let parent {.inject.} = WidgetIndex(-1)
      let widgetIndex {.inject.} = ui.beginWidget(Widget(), parent)
      `newBlk`
      ui.endWidget(parent, widgetIndex)

proc updateLayout*(ui: var UI) =
  discard

proc draw*(ui: var UI, widget: Widget) =
  if ui.hasDraw():
    ui.drawWidget(widget)

proc draw*(ui: var UI, widgetIndex: WidgetIndex) =
  ui.draw(ui.get(widgetIndex))
  for widget in ui.items(widgetIndex):
    ui.draw(widget)

proc draw*(ui: var UI) =
  ui.draw(ui.get(ui.root))
  for widget in ui:
    ui.draw(widget)
