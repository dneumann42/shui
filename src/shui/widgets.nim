import ./elements

type
  BoxOpts* = object
    justify*: Justify
    align*: Align
    spacing*: int
    padding*: Sides
    margin*: Sides
    minSize*: Size
    prefSize*: Size
    maxSize*: Size
    expand*: bool
    flex*: int

  PanelStyle* = enum
    FilledPanel
    BorderedPanel

proc boxOpts*(justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): BoxOpts =
  BoxOpts(
    justify: justify,
    align: align,
    spacing: spacing,
    padding: padding,
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
  )

proc boxElement*(id: string; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: Box,
    interactivity: StaticElement,
    surfaceStyle: SurfaceAuto,
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
    alignSelf: SelfAuto,
    justifySelf: SelfAuto,
  )

proc textElement*(id: string; text: string; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto): Element =
  Element(
    id: id,
    kind: Text,
    interactivity: StaticElement,
    surfaceStyle: SurfaceAuto,
    text: text,
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
    alignSelf: alignSelf,
    justifySelf: justifySelf,
  )

proc vboxElement*(id: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: VBox,
    interactivity: StaticElement,
    surfaceStyle: SurfaceAuto,
    justify: justify,
    align: align,
    spacing: spacing,
    padding: padding,
    relayLayout: "",
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
    alignSelf: SelfAuto,
    justifySelf: SelfAuto,
  )

proc hboxElement*(id: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: HBox,
    interactivity: StaticElement,
    surfaceStyle: SurfaceAuto,
    justify: justify,
    align: align,
    spacing: spacing,
    padding: padding,
    relayLayout: "",
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
    alignSelf: SelfAuto,
    justifySelf: SelfAuto,
  )

proc relayElement*(id: string; relayLayout: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: RelayContainer,
    interactivity: StaticElement,
    surfaceStyle: SurfaceAuto,
    justify: justify,
    align: align,
    spacing: spacing,
    padding: padding,
    relayLayout: relayLayout,
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
    alignSelf: SelfAuto,
    justifySelf: SelfAuto,
  )

proc addWidget*(ui: var UI; el: Element; parentId = ""): string =
  ui.addElement(el)
  if parentId.len > 0:
    ui.addChild(parentId, el.id)
  el.id

proc addChildren*(ui: var UI; parentId: string; childIds: openArray[string]) =
  for id in childIds:
    ui.addChild(parentId, id)

template layout*(ui: var UI; rootId: string; body: untyped) =
  ui.setRoot(rootId)
  body

proc resolveParentId(ui: UI; parentId: string): string =
  if parentId.len > 0: parentId else: ui.currentBuildParent()

proc applyPanelStyle(el: var Element; style: PanelStyle) =
  case style
  of FilledPanel:
    el.surfaceStyle = SurfaceFilled
  of BorderedPanel:
    el.surfaceStyle = SurfaceBordered

template vbox*(ui: var UI; id: string; opts = boxOpts(); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    discard ui.addWidget(vboxElement(id, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex), parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template hbox*(ui: var UI; id: string; opts = boxOpts(); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    discard ui.addWidget(hboxElement(id, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex), parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template panel*(ui: var UI; id: string; style: PanelStyle; opts: BoxOpts; body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    var el = vboxElement(id, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex)
    applyPanelStyle(el, style)
    discard ui.addWidget(el, parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template panelRow*(ui: var UI; id: string; style: PanelStyle; opts: BoxOpts; body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    var el = hboxElement(id, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex)
    applyPanelStyle(el, style)
    discard ui.addWidget(el, parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template panel*(ui: var UI; id: string; style: PanelStyle; body: untyped) =
  ui.panel(id, style, boxOpts()):
    body

template card*(ui: var UI; id: string; style: PanelStyle; opts: BoxOpts; body: untyped) =
  ui.panel(id, style, opts):
    body

template card*(ui: var UI; id: string; style: PanelStyle; body: untyped) =
  ui.card(id, style, boxOpts(spacing = 8, padding = uniformSides(12), align = AlignStretch)):
    body

template cardHeader*(ui: var UI; id: string; opts: BoxOpts; body: untyped) =
  ui.panel(id, FilledPanel, opts):
    body

template cardHeader*(ui: var UI; id: string; body: untyped) =
  ui.cardHeader(id, boxOpts(spacing = 4, padding = uniformSides(6), align = AlignStretch)):
    body

template cardBody*(ui: var UI; id: string; opts: BoxOpts; body: untyped) =
  ui.vbox(id, opts):
    body

template cardBody*(ui: var UI; id: string; body: untyped) =
  ui.cardBody(id, boxOpts(spacing = 8, padding = uniformSides(6), align = AlignStretch, expand = true, flex = 1)):
    body

template cardFooter*(ui: var UI; id: string; opts: BoxOpts; body: untyped) =
  ui.panelRow(id, FilledPanel, opts):
    body

template cardFooter*(ui: var UI; id: string; body: untyped) =
  ui.cardFooter(id, boxOpts(spacing = 8, padding = uniformSides(6), align = AlignCenter, justify = SpaceBetween)):
    body

proc box*(ui: var UI; id: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto): string =
  var el = boxElement(id, margin, minSize, prefSize, maxSize, expand, flex)
  el.alignSelf = alignSelf
  el.justifySelf = justifySelf
  let widgetId = ui.addWidget(el, resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc text*(ui: var UI; id: string; value: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto): string =
  let widgetId = ui.addWidget(textElement(id, value, margin, minSize, prefSize, maxSize, expand, flex, alignSelf, justifySelf), resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc button*(ui: var UI; id: string; label: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto): string =
  var el = textElement(id, label, margin, minSize, prefSize, maxSize, expand, flex, alignSelf, justifySelf)
  el.interactivity = ControlElement
  let widgetId = ui.addWidget(el, resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId
