import std/[tables]
import std/os as stdos
import uirelays/[screen, input, coords]
when not defined(shuiHostedOnly):
  import uirelays/backend
import ./[elements, layout_engine]

type
  ButtonImageDrawProc* = proc(spec: ButtonImageSpec; dst: Rect): bool {.nimcall.}

var buttonImageDrawHook*: pointer

type
  ScrollDragAxis = enum
    DragNone
    DragX
    DragY

  RuntimeConfig* = object
    title*: string
    width*: int
    height*: int
    targetFps*: int
    lineHeight*: int
    padding*: int
    gap*: int
    background*: Color
    containerColor*: Color
    boxColor*: Color
    buttonColor*: Color
    buttonHoverColor*: Color
    buttonPressedColor*: Color
    buttonBorderColor*: Color
    panelFillColor*: Color
    panelInnerColor*: Color
    panelBorderColor*: Color
    textColor*: Color
    textBgColor*: Color
    fontPath*: string
    fontSize*: int
    relayLayoutSrc*: string

  RuntimeEventHook* = proc(ev: Event; ui: var UI; running: var bool) {.closure.}

  HostedUiState* = object
    mouseX*: int
    mouseY*: int
    dragViewport: string
    dragAxis: ScrollDragAxis
    dragStartMouse: int
    dragStartOffset: int

proc defaultRuntimeConfig*(): RuntimeConfig =
  RuntimeConfig(
    title: "shui",
    width: 1024,
    height: 768,
    targetFps: 60,
    lineHeight: 20,
    padding: 6,
    gap: 0,
    background: color(24, 24, 24),
    containerColor: color(40, 40, 40),
    boxColor: color(72, 72, 72),
    buttonColor: color(70, 90, 120),
    buttonHoverColor: color(98, 126, 166),
    buttonPressedColor: color(130, 158, 198),
    buttonBorderColor: color(90, 115, 150),
    panelFillColor: color(58, 58, 74),
    panelInnerColor: color(34, 34, 44),
    panelBorderColor: color(110, 124, 150),
    textColor: color(232, 232, 232),
    textBgColor: color(72, 72, 72),
    fontPath: "",
    fontSize: 16,
    relayLayoutSrc: "",
  )

proc initHostedUiState*(): HostedUiState =
  HostedUiState(mouseX: -1, mouseY: -1)

proc ensureTextMeasures*(ui: var UI; f: Font) =
  if f == Font(0):
    return
  for id, el in ui.elements:
    if el.kind != Text:
      continue
    if id in ui.measureById:
      continue
    if el.prefSize.w > 0 or el.prefSize.h > 0:
      # Respect explicit layout sizing from the UI DSL/model.
      continue
    let textValue = el.text
    ui.setMeasure(id, proc(maxW, maxH: int): Size =
      discard maxW
      discard maxH
      let ext = measureText(f, textValue)
      size(ext.w, ext.h)
    )

proc findFontPath(preferred: string): string =
  if preferred.len > 0 and stdos.fileExists(preferred):
    return preferred

  let envPath = stdos.getEnv("SHUI_FONT_PATH", "")
  if envPath.len > 0 and stdos.fileExists(envPath):
    return envPath

  let candidates = [
    "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    "/usr/share/fonts/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
  ]
  for p in candidates:
    if stdos.fileExists(p):
      return p
  ""

proc drawBorder(r: Rect; color: Color) =
  if r.w <= 0 or r.h <= 0:
    return
  drawLine(r.x, r.y, r.x + r.w - 1, r.y, color)
  drawLine(r.x, r.y, r.x, r.y + r.h - 1, color)
  drawLine(r.x + r.w - 1, r.y, r.x + r.w - 1, r.y + r.h - 1, color)
  drawLine(r.x, r.y + r.h - 1, r.x + r.w - 1, r.y + r.h - 1, color)

proc drawSurface(r: Rect; style: SurfaceStyle; baseColor: Color; cfg: RuntimeConfig) =
  case style
  of SurfaceAuto:
    fillRect(r, baseColor)
  of SurfaceFilled:
    fillRect(r, cfg.panelFillColor)
  of SurfaceBordered:
    fillRect(r, cfg.panelInnerColor)
    drawBorder(r, cfg.panelBorderColor)

proc drawButtonImage(spec: ButtonImageSpec; dst: Rect): bool =
  if buttonImageDrawHook.isNil:
    return false
  let draw = cast[ButtonImageDrawProc](buttonImageDrawHook)
  draw(spec, dst)

proc drawNode(ui: UI; id: string; rects: Table[string, Rect]; cfg: RuntimeConfig; font: Font) =
  if id notin rects:
    return
  let r = rects[id]
  let el = ui.elements[id]
  case el.kind
  of VBox, HBox, RelayContainer:
    if el.interactivity == ControlElement:
      let bg =
        if ui.clickedId == id: cfg.buttonPressedColor
        elif ui.hoveredId == id: cfg.buttonHoverColor
        else: cfg.buttonColor
      if el.backgroundImage.hasButtonImage():
        if drawButtonImage(el.backgroundImage, r):
          fillRect(r, color(bg.r, bg.g, bg.b, 96'u8))
          drawBorder(r, cfg.buttonBorderColor)
        else:
          drawSurface(r, el.surfaceStyle, bg, cfg)
          drawBorder(r, cfg.buttonBorderColor)
      else:
        drawSurface(r, el.surfaceStyle, bg, cfg)
        drawBorder(r, cfg.buttonBorderColor)
    else:
      drawSurface(r, el.surfaceStyle, cfg.containerColor, cfg)
  of Box:
    drawSurface(r, el.surfaceStyle, cfg.boxColor, cfg)
  of Image:
    discard drawButtonImage(el.imageSpec, r)
  of Text:
    let isControl = el.interactivity == ControlElement
    var textBg = color(0, 0, 0, 0)
    if isControl:
      let bg =
        if ui.clickedId == id: cfg.buttonPressedColor
        elif ui.hoveredId == id: cfg.buttonHoverColor
        else: cfg.buttonColor
      drawSurface(r, el.surfaceStyle, bg, cfg)
      drawBorder(r, cfg.buttonBorderColor)
      textBg =
        case el.surfaceStyle
        of SurfaceAuto: bg
        of SurfaceFilled: cfg.panelFillColor
        of SurfaceBordered: cfg.panelInnerColor
    else:
      case el.surfaceStyle
      of SurfaceAuto:
        discard
      of SurfaceFilled:
        drawSurface(r, el.surfaceStyle, cfg.textBgColor, cfg)
        textBg = cfg.panelFillColor
      of SurfaceBordered:
        drawSurface(r, el.surfaceStyle, cfg.textBgColor, cfg)
        textBg = cfg.panelInnerColor
    if font != Font(0):
      let ext = measureText(font, el.text)
      let tx = r.x + max(0, (r.w - ext.w) div 2)
      let ty = r.y + max(0, (r.h - ext.h) div 2)
      discard drawText(font, tx, ty, el.text, cfg.textColor, textBg)

proc rectIntersection(a, b: Rect): Rect =
  let x0 = max(a.x, b.x)
  let y0 = max(a.y, b.y)
  let x1 = min(a.x + a.w, b.x + b.w)
  let y1 = min(a.y + a.h, b.y + b.h)
  rect(x0, y0, max(0, x1 - x0), max(0, y1 - y0))

proc maxScroll(viewportLen, contentLen: int): int =
  max(0, contentLen - viewportLen)

proc computeThumbRect(viewport: Rect; s: ScrollState; contentRect: Rect; horizontal: bool): Rect =
  let t = max(6, s.thickness)
  let minThumb = max(8, s.minThumb)
  if horizontal:
    let trackW = max(0, viewport.w - (if s.enableY: t else: 0))
    if trackW <= 0:
      return rect(viewport.x, viewport.y, 0, 0)
    let maxOff = maxScroll(viewport.w, contentRect.w)
    let thumbW =
      if maxOff == 0: trackW
      else: max(minThumb, (viewport.w * trackW) div max(1, contentRect.w))
    let thumbTravel = max(0, trackW - thumbW)
    let thumbX =
      if maxOff == 0: viewport.x
      else: viewport.x + (s.offsetX * thumbTravel) div maxOff
    return rect(thumbX, viewport.y + viewport.h - t, thumbW, t)
  else:
    let trackH = max(0, viewport.h - (if s.enableX: t else: 0))
    if trackH <= 0:
      return rect(viewport.x, viewport.y, 0, 0)
    let maxOff = maxScroll(viewport.h, contentRect.h)
    let thumbH =
      if maxOff == 0: trackH
      else: max(minThumb, (viewport.h * trackH) div max(1, contentRect.h))
    let thumbTravel = max(0, trackH - thumbH)
    let thumbY =
      if maxOff == 0: viewport.y
      else: viewport.y + (s.offsetY * thumbTravel) div maxOff
    return rect(viewport.x + viewport.w - t, thumbY, t, thumbH)

proc syncScrollOffsets(ui: var UI; rects: Table[string, Rect]) =
  for viewportId, scroll in ui.scrollByViewport.mpairs:
    if viewportId notin rects or scroll.contentId notin rects:
      continue
    let viewport = rects[viewportId]
    let content = rects[scroll.contentId]
    let maxX = if scroll.enableX: maxScroll(viewport.w, content.w) else: 0
    let maxY = if scroll.enableY: maxScroll(viewport.h, content.h) else: 0
    scroll.offsetX = max(0, min(scroll.offsetX, maxX))
    scroll.offsetY = max(0, min(scroll.offsetY, maxY))
    if scroll.contentId in ui.elements:
      ui.setFloating(scroll.contentId, anchor = AnchorTopLeft, anchorToId = viewportId, offsetX = -scroll.offsetX, offsetY = -scroll.offsetY)

proc drawScrollbars(ui: UI; rects: Table[string, Rect]) =
  for viewportId, scroll in ui.scrollByViewport:
    if viewportId notin rects or scroll.contentId notin rects:
      continue
    let viewport = rects[viewportId]
    let content = rects[scroll.contentId]
    if scroll.enableY and content.h > viewport.h:
      let thumb = computeThumbRect(viewport, scroll, content, horizontal = false)
      let track = rect(viewport.x + viewport.w - max(6, scroll.thickness), viewport.y, max(6, scroll.thickness), max(0, viewport.h - (if scroll.enableX: max(6, scroll.thickness) else: 0)))
      fillRect(track, color(44, 50, 62))
      fillRect(thumb, color(110, 130, 170))
    if scroll.enableX and content.w > viewport.w:
      let thumb = computeThumbRect(viewport, scroll, content, horizontal = true)
      let track = rect(viewport.x, viewport.y + viewport.h - max(6, scroll.thickness), max(0, viewport.w - (if scroll.enableY: max(6, scroll.thickness) else: 0)), max(6, scroll.thickness))
      fillRect(track, color(44, 50, 62))
      fillRect(thumb, color(110, 130, 170))

proc isInScrolledContent(ui: UI; id: string): tuple[inside: bool, viewportId: string] =
  var cur = id
  while cur.len > 0 and cur in ui.parentById:
    let parentId = ui.parentById[cur]
    if parentId in ui.scrollByViewport and ui.scrollByViewport[parentId].contentId == cur:
      return (true, parentId)
    cur = parentId
  (false, "")

proc drawTreeFlow(ui: UI; id: string; rects: Table[string, Rect]; cfg: RuntimeConfig; font: Font; activeClip: Rect) =
  var nextClip = activeClip
  let sc = ui.isInScrolledContent(id)
  if sc.inside and sc.viewportId in rects:
    nextClip = rectIntersection(activeClip, rects[sc.viewportId])
    setClipRect(nextClip)
  else:
    setClipRect(activeClip)
  drawNode(ui, id, rects, cfg, font)
  var flowChildren: seq[string] = @[]
  for childId in ui.childrenById.getOrDefault(id, @[]):
    if ui.elements[childId].positionMode != FloatingPosition:
      flowChildren.add childId

  for childId in flowChildren:
    drawTreeFlow(ui, childId, rects, cfg, font, nextClip)
  setClipRect(activeClip)

proc drawFloatingOverlays(ui: UI; id: string; rects: Table[string, Rect]; cfg: RuntimeConfig; font: Font; activeClip: Rect) =
  for childId in ui.childrenById.getOrDefault(id, @[]):
    if ui.elements[childId].positionMode == FloatingPosition:
      # Draw the full floating subtree on top.
      drawTreeFlow(ui, childId, rects, cfg, font, activeClip)
      drawFloatingOverlays(ui, childId, rects, cfg, font, activeClip)
    else:
      drawFloatingOverlays(ui, childId, rects, cfg, font, activeClip)

proc findHoveredControlFlow(ui: UI; id: string; rects: Table[string, Rect]; p: Point): string =
  let sc = ui.isInScrolledContent(id)
  if sc.inside and sc.viewportId in rects and not rects[sc.viewportId].contains(p):
    return ""
  var flowChildren: seq[string] = @[]
  for childId in ui.childrenById.getOrDefault(id, @[]):
    if ui.elements[childId].positionMode != FloatingPosition:
      flowChildren.add childId

  for i in countdown(flowChildren.len - 1, 0):
    let childId = flowChildren[i]
    let hit = findHoveredControlFlow(ui, childId, rects, p)
    if hit.len > 0:
      return hit
  if id in rects and ui.elements[id].interactivity == ControlElement and rects[id].contains(p):
    return id
  ""

proc findHoveredControlFloating(ui: UI; id: string; rects: Table[string, Rect]; p: Point): string =
  let sc = ui.isInScrolledContent(id)
  if sc.inside and sc.viewportId in rects and not rects[sc.viewportId].contains(p):
    return ""
  var floatingChildren: seq[string] = @[]
  for childId in ui.childrenById.getOrDefault(id, @[]):
    if ui.elements[childId].positionMode == FloatingPosition:
      floatingChildren.add childId

  for i in countdown(floatingChildren.len - 1, 0):
    let childId = floatingChildren[i]
    let hitFlow = findHoveredControlFlow(ui, childId, rects, p)
    if hitFlow.len > 0:
      return hitFlow
    let hitNested = findHoveredControlFloating(ui, childId, rects, p)
    if hitNested.len > 0:
      return hitNested

  for childId in ui.childrenById.getOrDefault(id, @[]):
    if ui.elements[childId].positionMode != FloatingPosition:
      let hit = findHoveredControlFloating(ui, childId, rects, p)
      if hit.len > 0:
        return hit
  ""

proc findHoveredControl(ui: UI; rootId: string; rects: Table[string, Rect]; p: Point): string =
  let top = findHoveredControlFloating(ui, rootId, rects, p)
  if top.len > 0:
    return top
  if ui.hasOpenDialogs():
    # Modal behavior: when any dialog is open, only floating controls are interactable.
    return ""
  findHoveredControlFlow(ui, rootId, rects, p)

proc hitTestControlId*(ui: UI; rootId: string; rects: Table[string, Rect]; p: Point): string =
  findHoveredControl(ui, rootId, rects, p)

proc layoutFrame*(
  ui: var UI;
  rootId: string;
  width, height: int;
  cfg = defaultRuntimeConfig()
): LayoutOutcome {.gcsafe.} =
  {.cast(gcsafe).}: # TODO(gcsafe): make this whole module gcsafe
    result =
      if cfg.relayLayoutSrc.len > 0:
        layoutWithUirelays(ui, cfg.relayLayoutSrc, width, height, cfg.lineHeight, cfg.padding, cfg.gap)
      else:
        layoutInRect(ui, rootId, rect(0, 0, width, height))
    if result.ok:
      ui.syncScrollOffsets(result.rects)

proc updateHovered*(
  ui: var UI;
  state: HostedUiState;
  rootId: string;
  frame: LayoutOutcome
) =
  if frame.ok and state.mouseX >= 0 and state.mouseY >= 0:
    ui.hoveredId = findHoveredControl(ui, rootId, frame.rects, point(state.mouseX, state.mouseY))
  else:
    ui.hoveredId = ""

proc handleEvent*(
  ui: var UI;
  state: var HostedUiState;
  rootId: string;
  cfg: RuntimeConfig;
  ev: Event;
  width, height: int;
  clearClickOnMouseUp = true
): bool =
  case ev.kind
  of MouseMoveEvent, MouseDownEvent, MouseUpEvent:
    state.mouseX = ev.x
    state.mouseY = ev.y
  else:
    discard

  if ev.kind == MouseDownEvent and ev.button == LeftButton:
    let frameNow = ui.layoutFrame(rootId, width, height, cfg)
    if frameNow.ok:
      for viewportId, scroll in ui.scrollByViewport:
        if viewportId notin frameNow.rects or scroll.contentId notin frameNow.rects:
          continue
        let p = point(ev.x, ev.y)
        if scroll.enableY:
          let thumbY = computeThumbRect(frameNow.rects[viewportId], scroll, frameNow.rects[scroll.contentId], horizontal = false)
          if thumbY.w > 0 and thumbY.h > 0 and thumbY.contains(p):
            state.dragViewport = viewportId
            state.dragAxis = DragY
            state.dragStartMouse = ev.y
            state.dragStartOffset = scroll.offsetY
            ui.clickedId = ""
            return true
        if scroll.enableX:
          let thumbX = computeThumbRect(frameNow.rects[viewportId], scroll, frameNow.rects[scroll.contentId], horizontal = true)
          if thumbX.w > 0 and thumbX.h > 0 and thumbX.contains(p):
            state.dragViewport = viewportId
            state.dragAxis = DragX
            state.dragStartMouse = ev.x
            state.dragStartOffset = scroll.offsetX
            ui.clickedId = ""
            return true
      ui.clickedId = findHoveredControl(ui, rootId, frameNow.rects, point(ev.x, ev.y))
      return ui.clickedId.len > 0
    ui.clickedId = ""
  elif ev.kind == MouseUpEvent and ev.button == LeftButton:
    if clearClickOnMouseUp:
      ui.clickedId = ""
    state.dragViewport = ""
    state.dragAxis = DragNone
  elif ev.kind == MouseMoveEvent and state.dragAxis != DragNone and state.dragViewport in ui.scrollByViewport:
    let frameNow = ui.layoutFrame(rootId, width, height, cfg)
    if frameNow.ok and state.dragViewport in frameNow.rects:
      var s = ui.scrollByViewport[state.dragViewport]
      if s.contentId in frameNow.rects:
        let vp = frameNow.rects[state.dragViewport]
        let ct = frameNow.rects[s.contentId]
        if state.dragAxis == DragY:
          let thumb = computeThumbRect(vp, s, ct, horizontal = false)
          let trackH = max(1, (vp.h - (if s.enableX: max(6, s.thickness) else: 0)) - thumb.h)
          let maxY = maxScroll(vp.h, ct.h)
          if maxY > 0 and trackH > 0:
            let deltaPx = ev.y - state.dragStartMouse
            s.offsetY = max(0, min(maxY, state.dragStartOffset + (deltaPx * maxY) div trackH))
        else:
          let thumb = computeThumbRect(vp, s, ct, horizontal = true)
          let trackW = max(1, (vp.w - (if s.enableY: max(6, s.thickness) else: 0)) - thumb.w)
          let maxX = maxScroll(vp.w, ct.w)
          if maxX > 0 and trackW > 0:
            let deltaPx = ev.x - state.dragStartMouse
            s.offsetX = max(0, min(maxX, state.dragStartOffset + (deltaPx * maxX) div trackW))
        ui.scrollByViewport[state.dragViewport] = s
      return true

  false

proc drawFrame*(
  ui: UI;
  rootId: string;
  frame: LayoutOutcome;
  cfg: RuntimeConfig;
  font: Font;
  width, height: int
) =
  if not frame.ok:
    return
  let fullClip = rect(0, 0, width, height)
  setClipRect(fullClip)
  fillRect(fullClip, cfg.background)
  drawTreeFlow(ui, rootId, frame.rects, cfg, font, fullClip)
  drawFloatingOverlays(ui, rootId, frame.rects, cfg, font, fullClip)
  drawScrollbars(ui, frame.rects)
  setClipRect(fullClip)

proc runUirelayRuntime*(ui: var UI; rootId: string; cfg = defaultRuntimeConfig(); onEvent: RuntimeEventHook = nil) =
  when defined(shuiHostedOnly):
    raise newException(CatchableError, "runUirelayRuntime is unavailable when compiled with -d:shuiHostedOnly")
  else:
    initBackend()

  var screenLayout = createWindow(cfg.width, cfg.height)
  setWindowTitle(cfg.title)

  var font = Font(0)
  var metrics: FontMetrics
  let fontPath = findFontPath(cfg.fontPath)
  if fontPath.len > 0:
    font = openFont(fontPath, cfg.fontSize, metrics)
    ui.ensureTextMeasures(font)
  else:
    echo "[shui] no usable font found; set cfg.fontPath or SHUI_FONT_PATH for text rendering"

  var running = true
  var hosted = initHostedUiState()
  while running:
    var ev: Event
    while pollEvent(ev):
      case ev.kind
      of QuitEvent, WindowCloseEvent:
        running = false
      of WindowResizeEvent:
        screenLayout.width = ev.x
        screenLayout.height = ev.y
      else:
        discard

      discard ui.handleEvent(hosted, rootId, cfg, ev, screenLayout.width, screenLayout.height)

      if onEvent != nil:
        onEvent(ev, ui, running)

    let frame = ui.layoutFrame(rootId, screenLayout.width, screenLayout.height, cfg)
    if frame.ok:
      ui.updateHovered(hosted, rootId, frame)
      ui.drawFrame(rootId, frame, cfg, font, screenLayout.width, screenLayout.height)
      refresh()

    if cfg.targetFps > 0:
      input.sleep(1000 div cfg.targetFps)

  if font != Font(0):
    closeFont(font)
  shutdown()
