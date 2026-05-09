import std/[tables]
import uirelays/coords

type
  Axis* = enum
    Horizontal
    Vertical

  Justify* = enum
    JustifyStart
    JustifyEnd
    JustifyCenter
    SpaceBetween
    SpaceAround
    SpaceEvenly

  Align* = enum
    AlignStart
    AlignEnd
    AlignCenter
    AlignStretch

  ElementKind* = enum
    Box
    Text
    VBox
    HBox
    RelayContainer

  Sides* = object
    top*: int
    right*: int
    bottom*: int
    left*: int

  Size* = object
    w*: int
    h*: int

  IntrinsicMeasureProc* = proc(maxW, maxH: int): Size {.closure.}

  Element* = object
    id*: string
    margin*: Sides
    minSize*: Size
    prefSize*: Size
    maxSize*: Size
    expand*: bool
    flex*: int
    case kind*: ElementKind
    of Box:
      discard
    of Text:
      text*: string
    of VBox, HBox, RelayContainer:
      justify*: Justify
      align*: Align
      spacing*: int
      padding*: Sides
      relayLayout*: string

  UI* = object
    elements*: Table[string, Element]
    measureById*: Table[string, IntrinsicMeasureProc]
    parentById*: Table[string, string]
    childrenById*: Table[string, seq[string]]
    buildStack*: seq[string]
    rootIds*: seq[string]
    regionBindings*: Table[string, string]

proc zeroSides*(): Sides =
  Sides(top: 0, right: 0, bottom: 0, left: 0)

proc uniformSides*(n: int): Sides =
  Sides(top: n, right: n, bottom: n, left: n)

proc size*(w, h: int): Size =
  Size(w: w, h: h)

proc initUi*(): UI =
  UI(
    elements: initTable[string, Element](),
    measureById: initTable[string, IntrinsicMeasureProc](),
    parentById: initTable[string, string](),
    childrenById: initTable[string, seq[string]](),
    buildStack: @[],
    rootIds: @[],
    regionBindings: initTable[string, string](),
  )

proc addElement*(ui: var UI; el: Element) =
  ui.elements[el.id] = el
  if el.id notin ui.childrenById:
    ui.childrenById[el.id] = @[]

proc setRoot*(ui: var UI; id: string) =
  ui.rootIds.add id

proc addChild*(ui: var UI; parentId, childId: string) =
  if parentId notin ui.childrenById:
    ui.childrenById[parentId] = @[]
  ui.childrenById[parentId].add childId
  ui.parentById[childId] = parentId

proc setMeasure*(ui: var UI; id: string; measure: IntrinsicMeasureProc) =
  ui.measureById[id] = measure

proc pushBuildParent*(ui: var UI; id: string) =
  ui.buildStack.add id

proc popBuildParent*(ui: var UI) =
  if ui.buildStack.len > 0:
    discard ui.buildStack.pop()

proc currentBuildParent*(ui: UI): string =
  if ui.buildStack.len == 0:
    ""
  else:
    ui.buildStack[^1]

proc clampSize*(s, minS, maxS: Size): Size =
  result.w = max(minS.w, s.w)
  result.h = max(minS.h, s.h)
  if maxS.w > 0:
    result.w = min(result.w, maxS.w)
  if maxS.h > 0:
    result.h = min(result.h, maxS.h)

proc axisForKind*(kind: ElementKind): Axis =
  case kind
  of HBox: Horizontal
  of VBox, RelayContainer: Vertical
  of Box, Text: Vertical

proc mainSize*(axis: Axis; s: Size): int =
  if axis == Horizontal: s.w else: s.h

proc crossSize*(axis: Axis; s: Size): int =
  if axis == Horizontal: s.h else: s.w

proc setMain*(axis: Axis; s: var Size; value: int) =
  if axis == Horizontal:
    s.w = value
  else:
    s.h = value

proc setCross*(axis: Axis; s: var Size; value: int) =
  if axis == Horizontal:
    s.h = value
  else:
    s.w = value

proc outerSize*(inner: Size; m: Sides): Size =
  Size(w: inner.w + m.left + m.right, h: inner.h + m.top + m.bottom)

proc innerRect*(r: Rect; pad: Sides): Rect =
  let x = r.x + pad.left
  let y = r.y + pad.top
  let w = max(0, r.w - pad.left - pad.right)
  let h = max(0, r.h - pad.top - pad.bottom)
  Rect(x: x, y: y, w: w, h: h)
