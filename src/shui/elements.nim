import std/[tables]
import uirelays/coords

type
  ScrollState* = object
    contentId*: string
    enableX*: bool
    enableY*: bool
    offsetX*: int
    offsetY*: int
    thickness*: int
    minThumb*: int

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

  SelfAlign* = enum
    SelfAuto
    SelfStart
    SelfEnd
    SelfCenter
    SelfStretch

  Interactivity* = enum
    StaticElement
    ControlElement

  SurfaceStyle* = enum
    SurfaceAuto
    SurfaceFilled
    SurfaceBordered

  PositionMode* = enum
    FlowPosition
    FloatingPosition

  AnchorKind* = enum
    AnchorTopLeft
    AnchorTopRight
    AnchorBottomLeft
    AnchorBottomRight
    AnchorCenter

  ElementKind* = enum
    Box
    Image
    Text
    VBox
    HBox
    RelayContainer

  ButtonImageSpec* = object
    resourceId*: string
    source*: Rect
    hasSource*: bool
    size*: Size

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
    selected*: bool
    interactivity*: Interactivity
    surfaceStyle*: SurfaceStyle
    visible*: bool
    positionMode*: PositionMode
    anchor*: AnchorKind
    anchorToId*: string
    offsetX*: int
    offsetY*: int
    margin*: Sides
    minSize*: Size
    prefSize*: Size
    maxSize*: Size
    expand*: bool
    flex*: int
    alignSelf*: SelfAlign
    justifySelf*: SelfAlign
    backgroundImage*: ButtonImageSpec
    hideSurface*: bool
    case kind*: ElementKind
    of Box:
      discard
    of Image:
      imageSpec*: ButtonImageSpec
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
    hoveredId*: string
    clickedId*: string
    rootIds*: seq[string]
    regionBindings*: Table[string, string]
    scrollByViewport*: Table[string, ScrollState]
    openDialogs*: seq[string]

  Stringable = concept
    proc `$`(s: Self): string

proc clicked*(ui: UI, id: Stringable): bool =
  ui.clickedId == $id

proc buttonImage*(resourceId: string; size: Size): ButtonImageSpec =
  ButtonImageSpec(
    resourceId: resourceId,
    size: size,
    hasSource: false,
    source: rect(0, 0, size.w, size.h),
  )

proc buttonImage*(resourceId: string; source: Rect): ButtonImageSpec =
  ButtonImageSpec(
    resourceId: resourceId,
    size: Size(w: source.w, h: source.h),
    hasSource: true,
    source: source,
  )

proc normalizedSource*(spec: ButtonImageSpec): Rect =
  if spec.hasSource:
    spec.source
  else:
    rect(0, 0, spec.size.w, spec.size.h)

proc buttonImageSize*(spec: ButtonImageSpec): Size =
  if spec.hasSource:
    Size(w: spec.source.w, h: spec.source.h)
  else:
    spec.size

proc hasButtonImage*(spec: ButtonImageSpec): bool =
  spec.resourceId.len > 0

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
    hoveredId: "",
    clickedId: "",
    rootIds: @[],
    regionBindings: initTable[string, string](),
    scrollByViewport: initTable[string, ScrollState](),
    openDialogs: @[],
  )

proc beginFrame*(ui: var UI) =
  let hoveredId = ui.hoveredId
  let clickedId = ui.clickedId
  ui.elements.clear()
  ui.measureById.clear()
  ui.parentById.clear()
  ui.childrenById.clear()
  ui.buildStack.setLen(0)
  ui.rootIds.setLen(0)
  ui.regionBindings.clear()
  ui.scrollByViewport.clear()
  ui.openDialogs.setLen(0)
  ui.hoveredId = hoveredId
  ui.clickedId = clickedId

proc addElement*(ui: var UI; el: Element) =
  ui.elements[el.id] = el
  if el.id notin ui.childrenById:
    ui.childrenById[el.id] = @[]

proc setVisible*(ui: var UI; id: string; visible: bool) =
  if id notin ui.elements:
    return
  var el = ui.elements[id]
  el.visible = visible
  ui.elements[id] = el

proc setFloating*(ui: var UI; id: string; anchor = AnchorBottomLeft; anchorToId = ""; offsetX = 0; offsetY = 0) =
  if id notin ui.elements:
    return
  var el = ui.elements[id]
  el.positionMode = FloatingPosition
  el.anchor = anchor
  el.anchorToId = anchorToId
  el.offsetX = offsetX
  el.offsetY = offsetY
  ui.elements[id] = el

proc setRoot*(ui: var UI; id: string) =
  ui.rootIds.add id

proc addChild*(ui: var UI; parentId, childId: string) =
  if parentId notin ui.childrenById:
    ui.childrenById[parentId] = @[]
  ui.childrenById[parentId].add childId
  ui.parentById[childId] = parentId

proc setMeasure*(ui: var UI; id: string; measure: IntrinsicMeasureProc) =
  ui.measureById[id] = measure

proc registerScroll*(ui: var UI; viewportId, contentId: string; enableX, enableY: bool; thickness = 12; minThumb = 18) =
  ui.scrollByViewport[viewportId] = ScrollState(
    contentId: contentId,
    enableX: enableX,
    enableY: enableY,
    offsetX: 0,
    offsetY: 0,
    thickness: thickness,
    minThumb: minThumb,
  )

proc setScrollOffset*(ui: var UI; viewportId: string; offsetX, offsetY: int) =
  if viewportId notin ui.scrollByViewport:
    return
  var s = ui.scrollByViewport[viewportId]
  s.offsetX = offsetX
  s.offsetY = offsetY
  ui.scrollByViewport[viewportId] = s

proc isDialogOpen*(ui: UI; id: string): bool =
  for dialogId in ui.openDialogs:
    if dialogId == id:
      return true
  false

proc hasOpenDialogs*(ui: UI): bool =
  ui.openDialogs.len > 0

proc topDialogId*(ui: UI): string =
  if ui.openDialogs.len == 0: "" else: ui.openDialogs[^1]

proc openDialog*(ui: var UI; id: string) =
  if id.len == 0:
    return
  if not ui.isDialogOpen(id):
    ui.openDialogs.add id
  ui.setVisible(id, true)

proc closeDialog*(ui: var UI; id: string) =
  if id.len == 0:
    return
  var kept: seq[string] = @[]
  for dialogId in ui.openDialogs:
    if dialogId != id:
      kept.add dialogId
  ui.openDialogs = kept
  ui.setVisible(id, false)

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
  of Box, Image, Text: Vertical

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
