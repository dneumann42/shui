import ./elements

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

proc vbox*(ui: var UI; id: string; parentId = ""; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): string =
  ui.addWidget(vboxElement(id, justify, align, spacing, padding, margin, minSize, prefSize, maxSize, expand, flex), parentId)

proc hbox*(ui: var UI; id: string; parentId = ""; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): string =
  ui.addWidget(hboxElement(id, justify, align, spacing, padding, margin, minSize, prefSize, maxSize, expand, flex), parentId)

proc box*(ui: var UI; id: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): string =
  let widgetId = ui.addWidget(boxElement(id, margin, minSize, prefSize, maxSize, expand, flex), parentId)
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc text*(ui: var UI; id: string; value: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0): string =
  let widgetId = ui.addWidget(textElement(id, value, margin, minSize, prefSize, maxSize, expand, flex), parentId)
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId
