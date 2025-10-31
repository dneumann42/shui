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
    padding* = 0
    gap* = 8
    borderRadius* = 0.0

  Align* = enum
    Start
    Center
    End

  Widget* = object
    size*: tuple[w, h: Sizing]
    state*: WidgetState
    text*: string
    style*: Style
    dir*: Direction
    align*: Align
    crossAlign*: Align
    textAlign*: Align
    border*: int
    box*: tuple[x, y, w, h: int]
    children: seq[WidgetIndex]

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

proc getDimensions*(
    ui: var UI, widgetIndex: WidgetIndex
): tuple[w, h, maxW, maxH: int] =
  let container = ui.get(widgetIndex)
  let gap = container.style.gap
  let dir = container.dir
  var childCount = 0
  for child in ui.items(widgetIndex):
    let childWidget = ui.get(child)
    let (_, _, w, h) = childWidget.box
    let effW = max(w, childWidget.size.w.min)
    let effH = max(h, childWidget.size.h.min)
    result.w += effW
    result.h += effH
    result.maxW = max(result.maxW, effW)
    result.maxH = max(result.maxH, effH)
    inc childCount

  if childCount > 1 and gap != 0:
    let totalGap = gap * (childCount - 1)
    if dir == Row:
      result.w += totalGap
    else:
      result.h += totalGap

proc updateDimensions*(ui: var UI, widgetIndex: WidgetIndex) =
  let w = ui.get(widgetIndex)
  let padding = w.style.padding * 2

  if w.text.len > 0:
    let (tw, th) = ui.measureText(w.text)
    ui.get(widgetIndex).box.w = tw + padding
    ui.get(widgetIndex).box.h = th + padding
    return

  let (totalWidth, totalHeight, maxWidth, maxHeight) = ui.getDimensions(widgetIndex)

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

  ui.get(widgetIndex).box.w += padding
  ui.get(widgetIndex).box.h += padding

  let sizing = ui.get(widgetIndex).size
  if sizing.w.min > 0:
    ui.get(widgetIndex).box.w = max(ui.get(widgetIndex).box.w, sizing.w.min)
  if sizing.w.max > 0:
    ui.get(widgetIndex).box.w = min(ui.get(widgetIndex).box.w, sizing.w.max)
  if sizing.h.min > 0:
    ui.get(widgetIndex).box.h = max(ui.get(widgetIndex).box.h, sizing.h.min)
  if sizing.h.max > 0:
    ui.get(widgetIndex).box.h = min(ui.get(widgetIndex).box.h, sizing.h.max)

proc clampDimension(value: int, sizing: Sizing): int =
  result = value
  if sizing.min > 0:
    result = max(result, sizing.min)
  if sizing.max > 0:
    result = min(result, sizing.max)

proc updateGrowContainer*(ui: var UI, widgetIndex: WidgetIndex) =
  let w = ui.get(widgetIndex)
  let gap = w.style.gap
  let padding = w.style.padding * 2
  let childCount = w.children.len
  let gapTotal = gap * max(childCount - 1, 0)

  if w.dir == Row:
    var
      fixedWidth = 0
      growChildren: seq[tuple[index: WidgetIndex, base: int]]

    for child in ui.items(widgetIndex):
      let childWidget = ui.get(child)
      if childWidget.size.w.kind == Grow:
        growChildren.add((index: child, base: childWidget.box.w))
      else:
        fixedWidth += childWidget.box.w

    let growCount = growChildren.len
    if growCount > 0:
      let available = max(w.box.w - padding - fixedWidth - gapTotal, 0)
      let share = available div growCount
      var remainder = available mod growCount
      for childInfo in growChildren:
        let child = childInfo.index
        let sizing = ui.get(child).size.w
        var targetWidth = max(share, childInfo.base)
        if remainder > 0:
          inc targetWidth
          dec remainder
        if sizing.min > 0:
          targetWidth = max(targetWidth, sizing.min)
        if sizing.max > 0:
          targetWidth = min(targetWidth, sizing.max)
        ui.get(child).box.w = targetWidth

  if w.dir == Col:
    var
      fixedHeight = 0
      growChildren: seq[tuple[index: WidgetIndex, base: int]]

    for child in ui.items(widgetIndex):
      let childWidget = ui.get(child)
      if childWidget.size.h.kind == Grow:
        growChildren.add((index: child, base: childWidget.box.h))
      else:
        fixedHeight += childWidget.box.h

    let growCount = growChildren.len
    if growCount > 0:
      let available = max(w.box.h - padding - fixedHeight - gapTotal, 0)
      let share = available div growCount
      var remainder = available mod growCount
      for childInfo in growChildren:
        let child = childInfo.index
        let sizing = ui.get(child).size.h
        var targetHeight = max(share, childInfo.base)
        if remainder > 0:
          inc targetHeight
          dec remainder
        if sizing.min > 0:
          targetHeight = max(targetHeight, sizing.min)
        if sizing.max > 0:
          targetHeight = min(targetHeight, sizing.max)
        ui.get(child).box.h = targetHeight

  for child in ui.items(widgetIndex):
    ui.updateGrowContainer(child)

proc updateLayout*(ui: var UI, widgetIndex: WidgetIndex) =
  # This traverses top to bottom of the tree
  # each node can assume it has been positioned already
  let w = ui.get(widgetIndex)

  let (width, height, _, _) = ui.getDimensions(widgetIndex)
  let paddingVal = w.style.padding
  let doublePad = paddingVal * 2
  let contentStartX = w.box.x + paddingVal
  let contentStartY = w.box.y + paddingVal
  let contentWidth = max(w.box.w - doublePad, 0)
  let contentHeight = max(w.box.h - doublePad, 0)

  var mainOffset = 0
  if w.align == Center:
    if w.dir == Row:
      mainOffset = max((contentWidth - width) div 2, 0)
    else:
      mainOffset = max((contentHeight - height) div 2, 0)
  elif w.align == End:
    if w.dir == Row:
      mainOffset = max(contentWidth - width, 0)
    else:
      mainOffset = max(contentHeight - height, 0)

  var
    cursorX = contentStartX + (if w.dir == Row: mainOffset else: 0)
    cursorY = contentStartY + (if w.dir == Col: mainOffset else: 0)

  let gap = w.style.gap
  let childCount = w.children.len
  var childIndexCounter = 0

  for child in ui.items(widgetIndex):
    let childIndex = child
    let childSize = ui.get(childIndex).size
    if w.dir == Row:
      ui.get(childIndex).box.x = cursorX
      ui.get(childIndex).box.y = contentStartY
    else:
      ui.get(childIndex).box.x = contentStartX
      ui.get(childIndex).box.y = cursorY

    if w.dir == Col and childSize.w.kind == Grow:
      ui.get(childIndex).box.w = clampDimension(contentWidth, childSize.w)
    if w.dir == Row and childSize.h.kind == Grow:
      ui.get(childIndex).box.h = clampDimension(contentHeight, childSize.h)

    ui.updateLayout(childIndex)

    if w.dir == Row:
      cursorX += ui.get(childIndex).box.w
      if childIndexCounter < childCount - 1:
        cursorX += gap
    else:
      cursorY += ui.get(childIndex).box.h
      if childIndexCounter < childCount - 1:
        cursorY += gap

    inc childIndexCounter

    case w.crossAlign
    of Center:
      if w.dir == Row:
        ui.get(childIndex).box.y =
          contentStartY + max((contentHeight - ui.get(childIndex).box.h) div 2, 0)
      else:
        ui.get(childIndex).box.x =
          contentStartX + max((contentWidth - ui.get(childIndex).box.w) div 2, 0)
    of End:
      if w.dir == Row:
        ui.get(childIndex).box.y =
          contentStartY + max(contentHeight - ui.get(childIndex).box.h, 0)
      else:
        ui.get(childIndex).box.x =
          contentStartX + max(contentWidth - ui.get(childIndex).box.w, 0)
    else:
      if w.dir == Row:
        ui.get(childIndex).box.y = contentStartY
      else:
        ui.get(childIndex).box.x = contentStartX

proc updateLayout*(ui: var UI, container: tuple[x, y, w, h: int]) =
  ui.get(ui.root).box = container
  ui.get(ui.root).size = (
    #
    w: Sizing(kind: Fixed, min: container.w, max: container.w),
    h: Sizing(kind: Fixed, min: container.h, max: container.h),
  )
  ui.updateGrowContainer(ui.root)
  ui.updateLayout(ui.root)

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

proc writeLayout*(ui: UI, path: string) =
  var file = open(path, fmWrite)
  defer:
    file.close()

  proc findParent(child: WidgetIndex): int =
    for idx, widget in ui.widgets:
      for c in widget.children:
        if int(c) == int(child):
          return idx
    return -1

  file.writeLine("index parent dir align crossAlign x y w h text")
  for idx, widget in ui.widgets:
    let parent = findParent(WidgetIndex(idx))
    let line =
      "widget " & $idx & " parent " & $parent & " dir " & $widget.dir & " align " &
      $widget.align & " crossAlign " & $widget.crossAlign & " box(" & $widget.box.x & "," &
      $widget.box.y & "," & $widget.box.w & "," & $widget.box.h & ")" & " sizeW(" &
      $widget.size.w.kind & "," & $widget.size.w.min & "," & $widget.size.w.max & ")" &
      " sizeH(" & $widget.size.h.kind & "," & $widget.size.h.min & "," &
      $widget.size.h.max & ")" & " text \"" & widget.text & "\""
    file.writeLine(line)
