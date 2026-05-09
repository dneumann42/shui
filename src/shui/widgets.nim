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
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
  )

proc textElement*(id: string; text: string; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: Text,
    text: text,
    margin: margin,
    minSize: minSize,
    prefSize: prefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
  )

proc vboxElement*(id: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: VBox,
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
  )

proc hboxElement*(id: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: HBox,
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
  )

proc relayElement*(id: string; relayLayout: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): Element =
  Element(
    id: id,
    kind: RelayContainer,
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

proc box*(ui: var UI; id: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): string =
  let widgetId = ui.addWidget(boxElement(id, margin, minSize, prefSize, maxSize, expand, flex), resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc text*(ui: var UI; id: string; value: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): string =
  let widgetId = ui.addWidget(textElement(id, value, margin, minSize, prefSize, maxSize, expand, flex), resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId
