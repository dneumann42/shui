# import std/hashes

import chroma, macros

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

  Style* = object
    bg*, fg*, border*: Color
    bordered* = false
    padding* = 8
    gap* = 8

  Widget* = object
    size*: Sizing
    state*: WidgetState
    text*: string
    style*: Style
    children: seq[WidgetIndex]

  WidgetIndex* = distinct int

  UI* = object
    widgets: seq[Widget]

proc `[]=`*(ui: var UI, index: WidgetIndex, widget: Widget) =
  ui.widgets[int(index)] = widget

proc `[]`*(ui: var UI, index: WidgetIndex): var Widget =
  result = ui.widgets[int(index)]

proc get*(ui: var UI, index: WidgetIndex): var Widget {.inline.} =
  ui[index]

proc createWidget*(ui: var UI): WidgetIndex =
  ui.widgets.add(Widget())
  result = WidgetIndex(ui.widgets.len - 1)

proc beginWidget*(ui: var UI, widget: Widget): WidgetIndex =
  result = ui.createWidget()
  ui[result] = widget

proc add*(ui: var UI, parent, child: WidgetIndex) =
  ui.get(parent).children.add(child)

proc endWidget*(ui: var UI, widget: WidgetIndex) =
  # Calculate the size
  discard

proc updateWidget(blk: NimNode): auto =
  result = blk
  for i in 0 ..< blk.len:
    if blk[i].kind == nnkAsgn:
      blk[i] = nnkAsgn.newTree(
        nnkDotExpr.newTree(
          nnkCall.newTree(
            nnkDotExpr.newTree(newIdentNode("ui"), newIdentNode("get")),
            newIdentNode("widgetIndex"),
          ),
          blk[i][0],
        ),
        blk[i][1],
      )

macro widget*(blk: untyped) =
  let newBlk = updateWidget(blk)
  quote:
    block:
      when compiles(widgetIndex):
        let parent {.inject.} = widgetIndex
      else:
        let parent {.inject.} = WidgetIndex(-1)
      let widgetIndex {.inject.} = ui.beginWidget(Widget())
      `newBlk`
      when compiles(widgetIndex):
        if parent.int != -1:
          ui.add(parent, widgetIndex)
