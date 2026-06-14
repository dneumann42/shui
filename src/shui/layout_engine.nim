import std/[tables, sets, strformat, strutils]
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
    logs*: seq[string]

proc fail(msg: string; logs: seq[string] = @[]): LayoutOutcome =
  LayoutOutcome(
    ok: false,
    error: LayoutError(msg: msg),
    measured: initTable[string, Size](),
    rects: initTable[string, Rect](),
    logs: logs,
  )

proc okOutcome(measured: Table[string, Size]; rects: Table[string, Rect]; logs: seq[string]): LayoutOutcome =
  LayoutOutcome(ok: true, measured: measured, rects: rects, logs: logs)

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

proc logLine(logs: var seq[string]; enabled: bool; msg: string) =
  if enabled:
    logs.add msg

proc measureNode(ui: UI; id: string; measured: var Table[string, Size];
                 logs: var seq[string]; logEnabled: bool): Size =
  if id in measured:
    logs.logLine(logEnabled, fmt"measure cache-hit id={id} size={measured[id].w}x{measured[id].h}")
    return measured[id]

  let el = ui.elements[id]
  if not el.visible:
    measured[id] = size(0, 0)
    logs.logLine(logEnabled, fmt"measure hidden id={id} size=0x0")
    return measured[id]

  let explicitMeasure = ui.measureById.getOrDefault(id, nil)
  if explicitMeasure != nil:
    if el.kind notin {Box, Text, Image}:
      for childId in ui.childrenById.getOrDefault(id, @[]):
        discard measureNode(ui, childId, measured, logs, logEnabled)
    let s = clampSize(explicitMeasure(el.maxSize.w, el.maxSize.h), el.minSize, el.maxSize)
    measured[id] = s
    logs.logLine(logEnabled, fmt"measure explicit id={id} kind={el.kind} size={s.w}x{s.h}")
    return s

  case el.kind
  of Box, Text, Image:
    var s = el.prefSize
    s = clampSize(s, el.minSize, el.maxSize)
    measured[id] = s
    logs.logLine(logEnabled, fmt"measure leaf id={id} kind={el.kind} size={s.w}x{s.h}")
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
      if not child.visible:
        continue
      if child.positionMode == FloatingPosition:
        discard measureNode(ui, childId, measured, logs, logEnabled)
        continue
      let childSize = measureNode(ui, childId, measured, logs, logEnabled)
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
    # Container preferred size is a lower bound before min/max clamping.
    box.w = max(box.w, el.prefSize.w)
    box.h = max(box.h, el.prefSize.h)

    box = clampSize(box, el.minSize, el.maxSize)
    measured[id] = box
    logs.logLine(logEnabled, fmt"measure container id={id} kind={el.kind} axis={axis} children={childCount} size={box.w}x{box.h}")
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

proc arrangeNode(ui: UI; id: string; rect: Rect; measured: Table[string, Size];
                 rects: var Table[string, Rect]; logs: var seq[string];
                 logEnabled: bool) =
  let el = ui.elements[id]
  if not el.visible:
    return
  rects[id] = rect
  logs.logLine(logEnabled, fmt"arrange id={id} kind={el.kind} rect=({rect.x},{rect.y},{rect.w},{rect.h})")
  if el.kind == Box or el.kind == Text:
    return

  let content = innerRect(rect, el.padding)
  if el.kind == RelayContainer and el.relayLayout.len > 0:
    var floatingChildren: seq[string] = @[]
    for childId in ui.childrenById.getOrDefault(id, @[]):
      let child = ui.elements[childId]
      if child.visible and child.positionMode == FloatingPosition:
        floatingChildren.add childId

    try:
      let parsed = parseLayout(el.relayLayout)
      let cells = resolve(parsed, content.w, content.h)
      for childId in ui.childrenById.getOrDefault(id, @[]):
        let child = ui.elements[childId]
        if not child.visible or child.positionMode == FloatingPosition:
          continue
        var cellName = childId
        let prefix = id & "."
        if childId.startsWith(prefix):
          cellName = childId.substr(prefix.len)
        if cellName in cells:
          let c = cells[cellName]
          let childRect = rect(content.x + c.x, content.y + c.y, c.w, c.h)
          logs.logLine(logEnabled, fmt"arrange relay child id={childId} cell={cellName} rect=({childRect.x},{childRect.y},{childRect.w},{childRect.h})")
          arrangeNode(ui, childId, childRect, measured, rects, logs, logEnabled)
        else:
          logs.logLine(logEnabled, fmt"arrange relay miss id={childId} cell={cellName}")

      for childId in floatingChildren:
        let child = ui.elements[childId]
        let childSize = measured.getOrDefault(childId, size(0, 0))
        let target =
          if child.anchorToId.len > 0 and child.anchorToId in rects:
            rects[child.anchorToId]
          else:
            content
        var x = target.x
        var y = target.y
        case child.anchor
        of AnchorTopLeft:
          x = target.x
          y = target.y
        of AnchorTopRight:
          x = target.x + target.w - childSize.w
          y = target.y
        of AnchorBottomLeft:
          x = target.x
          y = target.y + target.h - childSize.h
        of AnchorBottomRight:
          x = target.x + target.w - childSize.w
          y = target.y + target.h - childSize.h
        of AnchorCenter:
          x = target.x + (target.w - childSize.w) div 2
          y = target.y + (target.h - childSize.h) div 2
        let childRect = rect(x + child.offsetX, y + child.offsetY, childSize.w, childSize.h)
        arrangeNode(ui, childId, childRect, measured, rects, logs, logEnabled)
      return
    except CatchableError:
      logs.logLine(logEnabled, fmt"relay layout parse failed id={id}; fallback flow")

  let axis = axisForKind(el.kind)

  type ChildPlacement = object
    id: string
    margin: Sides
    base: Size
    allocatedMain: int

  var children: seq[ChildPlacement] = @[]
  var floatingChildren: seq[string] = @[]
  var baseMainSum = 0
  var flexSum = 0
  for childId in ui.childrenById.getOrDefault(id, @[]):
    let child = ui.elements[childId]
    if not child.visible:
      continue
    if child.positionMode == FloatingPosition:
      floatingChildren.add childId
      continue
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

    let effectiveCrossAlignForSize =
      case child.alignSelf
      of SelfAuto:
        case el.align
        of AlignStretch: SelfStretch
        of AlignStart: SelfStart
        of AlignEnd: SelfEnd
        of AlignCenter: SelfCenter
      else:
        child.alignSelf

    if effectiveCrossAlignForSize == SelfStretch:
      setCross(axis, childInner, maxCrossInner)
    else:
      setCross(axis, childInner, min(crossSize(axis, childInner), maxCrossInner))

    var crossPos = 0
    let effectiveCrossAlign =
      case child.alignSelf
      of SelfAuto:
        case el.align
        of AlignStart: SelfStart
        of AlignEnd: SelfEnd
        of AlignCenter: SelfCenter
        of AlignStretch: SelfStretch
      else:
        child.alignSelf

    case effectiveCrossAlign
    of SelfStart, SelfStretch:
      crossPos = crossMarginBefore
    of SelfEnd:
      crossPos = contentCross - crossMarginAfter - crossSize(axis, childInner)
    of SelfCenter:
      crossPos = (contentCross - crossSize(axis, childInner)) div 2
    of SelfAuto:
      discard

    let mainPos = cursor + mainMarginBefore

    var childRect = rect(0, 0, childInner.w, childInner.h)
    if axis == Horizontal:
      childRect.x = content.x + mainPos
      childRect.y = content.y + crossPos
    else:
      childRect.x = content.x + crossPos
      childRect.y = content.y + mainPos

    logs.logLine(logEnabled, fmt"arrange child id={c.id} parent={id} rect=({childRect.x},{childRect.y},{childRect.w},{childRect.h})")
    arrangeNode(ui, c.id, childRect, measured, rects, logs, logEnabled)

    cursor += outerMain
    if i < children.len - 1:
      cursor += just.gap

  for childId in floatingChildren:
    let child = ui.elements[childId]
    var childSize = measured.getOrDefault(childId, size(0, 0))
    let target =
      if child.anchorToId.len > 0 and child.anchorToId in rects:
        rects[child.anchorToId]
      else:
        content
    var x = target.x
    var y = target.y
    case child.anchor
    of AnchorTopLeft:
      x = target.x
      y = target.y
    of AnchorTopRight:
      x = target.x + target.w - childSize.w
      y = target.y
    of AnchorBottomLeft:
      x = target.x
      y = target.y + target.h - childSize.h
    of AnchorBottomRight:
      x = target.x + target.w - childSize.w
      y = target.y + target.h - childSize.h
    of AnchorCenter:
      x = target.x + (target.w - childSize.w) div 2
      y = target.y + (target.h - childSize.h) div 2
    let childRect = rect(x + child.offsetX, y + child.offsetY, childSize.w, childSize.h)
    logs.logLine(logEnabled, fmt"arrange floating child id={childId} anchor={child.anchor} target=({target.x},{target.y},{target.w},{target.h}) rect=({childRect.x},{childRect.y},{childRect.w},{childRect.h})")
    arrangeNode(ui, childId, childRect, measured, rects, logs, logEnabled)

proc layoutInRect*(ui: UI; rootId: string; rootRect: Rect; debugLog = false): LayoutOutcome =
  var logs: seq[string] = @[]
  logs.logLine(debugLog, fmt"layout start root={rootId} rect=({rootRect.x},{rootRect.y},{rootRect.w},{rootRect.h})")
  let err = validate(ui)
  if err.msg.len > 0:
    logs.logLine(debugLog, "layout validate error: " & err.msg)
    return fail(err.msg, logs)
  if rootId notin ui.elements:
    let m = fmt"missing layout root id: {rootId}"
    logs.logLine(debugLog, "layout root error: " & m)
    return fail(m, logs)

  var measured = initTable[string, Size]()
  discard measureNode(ui, rootId, measured, logs, debugLog)

  var rects = initTable[string, Rect]()
  arrangeNode(ui, rootId, rootRect, measured, rects, logs, debugLog)
  logs.logLine(debugLog, "layout done")
  return okOutcome(measured, rects, logs)

proc layoutWithUirelays*(ui: UI; layoutSrc: string; screenW, screenH: int; lineHeight = 20; padding = 6; gap = 0; debugLog = false): LayoutOutcome =
  var logs: seq[string] = @[]
  logs.logLine(debugLog, fmt"layout uirelays start screen={screenW}x{screenH}")
  let err = validate(ui)
  if err.msg.len > 0:
    logs.logLine(debugLog, "layout validate error: " & err.msg)
    return fail(err.msg, logs)

  let parsed = parseLayout(layoutSrc)
  let cells = resolve(parsed, screenW, screenH, lineHeight, padding, gap)

  var measured = initTable[string, Size]()
  var rects = initTable[string, Rect]()

  for cellName, rootId in ui.regionBindings:
    if rootId notin ui.elements:
      let m = fmt"region '{cellName}' bound to missing element id '{rootId}'"
      logs.logLine(debugLog, "layout bind error: " & m)
      return fail(m, logs)
    if cellName notin cells:
      let m = fmt"missing uirelays cell '{cellName}' for binding to '{rootId}'"
      logs.logLine(debugLog, "layout cell error: " & m)
      return fail(m, logs)
    logs.logLine(debugLog, fmt"layout cell bind cell={cellName} root={rootId} rect=({cells[cellName].x},{cells[cellName].y},{cells[cellName].w},{cells[cellName].h})")
    discard measureNode(ui, rootId, measured, logs, debugLog)
    arrangeNode(ui, rootId, cells[cellName], measured, rects, logs, debugLog)

  logs.logLine(debugLog, "layout uirelays done")
  return okOutcome(measured, rects, logs)
