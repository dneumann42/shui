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

proc drawTree(ui: UI; id: string; rects: Table[string, Rect]; cfg: RuntimeConfig; font: Font) =
  if id notin rects:
    return
  let r = rects[id]
  let el = ui.elements[id]
  case el.kind
  of VBox, HBox, RelayContainer:
    fillRect(r, cfg.containerColor)
  of Box:
    fillRect(r, cfg.boxColor)
  of Text:
    fillRect(r, cfg.textBgColor)
    if font != Font(0):
      let ext = measureText(font, el.text)
      let tx = r.x + max(0, (r.w - ext.w) div 2)
      let ty = r.y + max(0, (r.h - ext.h) div 2)
      discard drawText(font, tx, ty, el.text, cfg.textColor, cfg.textBgColor)

  for childId in ui.childrenById.getOrDefault(id, @[]):
    drawTree(ui, childId, rects, cfg, font)

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

      if onEvent != nil:
        onEvent(ev, ui, running)

    let frame =
      if cfg.relayLayoutSrc.len > 0:
        layoutWithUirelays(ui, cfg.relayLayoutSrc, screenLayout.width, screenLayout.height, cfg.lineHeight, cfg.padding, cfg.gap)
      else:
        layoutInRect(ui, rootId, rect(0, 0, screenLayout.width, screenLayout.height))
    if frame.ok:
      fillRect(rect(0, 0, screenLayout.width, screenLayout.height), cfg.background)
      drawTree(ui, rootId, frame.rects, cfg, font)
      refresh()

    if cfg.targetFps > 0:
      input.sleep(1000 div cfg.targetFps)

  if font != Font(0):
    closeFont(font)
  shutdown()
