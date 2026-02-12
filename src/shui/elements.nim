import std/[oids, sets, hashes, tables, options, macros, strformat]
import chroma

# Compile-time debug flag - set to true to enable debug visualization
const shuiDebug* {.booldefine.} = false

when shuiDebug:
  import std/strutils

type
  SizingKind* = enum
    Fixed
    Fit
    Grow

  Sizing* = object
    min*, max*: int
    kind*: SizingKind

  ElemState* = enum
    Visible
    Disabled
    Dead

  Direction* = enum
    Row
    Col

  Style* = object
    bg*, fg*, borderColor*: Color
    border* = 0
    padding* = 0
    gap* = 8
    borderRadius* = 0.0
    rotation* = 0.0  # Rotation in radians

  Align* = enum
    Start
    Center
    End

  DrawPhase* = enum
    BeforeChildren
    AfterChildren

  ElemId* = distinct string

  AbstractWidgetState* = ref object of RootObj
  WidgetState*[T] = ref object of AbstractWidgetState
    when T isnot void:
      state*: T

  Elem* = object
    id: ElemId
    size*: tuple[w, h: Sizing]
    floating*: bool
    absolute*: bool  # Absolute positioning (ignores parent layout)
    pos*: tuple[x, y: int]  # Absolute position when absolute=true
    clipOverflow*: bool
    scrollable*: bool
    scrollY*: float
    scrollThumbY*: int
    scrollThumbHeight*: int
    stopClip*: bool
    state*: ElemState
    text*: string
    style*: Style
    dir*: Direction
    align*: Align
    crossAlign*: Align
    textAlign*: Align
    border*: int
    box*: tuple[x, y, w, h: int]
    children*: seq[ElemIndex]

  ElemIndex* = distinct int

proc `==`*(a, b: ElemIndex): bool {.borrow.}

type
  Widget* = object
    box: tuple[x, y, w, h: int]
    focused = false

  BasicInput* = object
    mousePosition*: tuple[x, y: int]
    scrollY*: float
    actionPressed*: bool
    actionDown*: bool
    dragPressed*: bool
    dragDown*: bool
    backspacePressed*: bool
    enterPressed*: bool
    tabPressed*: bool
    textInput*: string

  ScrollState* = object
    scrollX, scrollY: float

  DrawElemProc = proc(elem: Elem, phase: DrawPhase): void {.gcsafe.}
  MeasureTextProc = proc(text: string): tuple[w, h: int] {.gcsafe.}

  DebugInfo* = object
    elemCount*: int
    rootCount*: int
    layoutDepth*: int
    drawCalls*: int

  UI* = object
    roots*: seq[ElemIndex]  # Support multiple roots for layered UI
    elems*: seq[Elem]
    drawElem: DrawElemProc
    measureText: MeasureTextProc

    widgets*: Table[ElemId, Widget]
    widgetState: Table[ElemId, AbstractWidgetState]
    boxes*: Table[ElemId, tuple[x, y, w, h: int]]

    when shuiDebug:
      debug*: DebugInfo

    input*: BasicInput

    blinkTimer*: float
    blinkTicker*: int
    hotElemId*: Option[ElemId]

    # Parent stack for preserving element hierarchy across proc calls
    parentStack: seq[ElemIndex]

proc init*(T: typedesc[UI]): T =
  T.default()

proc pushParent*(ui: var UI, parent: ElemIndex) =
  ## Push a parent element onto the stack
  ui.parentStack.add(parent)

proc popParent*(ui: var UI) =
  ## Pop the top parent element from the stack
  if ui.parentStack.len > 0:
    discard ui.parentStack.pop()

proc currentParent*(ui: UI): ElemIndex =
  ## Get the current parent from the stack, or -1 if none
  if ui.parentStack.len > 0:
    result = ui.parentStack[^1]
  else:
    result = ElemIndex(-1)

proc id*(e: Elem): ElemId =
  e.id

proc `==`*(a, b: ElemId): bool {.borrow.}
proc hash*(a: ElemId): Hash =
  a.string.hash()

proc cloneStringLiteral* (s: string): string =
  if s.len == 0:
    return newString(0)
  result = newString(s.len)
  copyMem(result.cstring, s.cstring, s.len)

proc cloneUi*(ui: UI): UI =
  var copy = UI()
  deepCopy(copy, ui)
  for i in 0 ..< copy.elems.len:
    copy.elems[i].text = cloneStringLiteral(copy.elems[i].text)
  result = copy

proc setState*[T](ui: var UI, eid: ElemId, state: T) =
  ui.widgetState[eid] = AbstractWidgetState(WidgetState[T](state: state))

proc getState*(ui: var UI, eid: ElemId, Ty: typedesc): Ty =
  var widgetState = cast[WidgetState[Ty]](ui.widgetState[eid])
  when compiles(widgetState.state):
    result = widgetState.state

proc hasState*(ui: var UI, eid: ElemId): bool =
  result = ui.widgetState.hasKey(eid)

proc focused*(widget: Widget): bool =
  widget.focused

proc `$`*(a: ElemId): string =
  a.string

converter toSizing*(kind: SizingKind): Sizing =
  Sizing(kind: kind)

const GrowSize* = Sizing(kind: Grow)
const FitSize* = Sizing(kind: Fit)

proc mget*(ui: UI, elemId: ElemId): lent Elem =
  for i in 0 ..< ui.elems.len:
    if ui.elems[i].id == elemId:
      return ui.elems[i]
  raise newException(ValueError, "Failed to find element of ID: " & $elemId)

proc get*(ui: UI, elemId: ElemId): Elem =
  for i in 0 ..< ui.elems.len:
    if ui.elems[i].id == elemId:
      return ui.elems[i]
  raise newException(ValueError, "Failed to find element of ID: " & $elemId)

proc registerWidget*(ui: var UI, eid: ElemId) =
  if ui.widgets.contains(eid):
    return
  ui.widgets[eid] = Widget()

proc hot*(eid: ElemId, ui: UI): bool =
  if not ui.widgets.contains(eid):
    return false
  let (x, y, w, h) = ui.widgets[eid].box
  let (mx, my) = ui.input.mousePosition
  result = mx > x and mx < x + w and my > y and my < y + h

proc pressed*(eid: ElemId, ui: var UI): bool =
  if not ui.widgets.contains(eid):
    return false
  result = eid.hot(ui) and ui.input.actionPressed
  if result:
    ui.input.actionPressed = false

proc focused*(eid: ElemId, ui: var UI): bool =
  if ui.widgets.contains(eid):
    return ui.widgets[eid].focused

proc focus*(eid: ElemId, ui: var UI) =
  if ui.widgets.contains(eid):
    ui.widgets[eid].focused = true

proc unfocus*(eid: ElemId, ui: var UI) =
  if ui.widgets.contains(eid):
    ui.widgets[eid].focused = false

proc down*(eid: ElemId, ui: var UI): bool =
  if not ui.widgets.contains(eid):
    return false
  result = eid.hot(ui) and ui.input.actionDown

proc color*(r, g, b: SomeFloat, a: SomeFloat = 1.0): Color =
  result = Color(r: r.float32, g: g.float32, b: b.float32, a: a.float32)

proc color*(v: SomeFloat): Color =
  result = Color(r: v, g: v, b: v, a: 1.0)

proc style*(
  bg = color(0.0),
  fg = color(0.0),
  borderColor = color(0.0),
  border = 0,
  padding = 0,
  gap = 8,
  borderRadius = 0.0,
  rotation = 0.0
): Style =
  result = Style(
    bg: bg, fg: fg, borderColor: borderColor,
    border: border,
    padding: padding,
    gap: gap,
    borderRadius: borderRadius,
    rotation: rotation
  )

proc `onDraw=`*(ui: var UI, fn: DrawElemProc) =
  ui.drawElem = fn

proc `onMeasureText=`*(ui: var UI, fn: MeasureTextProc) =
  ui.measureText = fn

proc begin*(ui: var UI) =
  for elem in ui.elems:
    if ui.widgets.contains(elem.id):
      ui.widgets[elem.id].box = elem.box
  ui.roots.setLen(0)
  ui.elems.setLen(0)

  when shuiDebug:
    ui.debug.elemCount = 0
    ui.debug.rootCount = 0
    ui.debug.layoutDepth = 0
    ui.debug.drawCalls = 0

proc hasDraw*(ui: var UI): bool =
  ui.drawElem.isNil == false

proc hasMeasureText*(ui: var UI): bool =
  ui.measureText.isNil == false

proc `[]=`*(ui: var UI, index: ElemIndex, elem: Elem) =
  ui.elems[int(index)] = elem

proc `[]`*(ui: var UI, index: ElemIndex): var Elem =
  result = ui.elems[int(index)]

proc get*(ui: var UI, index: ElemIndex): var Elem {.inline.} =
  ui[index]

iterator items*(ui: var UI, elem: ElemIndex): ElemIndex =
  for child in ui.get(elem).children:
    yield child

iterator items*(ui: var UI): ElemIndex =
  for root in ui.roots:
    for child in ui.items(root):
      yield child

proc createElem*(ui: var UI): ElemIndex =
  ui.elems.add(Elem(id: ElemId($genOid())))
  result = ElemIndex(ui.elems.len - 1)

  when shuiDebug:
    ui.debug.elemCount += 1
    echo fmt"[Shui Debug] Created elem {result.int}: {ui.elems[^1].id}"

proc beginElem*(ui: var UI, elem: Elem, parent = ElemIndex(-1)): ElemIndex =
  result = ui.createElem()
  ui[result] = elem
  if parent.int == -1:
    ui.roots.add(result)
    when shuiDebug:
      ui.debug.rootCount += 1
      echo fmt"[Shui Debug] Added root {result.int} (total roots: {ui.debug.rootCount})"

proc add*(ui: var UI, parent, child: ElemIndex) =
  ui.get(parent).children.add(child)

proc getDimensions*(ui: var UI, elemIndex: ElemIndex): tuple[w, h, maxW, maxH: int] =
  let container = ui.get(elemIndex)
  let gap = container.style.gap
  let dir = container.dir
  var childCount = 0
  for child in ui.items(elemIndex):
    let childElem = ui.get(child)
    if childElem.floating:
      continue
    let (_, _, w, h) = childElem.box
    let effW = max(w, childElem.size.w.min)
    let effH = max(h, childElem.size.h.min)
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

proc updateDimensions*(ui: var UI, elemIndex: ElemIndex) {.gcsafe.} =
  let w = ui.get(elemIndex)
  let padding = w.style.padding * 2

  if w.text.len > 0:
    # NOTE: I need to think of a way to remove the cast
    # the reason its needed is because of the callback ui.measureText
    # because I only pass it text, it needs access to some font
    # that would be captured in the closures environment... which isn't ideal
    # I should add a generic parameter to UI so I can give it the font
    {.cast(gcsafe).}:
      if ui.measureText.isNil:
        ui.measureText = proc(txt: string): auto =
          (w: txt.len, h: 1)
      let (tw, th) = ui.measureText(w.text)
      ui.get(elemIndex).box.w = tw + padding
      ui.get(elemIndex).box.h = th + padding
      return

  let (totalWidth, totalHeight, maxWidth, maxHeight) = ui.getDimensions(elemIndex)

  if w.dir == Row:
    if w.size.w.kind == Fit:
      ui.get(elemIndex).box.w = max(w.size.w.min, totalWidth)
    if w.size.h.kind == Fit:
      ui.get(elemIndex).box.h = max(w.size.h.min, maxHeight)
  else:
    if w.size.w.kind == Fit:
      ui.get(elemIndex).box.w = max(w.size.w.min, maxWidth)
    if w.size.h.kind == Fit:
      ui.get(elemIndex).box.h = max(w.size.h.min, totalHeight)

  ui.get(elemIndex).box.w += padding
  ui.get(elemIndex).box.h += padding

  let sizing = ui.get(elemIndex).size
  if sizing.w.min > 0:
    ui.get(elemIndex).box.w = max(ui.get(elemIndex).box.w, sizing.w.min)
  if sizing.w.max > 0:
    ui.get(elemIndex).box.w = min(ui.get(elemIndex).box.w, sizing.w.max)
  if sizing.h.min > 0:
    ui.get(elemIndex).box.h = max(ui.get(elemIndex).box.h, sizing.h.min)
  if sizing.h.max > 0:
    ui.get(elemIndex).box.h = min(ui.get(elemIndex).box.h, sizing.h.max)

proc clampDimension(value: int, sizing: Sizing): int =
  result = value
  if sizing.min > 0:
    result = max(result, sizing.min)
  if sizing.max > 0:
    result = min(result, sizing.max)

proc updateGrowContainer*(ui: var UI, elemIndex: ElemIndex) =
  let w = ui.get(elemIndex)
  let gap = w.style.gap
  let padding = w.style.padding * 2
  var layoutChildCount = 0
  for child in ui.items(elemIndex):
    let childElem = ui.get(child)
    if not childElem.floating and not childElem.absolute:
      inc layoutChildCount
  let gapTotal = gap * max(layoutChildCount - 1, 0)

  if w.dir == Row:
    var
      fixedWidth = 0
      growChildren: seq[tuple[index: ElemIndex, base: int]]

    for child in ui.items(elemIndex):
      let childElem = ui.get(child)
      if childElem.floating:
        continue
      if childElem.size.w.kind == Grow:
        growChildren.add((index: child, base: childElem.box.w))
      else:
        fixedWidth += childElem.box.w

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
      growChildren: seq[tuple[index: ElemIndex, base: int]]

    for child in ui.items(elemIndex):
      let childElem = ui.get(child)
      if childElem.floating:
        continue
      if childElem.size.h.kind == Grow:
        growChildren.add((index: child, base: childElem.box.h))
      else:
        fixedHeight += childElem.box.h

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

  let contentWidth = max(w.box.w - padding, 0)
  let contentHeight = max(w.box.h - padding, 0)
  for child in ui.items(elemIndex):
    let childSize = ui.get(child).size
    if w.dir == Col and childSize.w.kind == Grow:
      ui.get(child).box.w = clampDimension(contentWidth, childSize.w)
    if w.dir == Row and childSize.h.kind == Grow:
      ui.get(child).box.h = clampDimension(contentHeight, childSize.h)

  for child in ui.items(elemIndex):
    ui.updateGrowContainer(child)

proc updateLayout*(ui: var UI, elemIndex: ElemIndex) =
  # This traverses top to bottom of the tree
  # each node can assume it has been positioned already
  let w = ui.get(elemIndex)

  let (width, height, _, _) = ui.getDimensions(elemIndex)
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
  if w.scrollable:
    var scrollValue = w.scrollY
    var overflowAmount = 0
    if w.dir == Col:
      overflowAmount = max(height - contentHeight, 0)
      let overflow = overflowAmount.float
      if overflow <= 0.0:
        scrollValue = 0.0
      else:
        if scrollValue > 0.0:
          scrollValue = 0.0
        let minScroll = -overflow
        if scrollValue < minScroll:
          scrollValue = minScroll
      cursorY += scrollValue.int
    else:
      overflowAmount = max(width - contentWidth, 0)
      let overflow = overflowAmount.float
      if overflow <= 0.0:
        scrollValue = 0.0
      else:
        if scrollValue > 0.0:
          scrollValue = 0.0
        let minScroll = -overflow
        if scrollValue < minScroll:
          scrollValue = minScroll
      cursorX += scrollValue.int
    ui.get(elemIndex).scrollY = scrollValue
    if w.dir == Col:
      var thumbHeight = 0
      var thumbStart = 0
      if overflowAmount > 0 and contentHeight > 0 and height > 0:
        let viewport = contentHeight
        let contentSize = height
        let viewRatio = viewport.float / contentSize.float
        thumbHeight = max(int(viewRatio * viewport.float), 10)
        thumbHeight = min(thumbHeight, viewport)
        let maxThumbTravel = max(viewport - thumbHeight, 0)
        var ratio = if overflowAmount == 0: 0.0 else: (-scrollValue / overflowAmount.float)
        if ratio < 0.0:
          ratio = 0.0
        if ratio > 1.0:
          ratio = 1.0
        thumbStart = contentStartY + int(ratio * maxThumbTravel.float)
      ui.get(elemIndex).scrollThumbHeight = thumbHeight
      ui.get(elemIndex).scrollThumbY = thumbStart
    else:
      ui.get(elemIndex).scrollThumbHeight = 0
      ui.get(elemIndex).scrollThumbY = 0
    if ui.hasState(w.id):
      var scrollState = ui.getState(w.id, ScrollState)
      scrollState.scrollY = scrollValue
      ui.setState(w.id, scrollState)
  else:
    ui.get(elemIndex).scrollThumbHeight = 0
    ui.get(elemIndex).scrollThumbY = 0

  let gap = w.style.gap
  var layoutChildCount = 0
  for child in ui.items(elemIndex):
    let childElem = ui.get(child)
    if not childElem.floating and not childElem.absolute:
      inc layoutChildCount
  var childIndexCounter = 0

  for child in ui.items(elemIndex):
    let childIndex = child
    let childElem = ui.get(childIndex)
    let isFloating = childElem.floating
    let isAbsolute = childElem.absolute

    # Absolute positioned elements use their pos field
    if isAbsolute:
      ui.get(childIndex).box.x = childElem.pos.x
      ui.get(childIndex).box.y = childElem.pos.y
      ui.updateLayout(childIndex)
      continue

    # Normal flow layout
    if w.dir == Row:
      ui.get(childIndex).box.x = cursorX
      ui.get(childIndex).box.y = contentStartY
    else:
      ui.get(childIndex).box.x = contentStartX
      ui.get(childIndex).box.y = cursorY

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

    ui.updateLayout(childIndex)

    if not isFloating:
      if w.dir == Row:
        cursorX += ui.get(childIndex).box.w
        if childIndexCounter < layoutChildCount - 1:
          cursorX += gap
      else:
        cursorY += ui.get(childIndex).box.h
        if childIndexCounter < layoutChildCount - 1:
          cursorY += gap
      inc childIndexCounter

proc updateLayout*(ui: var UI, container: tuple[x, y, w, h: int]) =
  if ui.elems.len == 0:
    return

  # Layout all roots with the same container bounds
  for root in ui.roots:
    let rootSize = ui.get(root).size

    # Set position from container
    ui.get(root).box.x = container.x
    ui.get(root).box.y = container.y

    # Calculate width based on sizing kind
    case rootSize.w.kind:
    of Fixed:
      ui.get(root).box.w = clampDimension(rootSize.w.max, rootSize.w)
    of Grow:
      ui.get(root).box.w = clampDimension(container.w, rootSize.w)
    of Fit:
      # Fit will be calculated by updateGrowContainer
      ui.get(root).box.w = container.w

    # Calculate height based on sizing kind
    case rootSize.h.kind:
    of Fixed:
      ui.get(root).box.h = clampDimension(rootSize.h.max, rootSize.h)
    of Grow:
      ui.get(root).box.h = clampDimension(container.h, rootSize.h)
    of Fit:
      # Fit will be calculated by updateGrowContainer
      ui.get(root).box.h = container.h

    ui.updateGrowContainer(root)
    ui.updateLayout(root)

  ui.hotElemId = none(ElemId)
  for e in ui.elems:
    ui.boxes[e.id] = e.box
    if e.id.hot(ui):
      ui.hotElemId = some(e.id)

proc endElem*(ui: var UI, parent, elemIndex: ElemIndex) {.gcsafe.} =
  if parent.int != -1:
    ui.add(parent, elemIndex)
  ui.updateDimensions(elemIndex)

proc updateElem(blk: NimNode): auto =
  result = blk
  for i in 0 ..< blk.len:
    if blk[i].kind == nnkAsgn:
      let dot = nnkDotExpr.newTree(newIdentNode("ui"), newIdentNode("get"))
      let call = nnkCall.newTree(dot, newIdentNode("elemIndex"))
      blk[i] = nnkAsgn.newTree(nnkDotExpr.newTree(call, blk[i][0]), blk[i][1])

template withParent*(ui: var UI, parent: ElemIndex, body: untyped) =
  ## Execute body with a specific parent element context
  ## This allows factoring out UI code into procs while preserving parent-child relationships
  ui.pushParent(parent)
  try:
    body
  finally:
    ui.popParent()

macro elem*(blk: untyped) =
  let newBlk = updateElem(blk)

  quote:
    block:
      let parent {.inject.} = when compiles(elemIndex):
        elemIndex
      else:
        ui.currentParent()
      var elemIndex {.inject.} = ui.beginElem(Elem(), parent)
      var elemId {.inject.} = ui.elems[elemIndex.int].id
      `newBlk`
      elemId = ui.elems[elemIndex.int].id

      if ui.elems[elemIndex.int].scrollable:
        ui.registerWidget(elemId)

      if ui.elems[elemIndex.int].scrollable and elemId.hot(ui):
        if not ui.hasState(elemId):
          ui.setState(elemId, ScrollState())
        var state = ui.getState(elemId, ScrollState)
        state.scrollY += ui.input.scrollY
        ui.elems[elemIndex.int].scrollY = state.scrollY
        ui.setState(elemId, state)

      ui.endElem(parent, elemIndex)

macro label*(text: string, blk: untyped) =
  let newBlk = updateElem(blk)
  quote:
    block:
      when compiles(elemIndex):
        let parent {.inject.} = elemIndex
      else:
        let parent {.inject.} = ElemIndex(-1)
      var elemIndex {.inject.} = ui.beginElem(Elem(), parent)
      ui.get(elemIndex).text = `text`
      ui.get(elemIndex).style = style(
        fg = color(1.0, 1.0, 1.0, 1.0)
      )
      `newBlk`
      ui.endElem(parent, elemIndex)

macro unclippedElem*(blk: untyped) =
  quote:
    elem:
      stopClip = true
      `blk`

proc updateWidgets*(ui: var UI, deltaTime: float) =
  ui.blinkTimer += deltaTime
  if ui.blinkTimer > 0.0016 * 100.0:
    inc ui.blinkTicker
    ui.blinkTimer = 0.0
  for action in ui.widgets.keys:
    discard

proc draw*(ui: var UI, elem: Elem, phase: DrawPhase) {.gcsafe.} =
  if ui.hasDraw():
    ui.drawElem(elem, phase)

proc drawFloatingSubtree(ui: var UI, elemIndex: ElemIndex) =
  ui.draw(ui.get(elemIndex), BeforeChildren)
  for child in ui.items(elemIndex):
    ui.drawFloatingSubtree(child)
  ui.draw(ui.get(elemIndex), AfterChildren)

proc drawNonFloatingSubtree(
  ui: var UI,
  elemIndex: ElemIndex,
  floatingElems: var seq[ElemIndex]
) =
  let elem = ui.get(elemIndex)
  if elem.floating:
    floatingElems.add(elemIndex)
    return

  ui.draw(elem, BeforeChildren)
  for child in ui.items(elemIndex):
    ui.drawNonFloatingSubtree(child, floatingElems)
  ui.draw(elem, AfterChildren)

proc draw*(ui: var UI, elemIndex: ElemIndex) =
  var floatingElems: seq[ElemIndex] = @[]
  ui.drawNonFloatingSubtree(elemIndex, floatingElems)

  # Draw floating elements after everything else so they appear above non-floating content.
  for elem in floatingElems:
    ui.drawFloatingSubtree(elem)

proc draw*(ui: var UI) =
  if ui.elems.len == 0:
    return
  # Draw all roots in order (first root = bottom layer, last root = top layer)
  for root in ui.roots:
    ui.draw(root)
    when shuiDebug:
      ui.debug.drawCalls += 1

proc layoutToString*(ui: UI): string =
  proc findParent(child: ElemIndex): int =
    result = -1
    for idx, elem in ui.elems:
      for c in elem.children:
        if int(c) == int(child):
          return idx

  result.add("index parent dir align crossAlign x y w h text")
  for idx, elem in ui.elems:
    let parent = findParent(ElemIndex(idx))
    let line =
      "elem " & $idx & " parent " & $parent & " dir " & $elem.dir & " align " &
      $elem.align & " crossAlign " & $elem.crossAlign & " box(" & $elem.box.x & "," &
      $elem.box.y & "," & $elem.box.w & "," & $elem.box.h & ")" & " sizeW(" &
      $elem.size.w.kind & "," & $elem.size.w.min & "," & $elem.size.w.max & ")" &
      " sizeH(" & $elem.size.h.kind & "," & $elem.size.h.min & "," & $elem.size.h.max &
      ")" & " text \"" & elem.text & "\""
    result.add("\n")
    result.add(line)

proc writeLayout*(ui: UI, path: string) =
  var file = open(path, fmWrite)
  defer:
    file.close()
  file.write(ui.layoutToString())

# ==================== Debug Visualization ====================

when shuiDebug:
  type
    DebugDrawProc* = proc(x, y, w, h: int, color: Color, text: string = "") {.gcsafe.}

  var gDebugDrawProc: DebugDrawProc = nil

  proc setDebugDrawProc*(fn: DebugDrawProc) =
    ## Set the drawing function for debug visualization
    gDebugDrawProc = fn

  proc getSizingKindStr(s: Sizing): string =
    case s.kind
    of Fixed: fmt"Fixed({s.min})"
    of Fit: "Fit"
    of Grow: "Grow"

  proc drawDebugOverlay*(ui: var UI) =
    ## Draw debug visualization over the UI
    ## Call this after ui.draw() to see debug info
    if gDebugDrawProc.isNil:
      return

    # Draw stats in top-left corner
    gDebugDrawProc(5, 5, 200, 80, color(0.0, 0.0, 0.0, 0.8),
      fmt"""Shui Debug Stats:
Elements: {ui.debug.elemCount}
Roots: {ui.debug.rootCount}
Draw Calls: {ui.debug.drawCalls}""")

    # Draw all element boundaries
    for i, elem in ui.elems:
      let box = elem.box
      var debugColor = color(0.0, 1.0, 0.0, 0.4)  # Green for normal elements
      var label = fmt"#{i}"

      # Color code by type
      if elem.floating:
        debugColor = color(1.0, 0.65, 0.0, 0.4)  # Orange for floating
        label &= " [Float]"
      elif elem.absolute:
        debugColor = color(1.0, 0.0, 1.0, 0.4)  # Magenta for absolute
        label &= fmt" [Abs:{elem.pos.x},{elem.pos.y}]"

      # Color code roots specially
      if ElemIndex(i) in ui.roots:
        debugColor = color(1.0, 1.0, 0.0, 0.6)  # Yellow for roots
        label = fmt"ROOT {i}"

      # Draw box outline and info
      let sizeInfo = fmt"{getSizingKindStr(elem.size.w)} x {getSizingKindStr(elem.size.h)}"
      let boxInfo = fmt"{box.w}x{box.h} @ ({box.x},{box.y})"
      gDebugDrawProc(box.x, box.y, box.w, box.h, debugColor, fmt"{label}\n{sizeInfo}\n{boxInfo}")

  proc logLayoutInfo*(ui: UI, elemIndex: ElemIndex, depth: int = 0) =
    ## Recursively log layout tree structure
    let elem = ui.elems[elemIndex.int]
    let indent = repeat("  ", depth)
    let box = elem.box
    
    var flags = newSeq[string]()
    if elem.floating: flags.add("float")
    if elem.absolute: flags.add(fmt"abs:{elem.pos.x},{elem.pos.y}")
    if ElemIndex(elemIndex.int) in ui.roots: flags.add("ROOT")
    
    let flagStr = if flags.len > 0: " [" & flags.join(", ") & "]" else: ""
    
    echo fmt"{indent}Elem {elemIndex.int}{flagStr}:"
    echo fmt"{indent}  Size: {getSizingKindStr(elem.size.w)} x {getSizingKindStr(elem.size.h)}"
    echo fmt"{indent}  Box: {box.w}x{box.h} @ ({box.x},{box.y})"
    echo fmt"{indent}  Style: dir={elem.dir}, align={elem.align}, gap={elem.style.gap}"
    
    if elem.text.len > 0:
      echo fmt"{indent}  Text: '{elem.text}'"
    
    if elem.children.len > 0:
      echo fmt"{indent}  Children: {elem.children.len}"
      for child in elem.children:
        ui.logLayoutInfo(child, depth + 1)

  proc dumpLayoutTree*(ui: UI) =
    ## Dump entire layout tree to console
    echo "\n========== Shui Layout Tree =========="
    echo fmt"Total Elements: {ui.elems.len}"
    echo fmt"Roots: {ui.roots.len}"
    for i, root in ui.roots:
      echo fmt"\n--- Root {i} (Element {root.int}) ---"
      ui.logLayoutInfo(root, 0)
    echo "======================================\n"

# Box API - Convenience functions for widget box management
proc getBox*(ui: UI, id: ElemId): tuple[x, y, w, h: int] =
  ## Get the bounding box for a widget by ID
  ## Returns (0, 0, 0, 0) if box doesn't exist
  if ui.boxes.hasKey(id):
    return ui.boxes[id]
  else:
    return (x: 0, y: 0, w: 0, h: 0)

proc setBox*(ui: var UI, id: ElemId, box: tuple[x, y, w, h: int]) =
  ## Set the bounding box for a widget
  ui.boxes[id] = box

proc setBox*(ui: var UI, id: ElemId, x, y, w, h: int) =
  ## Set the bounding box for a widget (individual parameters)
  ui.boxes[id] = (x: x, y: y, w: w, h: h)

proc hasBox*(ui: UI, id: ElemId): bool =
  ## Check if a widget box exists
  ui.boxes.hasKey(id)

proc removeBox*(ui: var UI, id: ElemId) =
  ## Remove a widget box
  ui.boxes.del(id)
