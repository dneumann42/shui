import std/[tables]
import std/os as stdos
import uirelays/[backend, screen, input, coords]
import ./[elements, layout_engine]

type
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
    panelFillColor*: Color
    panelInnerColor*: Color
    panelBorderColor*: Color
    textColor*: Color
    textBgColor*: Color
    fontPath*: string
    fontSize*: int
    relayLayoutSrc*: string

  RuntimeEventHook* = proc(ev: Event; ui: var UI; running: var bool) {.closure.}

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
    panelFillColor: color(58, 58, 74),
    panelInnerColor: color(34, 34, 44),
    panelBorderColor: color(110, 124, 150),
    textColor: color(232, 232, 232),
    textBgColor: color(72, 72, 72),
    fontPath: "",
    fontSize: 16,
    relayLayoutSrc: "",
  )

proc ensureTextMeasures(ui: var UI; f: Font) =
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

proc drawNode(ui: UI; id: string; rects: Table[string, Rect]; cfg: RuntimeConfig; font: Font) =
  if id notin rects:
    return
  let r = rects[id]
  let el = ui.elements[id]
  case el.kind
  of VBox, HBox, RelayContainer:
    drawSurface(r, el.surfaceStyle, cfg.containerColor, cfg)
  of Box:
    drawSurface(r, el.surfaceStyle, cfg.boxColor, cfg)
  of Text:
    let isControl = el.interactivity == ControlElement
    var textBg = color(0, 0, 0, 0)
    if isControl:
      let bg = if ui.hoveredId == id: cfg.buttonHoverColor else: cfg.buttonColor
      drawSurface(r, el.surfaceStyle, bg, cfg)
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

proc drawTreeFlow(ui: UI; id: string; rects: Table[string, Rect]; cfg: RuntimeConfig; font: Font) =
  drawNode(ui, id, rects, cfg, font)
  var flowChildren: seq[string] = @[]
  for childId in ui.childrenById.getOrDefault(id, @[]):
    if ui.elements[childId].positionMode != FloatingPosition:
      flowChildren.add childId

  for childId in flowChildren:
    drawTreeFlow(ui, childId, rects, cfg, font)

proc drawFloatingOverlays(ui: UI; id: string; rects: Table[string, Rect]; cfg: RuntimeConfig; font: Font) =
  for childId in ui.childrenById.getOrDefault(id, @[]):
    if ui.elements[childId].positionMode == FloatingPosition:
      # Draw the full floating subtree on top.
      drawTreeFlow(ui, childId, rects, cfg, font)
      drawFloatingOverlays(ui, childId, rects, cfg, font)
    else:
      drawFloatingOverlays(ui, childId, rects, cfg, font)

proc findHoveredControlFlow(ui: UI; id: string; rects: Table[string, Rect]; p: Point): string =
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
  findHoveredControlFlow(ui, rootId, rects, p)

proc runUirelayRuntime*(ui: var UI; rootId: string; cfg = defaultRuntimeConfig(); onEvent: RuntimeEventHook = nil) =
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
  var mouseX = -1
  var mouseY = -1
  while running:
    var ev: Event
    while pollEvent(ev):
      case ev.kind
      of QuitEvent, WindowCloseEvent:
        running = false
      of WindowResizeEvent:
        screenLayout.width = ev.x
        screenLayout.height = ev.y
      of MouseMoveEvent, MouseDownEvent, MouseUpEvent:
        mouseX = ev.x
        mouseY = ev.y
      else:
        discard

      if ev.kind == MouseDownEvent and ev.button == LeftButton:
        let frameNow =
          if cfg.relayLayoutSrc.len > 0:
            layoutWithUirelays(ui, cfg.relayLayoutSrc, screenLayout.width, screenLayout.height, cfg.lineHeight, cfg.padding, cfg.gap)
          else:
            layoutInRect(ui, rootId, rect(0, 0, screenLayout.width, screenLayout.height))
        if frameNow.ok:
          ui.clickedId = findHoveredControl(ui, rootId, frameNow.rects, point(ev.x, ev.y))
        else:
          ui.clickedId = ""
      elif ev.kind == MouseUpEvent and ev.button == LeftButton:
        ui.clickedId = ""

      if onEvent != nil:
        onEvent(ev, ui, running)

    let frame =
      if cfg.relayLayoutSrc.len > 0:
        layoutWithUirelays(ui, cfg.relayLayoutSrc, screenLayout.width, screenLayout.height, cfg.lineHeight, cfg.padding, cfg.gap)
      else:
        layoutInRect(ui, rootId, rect(0, 0, screenLayout.width, screenLayout.height))
    if frame.ok:
      if mouseX >= 0 and mouseY >= 0:
        ui.hoveredId = findHoveredControl(ui, rootId, frame.rects, point(mouseX, mouseY))
      else:
        ui.hoveredId = ""
      fillRect(rect(0, 0, screenLayout.width, screenLayout.height), cfg.background)
      drawTreeFlow(ui, rootId, frame.rects, cfg, font)
      drawFloatingOverlays(ui, rootId, frame.rects, cfg, font)
      refresh()

    if cfg.targetFps > 0:
      input.sleep(1000 div cfg.targetFps)

  if font != Font(0):
    closeFont(font)
  shutdown()
