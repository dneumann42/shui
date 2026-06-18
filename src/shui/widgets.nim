import std/[macros, strutils, tables]
import ./[dsl, elements]

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
    relayLayout*: string

  PanelStyle* = enum
    FilledPanel
    BorderedPanel

  LabelAlign* = enum
    LabelCenter
    LabelLeft
    LabelRight

  AdornProc* = proc(ui: var UI; parentId: string) {.closure.}

proc labelJustify*(a: LabelAlign): Justify =
  case a
  of LabelCenter: JustifyCenter
  of LabelLeft: JustifyStart
  of LabelRight: JustifyEnd

proc boxOpts*(justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; relayLayout = ""): BoxOpts =
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
    relayLayout: relayLayout,
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

proc textElement*(id: string; text: string; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto; textAlign = TextCenter): Element =
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
    textAlign: textAlign,
  )

proc vboxElement*(id: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; relayLayout = ""): Element =
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

proc hboxElement*(id: string; justify = JustifyStart; align = AlignStart; spacing = 0; padding = zeroSides(); margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; relayLayout = ""): Element =
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

template layout*(rootId: string; body: untyped) =
  ui.setRoot(rootId)
  body

proc resolveParentId(ui: UI; parentId: string): string =
  if parentId.len > 0: parentId else: ui.currentBuildParent()

proc applyPanelStyle*(el: var Element; style: PanelStyle) =
  case style
  of FilledPanel:
    el.surfaceStyle = SurfaceFilled
  of BorderedPanel:
    el.surfaceStyle = SurfaceBordered

template vbox*(parentId: string; opts = boxOpts(); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    discard ui.addWidget(vboxElement(parentId, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex, opts.relayLayout), parentResolved)
    ui.pushBuildParent(parentId)
    defer:
      ui.popBuildParent()
    template id(s: string): auto = parentId & "." & s
    body

template hbox*(id: string; opts = boxOpts(); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    discard ui.addWidget(hboxElement(id, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex, opts.relayLayout), parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template relay*(id: string; schema: string; opts = boxOpts(); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    discard ui.addWidget(relayElement(id, schema, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex), parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template panel*(id: string; style: PanelStyle; opts: BoxOpts; body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    var el = vboxElement(id, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex, opts.relayLayout)
    applyPanelStyle(el, style)
    discard ui.addWidget(el, parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template panelRow*(id: string; style: PanelStyle; opts: BoxOpts; body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    var el = hboxElement(id, opts.justify, opts.align, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex, opts.relayLayout)
    applyPanelStyle(el, style)
    discard ui.addWidget(el, parentResolved)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    body

template panel*(id: string; style: PanelStyle; body: untyped) =
  panel(id, style, boxOpts()):
    body

template card*(id: string; style: PanelStyle; opts: BoxOpts; body: untyped) =
  panel(id, style, opts):
    body

template card*(id: string; style: PanelStyle; body: untyped) =
  card(id, style, boxOpts(spacing = 8, padding = uniformSides(12), align = AlignStretch)):
    body

template cardHeader*(id: string; opts: BoxOpts; body: untyped) =
  panel(id, FilledPanel, opts):
    body

template cardHeader*(id: string; body: untyped) =
  cardHeader(id, boxOpts(spacing = 4, padding = uniformSides(6), align = AlignStretch)):
    body

template cardBody*(id: string; opts: BoxOpts; body: untyped) =
  vbox(id, opts):
    body

template cardBody*(id: string; body: untyped) =
  cardBody(id, boxOpts(spacing = 8, padding = uniformSides(6), align = AlignStretch, expand = true, flex = 1)):
    body

template cardFooter*(id: string; opts: BoxOpts; body: untyped) =
  panelRow(id, FilledPanel, opts):
    body

template cardFooter*(id: string; body: untyped) =
  cardFooter(id, boxOpts(spacing = 8, padding = uniformSides(6), align = AlignCenter, justify = SpaceBetween)):
    body

proc boxNode*(ui: var UI; id: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto): string {.discardable.} =
  var el = boxElement(id, margin, minSize, prefSize, maxSize, expand, flex)
  el.alignSelf = alignSelf
  el.justifySelf = justifySelf
  let widgetId = ui.addWidget(el, resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc textLabel*(ui: var UI; id: string; value: string; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto; textAlign = TextCenter): string {.discardable.} =
  let widgetId = ui.addWidget(textElement(id, value, margin, minSize, prefSize, maxSize, expand, flex, alignSelf, justifySelf, textAlign), resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc imageNode*(ui: var UI; id: string; spec: ButtonImageSpec; parentId = ""; measure: IntrinsicMeasureProc = nil; margin = zeroSides(); minSize = size(0, 0); prefSize = size(0, 0); maxSize = size(0, 0); expand = false; flex = 0; alignSelf = SelfAuto; justifySelf = SelfAuto): string {.discardable.} =
  let intrinsic = buttonImageSize(spec)
  let resolvedPrefSize =
    if prefSize.w > 0 or prefSize.h > 0:
      prefSize
    else:
      intrinsic

  var el = Element(
    id: id,
    kind: Image,
    interactivity: StaticElement,
    surfaceStyle: SurfaceAuto,
    visible: true,
    positionMode: FlowPosition,
    anchor: AnchorTopLeft,
    anchorToId: "",
    offsetX: 0,
    offsetY: 0,
    imageSpec: spec,
    margin: margin,
    minSize: minSize,
    prefSize: resolvedPrefSize,
    maxSize: maxSize,
    expand: expand,
    flex: flex,
    alignSelf: alignSelf,
    justifySelf: justifySelf,
  )
  let widgetId = ui.addWidget(el, resolveParentId(ui, parentId))
  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc pushButton*(
  ui: var UI;
  id: string;
  label: string;
  parentId = "";
  selected = false;
  measure: IntrinsicMeasureProc = nil;
  margin = zeroSides();
  minSize = size(0, 0);
  prefSize = size(0, 0);
  maxSize = size(0, 0);
  expand = false;
  flex = 0;
  alignSelf = SelfAuto;
  justifySelf = SelfAuto;
  visible = true;
  positionMode = FlowPosition;
  surfaceStyle = SurfaceAuto;
  anchor = AnchorTopLeft;
  anchorToId = "";
  offsetX = 0;
  offsetY = 0;
  interactivity = ControlElement;
  labelAlign = LabelCenter;
  align = AlignCenter;
  spacing = 6;
  padding = zeroSides();
  relayLayout = "";
  showBackground = true;
  leading: ButtonImageSpec = ButtonImageSpec();
  trailing: ButtonImageSpec = ButtonImageSpec();
  background: ButtonImageSpec = ButtonImageSpec();
  startAdorn: AdornProc = nil;
  endAdorn: AdornProc = nil
): string {.discardable.} =
  let parentResolved = resolveParentId(ui, parentId)
  let resolvedPrefSize =
    if prefSize.w > 0 or prefSize.h > 0:
      prefSize
    elif background.hasButtonImage():
      buttonImageSize(background)
    else:
      prefSize

  var el = hboxElement(id, labelJustify(labelAlign), align, spacing, padding, margin, minSize, resolvedPrefSize, maxSize, expand, flex)
  el.selected = selected
  el.interactivity = interactivity
  el.surfaceStyle = surfaceStyle
  el.visible = visible
  el.positionMode = positionMode
  el.anchor = anchor
  el.anchorToId = anchorToId
  el.offsetX = offsetX
  el.offsetY = offsetY
  el.alignSelf = alignSelf
  el.justifySelf = justifySelf
  el.backgroundImage = background
  el.relayLayout = relayLayout
  el.hideSurface = not showBackground
  let widgetId = ui.addWidget(el, parentResolved)

  if leading.hasButtonImage():
    discard ui.imageNode(id & ".leading", leading, parentId = id, alignSelf = SelfCenter, justifySelf = SelfCenter)
  if startAdorn != nil:
    startAdorn(ui, id)
  if label.len > 0:
    let ta = case labelAlign
      of LabelLeft: TextLeft
      of LabelRight: TextRight
      of LabelCenter: TextCenter
    discard ui.textLabel(id & ".label", label, parentId = id, alignSelf = SelfCenter, justifySelf = SelfCenter,
      expand = true, flex = 1, textAlign = ta)
  if endAdorn != nil:
    endAdorn(ui, id)
  if trailing.hasButtonImage():
    discard ui.imageNode(id & ".trailing", trailing, parentId = id, alignSelf = SelfCenter, justifySelf = SelfCenter)

  if measure != nil:
    ui.setMeasure(widgetId, measure)
  widgetId

proc inputField*(
  ui: var UI;
  id: string;
  text: string;
  placeholder = "";
  parentId = "";
  prefSize = size(220, 32);
  expand = false;
  flex = 0;
  alignSelf = SelfAuto
): string {.discardable.} =
  let parent = resolveParentId(ui, parentId)
  var el = hboxElement(id, JustifyStart, AlignCenter, 0, uniformSides(8), zeroSides(), size(0, 0), prefSize, size(0, 0), expand, flex)
  el.interactivity = ControlElement
  el.surfaceStyle = SurfaceBordered
  el.alignSelf = alignSelf
  discard ui.addWidget(el, parent)
  let shown = if text.len > 0: text else: placeholder
  discard ui.textLabel(id & ".text", shown, parentId = id, alignSelf = SelfCenter, expand = true, flex = 1, textAlign = TextLeft)
  id

type
  NotificationToast* = object
    id*: int
    message*: string
    remainingSeconds*: float

proc notificationWidth*(width: int): int =
  if width > 0: width else: 320

proc notificationItemHeight*(height: int): int =
  if height > 0: height else: 40

proc notificationSpacing*(spacing: int): int =
  if spacing > 0: spacing else: 8

proc notificationMargin*(margin: int): int =
  if margin > 0: margin else: 16

proc notificationDuration*(durationSeconds: float): float =
  if durationSeconds > 0: durationSeconds else: 3.0

renderWidget NotificationStack:
  state:
    notifications: seq[NotificationToast] = @[]
    nextId: int = 0
    width: int = 320
    itemHeight: int = 40
    spacing: int = 8
    margin: int = 16

  render(rootId: string):
    if state.notifications.len > 0:
      let stackWidth = notificationWidth(state.width)
      let toastHeight = notificationItemHeight(state.itemHeight)
      let stackSpacing = notificationSpacing(state.spacing)
      let stackMargin = notificationMargin(state.margin)

      vbox(rootId, boxOpts(align = AlignStretch, spacing = stackSpacing, prefSize = size(stackWidth, 0))):
        for item in state.notifications:
          let itemId = rootId & ".item." & $item.id
          panel(itemId, FilledPanel, boxOpts(align = AlignStretch, padding = uniformSides(8), prefSize = size(stackWidth, toastHeight))):
            discard ui.textLabel(itemId & ".message", item.message, prefSize = size(max(0, stackWidth - 16), max(0, toastHeight - 16)), alignSelf = SelfStretch)

      ui.setFloating(rootId, anchor = AnchorBottomRight, anchorToId = "", offsetX = -stackMargin, offsetY = -stackMargin)

template notificationStack*(state: var NotificationStack) =
  notificationStack(state, "notifications")

proc pushNotification*(state: var NotificationStack; message: string; durationSeconds = 3.0) =
  state.notifications.add NotificationToast(
    id: state.nextId,
    message: message,
    remainingSeconds: notificationDuration(durationSeconds),
  )
  inc state.nextId

proc updateNotifications*(state: var NotificationStack; deltaSeconds: float) =
  if state.notifications.len == 0:
    return

  var kept: seq[NotificationToast] = @[]
  for item in state.notifications:
    var next = item
    next.remainingSeconds -= deltaSeconds
    if next.remainingSeconds > 0:
      kept.add next
  state.notifications = kept

proc attachAdornment*(ui: var UI; hostId, adornId, text: string; prefSize = size(18, 18); anchor = AnchorTopRight; offsetX = -2; offsetY = 0): string =
  let parentId = ui.parentById.getOrDefault(hostId, "")
  discard ui.textLabel(adornId, text, parentId = parentId, prefSize = prefSize)
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

proc comboBox*(ui: var UI; id: string; items: openArray[string]; selectedIndex = 0; width = 180; itemHeight = 28): string {.discardable.} =
  let safeIndex =
    if items.len == 0: -1
    else: max(0, min(selectedIndex, items.len - 1))
  let selectedLabel = if safeIndex >= 0: items[safeIndex] else: ""

  discard ui.addWidget(vboxElement(
    id, JustifyStart, AlignStretch, 0, zeroSides(), zeroSides(), size(0, 0), size(width, itemHeight), size(0, 0), false, 0), resolveParentId(ui, ""))
  let triggerId = id & ".trigger"
  discard ui.pushButton(triggerId, selectedLabel, parentId = id, prefSize = size(width, itemHeight))

  # if ui.clicked triggerId:
  #   echo "CLICKED!"
  
  if triggerId in ui.elements:
    var trigger = ui.elements[triggerId]
    trigger.surfaceStyle = SurfaceBordered
    ui.elements[triggerId] = trigger
  let indicatorId = id & ".indicator"
  discard ui.attachAdornment(triggerId, indicatorId, "v", prefSize = size(20, itemHeight), anchor = AnchorTopRight, offsetX = -4, offsetY = 0)

  let menuId = id & ".menu"
  var menu = vboxElement(
    menuId, JustifyStart, AlignStretch, 2, uniformSides(4), zeroSides(), size(0, 0), size(width, max(0, items.len * itemHeight + 8)), size(0, 0), false, 0)
  menu.surfaceStyle = SurfaceBordered
  discard ui.addWidget(menu, id)
  ui.setFloating(menuId, anchor = AnchorTopLeft, anchorToId = triggerId, offsetX = 0, offsetY = itemHeight + 2)
  ui.setVisible(menuId, false)

  for i, item in items:
    let optId = id & ".opt." & $i
    discard ui.pushButton(optId, item, parentId = menuId, prefSize = size(width - 8, itemHeight))

  id

proc comboBoxTriggerId*(id: string): string =
  id & ".trigger"

proc comboBoxMenuId*(id: string): string =
  id & ".menu"

proc comboBoxOptionId*(id: string; index: int): string =
  id & ".opt." & $index

proc buttonLabelId(id: string): string =
  id & ".label"

proc elementText(ui: UI; id: string): string =
  if id in ui.elements and ui.elements[id].kind == Text:
    ui.elements[id].text
  else:
    ""

proc setElementText(ui: var UI; id, value: string): bool =
  if id notin ui.elements or ui.elements[id].kind != Text:
    return false
  var el = ui.elements[id]
  el.text = value
  ui.elements[id] = el
  true

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
  let selectedLabel = ui.elementText(buttonLabelId(optionId))
  if selectedLabel.len == 0:
    return false
  discard ui.setElementText(buttonLabelId(triggerId), selectedLabel)
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
    ui.setAdornmentText(id & ".indicator", if openNow: "v" else: "^")
    return true

  let optionPrefix = id & ".opt."
  if ui.clickedId.startsWith(optionPrefix):
    let selectedId = ui.clickedId
    if selectedId in ui.elements and triggerId in ui.elements:
      let selectedLabel = ui.elementText(buttonLabelId(selectedId))
      discard ui.setElementText(buttonLabelId(triggerId), selectedLabel)
    ui.setVisible(menuId, false)
    ui.setAdornmentText(id & ".indicator", "v")
    return true
  false

proc scrollContentId*(id: string): string =
  id & ".content"

template scrollV*(id: string; viewportOpts = boxOpts(); contentOpts = boxOpts(spacing = 4, align = AlignStretch); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    var viewport = vboxElement(id, viewportOpts.justify, viewportOpts.align, viewportOpts.spacing, viewportOpts.padding, viewportOpts.margin, viewportOpts.minSize, viewportOpts.prefSize, viewportOpts.maxSize, viewportOpts.expand, viewportOpts.flex)
    viewport.alignSelf = SelfStretch
    discard ui.addWidget(viewport, parentResolved)
    let contentId = scrollContentId(id)
    discard ui.addWidget(vboxElement(contentId, contentOpts.justify, contentOpts.align, contentOpts.spacing, contentOpts.padding, contentOpts.margin, contentOpts.minSize, contentOpts.prefSize, contentOpts.maxSize, contentOpts.expand, contentOpts.flex), id)
    ui.setFloating(contentId, anchor = AnchorTopLeft, anchorToId = id, offsetX = 0, offsetY = 0)
    ui.registerScroll(id, contentId, enableX = false, enableY = true)
    ui.pushBuildParent(contentId)
    defer:
      ui.popBuildParent()
    body

template scrollH*(id: string; viewportOpts = boxOpts(); contentOpts = boxOpts(spacing = 4, align = AlignStretch); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    var viewport = hboxElement(id, viewportOpts.justify, viewportOpts.align, viewportOpts.spacing, viewportOpts.padding, viewportOpts.margin, viewportOpts.minSize, viewportOpts.prefSize, viewportOpts.maxSize, viewportOpts.expand, viewportOpts.flex)
    viewport.alignSelf = SelfStretch
    discard ui.addWidget(viewport, parentResolved)
    let contentId = scrollContentId(id)
    discard ui.addWidget(hboxElement(contentId, contentOpts.justify, contentOpts.align, contentOpts.spacing, contentOpts.padding, contentOpts.margin, contentOpts.minSize, contentOpts.prefSize, contentOpts.maxSize, contentOpts.expand, contentOpts.flex), id)
    ui.setFloating(contentId, anchor = AnchorTopLeft, anchorToId = id, offsetX = 0, offsetY = 0)
    ui.registerScroll(id, contentId, enableX = true, enableY = false)
    ui.pushBuildParent(contentId)
    defer:
      ui.popBuildParent()
    body

proc dialogCloseId*(id: string): string =
  id & ".close"

proc showDialog*(ui: var UI; id: string) =
  ui.openDialog(id)

proc hideDialog*(ui: var UI; id: string) =
  ui.closeDialog(id)

template dialogHeader*(id: string; opts = boxOpts(justify = SpaceBetween, align = AlignCenter, spacing = 8, padding = uniformSides(8)); body: untyped) =
  panelRow(id, FilledPanel, opts):
    body

template dialogHeader*(id: string; body: untyped) =
  dialogHeader(id, boxOpts(justify = SpaceBetween, align = AlignStretch, spacing = 8, padding = uniformSides(8))):
    body

template dialogBody*(id: string; opts = boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch, expand = true, flex = 1); body: untyped) =
  vbox(id, opts):
    body

template dialogBody*(id: string; body: untyped) =
  dialogBody(id, boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch, expand = true, flex = 1)):
    body

template dialogFooter*(id: string; opts = boxOpts(justify = SpaceBetween, align = AlignCenter, spacing = 8, padding = uniformSides(8)); body: untyped) =
  panelRow(id, FilledPanel, opts):
    body

template dialogFooter*(id: string; body: untyped) =
  dialogFooter(id, boxOpts(justify = SpaceBetween, align = AlignCenter, spacing = 8, padding = uniformSides(8))):
    body

template dialog*(id: string; title = ""; showHeader = true; showClose = true; opts = boxOpts(spacing = 8, padding = uniformSides(8), align = AlignStretch, prefSize = size(520, 320)); body: untyped) =
  block:
    let parentResolved = ui.currentBuildParent()
    var root = vboxElement(id, opts.justify, AlignStretch, opts.spacing, opts.padding, opts.margin, opts.minSize, opts.prefSize, opts.maxSize, opts.expand, opts.flex)
    root.surfaceStyle = SurfaceBordered
    discard ui.addWidget(root, parentResolved)
    ui.setFloating(id, anchor = AnchorCenter, anchorToId = "", offsetX = 0, offsetY = 0)
    ui.setVisible(id, false)
    ui.pushBuildParent(id)
    defer:
      ui.popBuildParent()
    if showHeader:
      dialogHeader(id & ".header", boxOpts(justify = SpaceBetween, spacing = 4, padding = uniformSides(8), align = AlignStretch)):
        if title.len > 0:
          discard ui.textLabel(id & ".title", title, prefSize = size(260, 28), alignSelf = SelfStart)
        else:
          discard ui.boxNode(id & ".title.spacer", prefSize = size(10, 28), expand = true, flex = 1)
        if showClose:
          discard ui.pushButton(dialogCloseId(id), "X", prefSize = size(84, 28))
    dialogBody(id & ".body"):
      body
