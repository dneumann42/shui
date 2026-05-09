import std/[strutils, tables]
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
    visible: true,
    positionMode: FlowPosition,
    anchor: AnchorTopLeft,
    anchorToId: "",
    offsetX: 0,
    offsetY: 0,
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
    visible: true,
    positionMode: FlowPosition,
    anchor: AnchorTopLeft,
    anchorToId: "",
    offsetX: 0,
    offsetY: 0,
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
    visible: true,
    positionMode: FlowPosition,
    anchor: AnchorTopLeft,
    anchorToId: "",
    offsetX: 0,
    offsetY: 0,
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
    visible: true,
    positionMode: FlowPosition,
    anchor: AnchorTopLeft,
    anchorToId: "",
    offsetX: 0,
    offsetY: 0,
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
    visible: true,
    positionMode: FlowPosition,
    anchor: AnchorTopLeft,
    anchorToId: "",
    offsetX: 0,
    offsetY: 0,
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

proc attachAdornment*(ui: var UI; hostId, adornId, text: string; prefSize = size(18, 18); anchor = AnchorTopRight; offsetX = -2; offsetY = 0): string =
  let parentId = ui.parentById.getOrDefault(hostId, "")
  discard ui.text(adornId, text, parentId = parentId, prefSize = prefSize)
  ui.setFloating(adornId, anchor = anchor, anchorToId = hostId, offsetX = offsetX, offsetY = offsetY)
  adornId

proc setAdornmentText*(ui: var UI; adornId, text: string) =
  if adornId notin ui.elements:
    return
  var el = ui.elements[adornId]
  if el.kind != Text:
    return
  el.text = text
  ui.elements[adornId] = el

proc comboBox*(ui: var UI; id: string; items: openArray[string]; selectedIndex = 0; width = 180; itemHeight = 28): string =
  let safeIndex =
    if items.len == 0: -1
    else: max(0, min(selectedIndex, items.len - 1))
  let selectedLabel = if safeIndex >= 0: items[safeIndex] else: ""

  discard ui.addWidget(vboxElement(id, JustifyStart, AlignStretch, 0, zeroSides(), zeroSides(), size(0, 0), size(width, itemHeight), size(0, 0), false, 0), resolveParentId(ui, ""))
  let triggerId = id & ".trigger"
  discard ui.button(triggerId, selectedLabel, parentId = id, prefSize = size(width, itemHeight))
  if triggerId in ui.elements:
    var trigger = ui.elements[triggerId]
    trigger.surfaceStyle = SurfaceBordered
    ui.elements[triggerId] = trigger
  let indicatorId = id & ".indicator"
  discard ui.attachAdornment(triggerId, indicatorId, "v", prefSize = size(20, itemHeight), anchor = AnchorTopRight, offsetX = -4, offsetY = 0)

  let menuId = id & ".menu"
  var menu = vboxElement(menuId, JustifyStart, AlignStretch, 2, uniformSides(4), zeroSides(), size(0, 0), size(width, max(0, items.len * itemHeight + 8)), size(0, 0), false, 0)
  menu.surfaceStyle = SurfaceBordered
  discard ui.addWidget(menu, id)
  ui.setFloating(menuId, anchor = AnchorBottomLeft, anchorToId = triggerId, offsetX = 0, offsetY = 2)
  ui.setVisible(menuId, false)

  for i, item in items:
    let optId = id & ".opt." & $i
    discard ui.button(optId, item, parentId = menuId, prefSize = size(width - 8, itemHeight))

  id

proc comboBoxTriggerId*(id: string): string =
  id & ".trigger"

proc comboBoxMenuId*(id: string): string =
  id & ".menu"

proc comboBoxOptionId*(id: string; index: int): string =
  id & ".opt." & $index

proc comboBoxToggle*(ui: var UI; id: string): bool =
  let menuId = comboBoxMenuId(id)
  if menuId notin ui.elements:
    return false
  let openNow = ui.elements[menuId].visible
  ui.setVisible(menuId, not openNow)
  ui.setAdornmentText(id & ".indicator", if openNow: "v" else: "^")
  true

proc comboBoxSelect*(ui: var UI; id: string; index: int): bool =
  let triggerId = comboBoxTriggerId(id)
  let optionId = comboBoxOptionId(id, index)
  let menuId = comboBoxMenuId(id)
  if triggerId notin ui.elements or optionId notin ui.elements:
    return false
  if ui.elements[triggerId].kind != Text or ui.elements[optionId].kind != Text:
    return false
  var trigger = ui.elements[triggerId]
  trigger.text = ui.elements[optionId].text
  ui.elements[triggerId] = trigger
  if menuId in ui.elements:
    ui.setVisible(menuId, false)
  ui.setAdornmentText(id & ".indicator", "v")
  true

proc comboBoxHandleClick*(ui: var UI; id: string): bool =
  if ui.clickedId.len == 0:
    return false
  let triggerId = id & ".trigger"
  let menuId = id & ".menu"
  if ui.clickedId == triggerId:
    let openNow = ui.elements[menuId].visible
    ui.setVisible(menuId, not openNow)
    return true

  let optionPrefix = id & ".opt."
  if ui.clickedId.startsWith(optionPrefix):
    let selectedId = ui.clickedId
    if selectedId in ui.elements and triggerId in ui.elements:
      let selectedLabel = ui.elements[selectedId].text
      var trigger = ui.elements[triggerId]
      if trigger.kind == Text:
        trigger.text = selectedLabel
        ui.elements[triggerId] = trigger
    ui.setVisible(menuId, false)
    return true
  false
