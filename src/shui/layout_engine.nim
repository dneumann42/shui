import std/[tables, sets, strformat]
import uirelays/[coords, layout]
import ./elements

type
  LayoutError* = object
    msg*: string

  LayoutOutcome* = object
    ok*: bool
    error*: LayoutError
    measured*: Table[string, Size]
    rects*: Table[string, Rect]

proc fail(msg: string): LayoutOutcome =
  LayoutOutcome(
    ok: false,
    error: LayoutError(msg: msg),
    measured: initTable[string, Size](),
    rects: initTable[string, Rect](),
  )

proc okOutcome(measured: Table[string, Size]; rects: Table[string, Rect]): LayoutOutcome =
  LayoutOutcome(ok: true, measured: measured, rects: rects)

proc validate*(ui: UI): LayoutError =
  var seen = initHashSet[string]()
  for id, _ in ui.elements:
    if id in seen:
      return LayoutError(msg: fmt"duplicate element id: {id}")
    seen.incl(id)

  for rootId in ui.rootIds:
    if rootId notin ui.elements:
      return LayoutError(msg: fmt"missing root id: {rootId}")

  for id, el in ui.elements:
    for childId in ui.childrenById.getOrDefault(id, @[]):
      if childId notin ui.elements:
        return LayoutError(msg: fmt"missing child id '{childId}' referenced by '{id}'")
      let actualParent = ui.parentById.getOrDefault(childId, "")
      if actualParent != id:
        return LayoutError(msg: fmt"parent mismatch for child '{childId}', expected '{id}', got '{actualParent}'")

  var color = initTable[string, int]()
  proc dfs(id: string): LayoutError =
    if color.getOrDefault(id, 0) == 1:
      return LayoutError(msg: fmt"cycle detected at id '{id}'")
    if color.getOrDefault(id, 0) == 2:
      return LayoutError(msg: "")
    color[id] = 1
    for childId in ui.childrenById.getOrDefault(id, @[]):
      let e = dfs(childId)
      if e.msg.len > 0:
        return e
    color[id] = 2
    return LayoutError(msg: "")

  for id, _ in ui.elements:
    let e = dfs(id)
    if e.msg.len > 0:
      return e

  return LayoutError(msg: "")

proc measureNode(ui: UI; id: string; measured: var Table[string, Size]): Size =
  if id in measured:
    return measured[id]

  let el = ui.elements[id]
  case el.kind
  of Box, Text:
    var s = el.prefSize
    let measure = ui.measureById.getOrDefault(id, nil)
    if measure != nil:
      s = measure(el.maxSize.w, el.maxSize.h)
    s = clampSize(s, el.minSize, el.maxSize)
    measured[id] = s
    return s
  of VBox, HBox, RelayContainer:
    if el.kind == RelayContainer and el.relayLayout.len > 0:
      # Relay-based local layout still needs child measurement for fallback/aggregation.
      discard

    let axis = axisForKind(el.kind)
    var main = 0
    var cross = 0
    var childCount = 0

    for childId in ui.childrenById.getOrDefault(id, @[]):
      let child = ui.elements[childId]
      let childSize = measureNode(ui, childId, measured)
      let childOuter = outerSize(childSize, child.margin)
      main += mainSize(axis, childOuter)
      cross = max(cross, crossSize(axis, childOuter))
      inc childCount

    if childCount > 1:
      main += el.spacing * (childCount - 1)

    var content = size(0, 0)
    setMain(axis, content, main)
    setCross(axis, content, cross)

    var box = Size(
      w: content.w + el.padding.left + el.padding.right,
      h: content.h + el.padding.top + el.padding.bottom,
    )

    box = clampSize(box, el.minSize, el.maxSize)
    measured[id] = box
    return box

proc positionFromJustify(justify: Justify; containerMain, usedMain, count, spacing: int): tuple[start: int, gap: int] =
  let free = max(0, containerMain - usedMain)
  case justify
  of JustifyStart:
    (0, spacing)
  of JustifyEnd:
    (free, spacing)
  of JustifyCenter:
    (free div 2, spacing)
  of SpaceBetween:
    if count <= 1: (0, 0) else: (0, (free div (count - 1)) + spacing)
  of SpaceAround:
    if count <= 0: (0, spacing)
    else:
      let each = free div count
      (each div 2, spacing + each)
  of SpaceEvenly:
    if count <= 0: (0, spacing)
    else:
      let each = free div (count + 1)
      (each, spacing + each)

proc arrangeNode(ui: UI; id: string; rect: Rect; measured: Table[string, Size]; rects: var Table[string, Rect]) =
  rects[id] = rect
  let el = ui.elements[id]
  if el.kind == Box or el.kind == Text:
    return

  let axis = axisForKind(el.kind)
  let content = innerRect(rect, el.padding)

  type ChildPlacement = object
    id: string
    margin: Sides
    base: Size
    allocatedMain: int

  var children: seq[ChildPlacement] = @[]
  var baseMainSum = 0
  var flexSum = 0
  for childId in ui.childrenById.getOrDefault(id, @[]):
    let child = ui.elements[childId]
    let base = measured[childId]
    let mainMargins = if axis == Horizontal: child.margin.left + child.margin.right else: child.margin.top + child.margin.bottom
    var baseMain = mainSize(axis, base) + mainMargins
    if child.expand:
      flexSum += max(1, child.flex)
    children.add ChildPlacement(id: childId, margin: child.margin, base: base, allocatedMain: baseMain)
    baseMainSum += baseMain

  if children.len > 1:
    baseMainSum += el.spacing * (children.len - 1)

  let containerMain = if axis == Horizontal: content.w else: content.h
  let extra = max(0, containerMain - baseMainSum)
  if flexSum > 0 and extra > 0:
    for i in 0 ..< children.len:
      let child = ui.elements[children[i].id]
      if child.expand:
        children[i].allocatedMain += (extra * max(1, child.flex)) div flexSum

  var usedMain = 0
  for i, c in children:
    usedMain += c.allocatedMain
    if i < children.len - 1:
      usedMain += el.spacing

  let just = positionFromJustify(el.justify, containerMain, usedMain, children.len, el.spacing)
  var cursor = just.start

  for i, c in children:
    let child = ui.elements[c.id]
    let outerMain = c.allocatedMain
    let mainMarginBefore = if axis == Horizontal: c.margin.left else: c.margin.top
    let mainMarginAfter = if axis == Horizontal: c.margin.right else: c.margin.bottom
    let crossMarginBefore = if axis == Horizontal: c.margin.top else: c.margin.left
    let crossMarginAfter = if axis == Horizontal: c.margin.bottom else: c.margin.right

    let innerMain = max(0, outerMain - mainMarginBefore - mainMarginAfter)
    let contentCross = if axis == Horizontal: content.h else: content.w
    let maxCrossInner = max(0, contentCross - crossMarginBefore - crossMarginAfter)

    var childInner = c.base
    setMain(axis, childInner, innerMain)

    case el.align
    of AlignStretch:
      setCross(axis, childInner, maxCrossInner)
    else:
      setCross(axis, childInner, min(crossSize(axis, childInner), maxCrossInner))

    let crossPos =
      case el.align
      of AlignStart, AlignStretch:
        crossMarginBefore
      of AlignEnd:
        contentCross - crossMarginAfter - crossSize(axis, childInner)
      of AlignCenter:
        (contentCross - crossSize(axis, childInner)) div 2

    var childRect = rect(0, 0, childInner.w, childInner.h)
    if axis == Horizontal:
      childRect.x = content.x + cursor + mainMarginBefore
      childRect.y = content.y + crossPos
    else:
      childRect.x = content.x + crossPos
      childRect.y = content.y + cursor + mainMarginBefore

    arrangeNode(ui, c.id, childRect, measured, rects)

    cursor += outerMain
    if i < children.len - 1:
      cursor += just.gap

proc layoutInRect*(ui: UI; rootId: string; rootRect: Rect): LayoutOutcome =
  let err = validate(ui)
  if err.msg.len > 0:
    return fail(err.msg)
  if rootId notin ui.elements:
    return fail(fmt"missing layout root id: {rootId}")

  var measured = initTable[string, Size]()
  discard measureNode(ui, rootId, measured)

  var rects = initTable[string, Rect]()
  arrangeNode(ui, rootId, rootRect, measured, rects)
  return okOutcome(measured, rects)

proc layoutWithUirelays*(ui: UI; layoutSrc: string; screenW, screenH: int; lineHeight = 20; padding = 6; gap = 0): LayoutOutcome =
  let err = validate(ui)
  if err.msg.len > 0:
    return fail(err.msg)

  let parsed = parseLayout(layoutSrc)
  let cells = resolve(parsed, screenW, screenH, lineHeight, padding, gap)

  var measured = initTable[string, Size]()
  var rects = initTable[string, Rect]()

  for cellName, rootId in ui.regionBindings:
    if rootId notin ui.elements:
      return fail(fmt"region '{cellName}' bound to missing element id '{rootId}'")
    if cellName notin cells:
      return fail(fmt"missing uirelays cell '{cellName}' for binding to '{rootId}'")
    discard measureNode(ui, rootId, measured)
    arrangeNode(ui, rootId, cells[cellName], measured, rects)

  return okOutcome(measured, rects)
