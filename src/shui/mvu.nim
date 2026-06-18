import std/[macros, tables]
import uirelays/[screen, input, coords]
when not defined(shuiHostedOnly):
  import uirelays/backend
import ./[elements, uirelay_runtime]

export uirelay_runtime
export input
export tables

type UiEvent* = enum
  Clicked
  Pressed
  Released
  HoverIn
  HoverOut

type Dispatcher*[M] = object
  event*: proc(id: string; ev: UiEvent; m: M) {.closure.}
  text*: proc(id: string; make: proc(ch: string): M {.closure.}) {.closure.}
  key*: proc(id: string; code: KeyCode; m: M) {.closure.}

proc exported(name: NimNode): NimNode =
  nnkPostfix.newTree(ident"*", name)

proc stateField(node: NimNode): NimNode =
  expectKind(node, nnkCall)
  expectLen(node, 2)
  expectKind(node[0], nnkIdent)
  let fieldName = node[0]
  let spec = node[1][0]
  case spec.kind
  of nnkAsgn:
    nnkIdentDefs.newTree(exported(fieldName), spec[0], spec[1])
  else:
    nnkIdentDefs.newTree(exported(fieldName), spec, newEmptyNode())

proc rewriteMsgRefs(n: NimNode): NimNode =
  if n.kind == nnkDotExpr and n.len == 2 and n[0].kind == nnkIdent and
     n[1].kind == nnkIdent and n[1].strVal == "Msg":
    return ident(n[0].strVal & "Msg")
  result = copyNimNode(n)
  for c in n:
    result.add rewriteMsgRefs(c)

proc lowerFirst(s: string): string =
  result = s
  if result.len > 0 and result[0] in {'A'..'Z'}:
    result[0] = chr(ord(result[0]) + 32)

proc rewriteFieldAccess(n, param: NimNode; umap: Table[string, string]): NimNode =
  if n.kind == nnkDotExpr and n.len == 2 and
     n[0].kind in {nnkIdent, nnkSym} and n[0].strVal == param.strVal and
     n[1].kind == nnkIdent and umap.hasKey(n[1].strVal):
    return newDotExpr(n[0], ident(umap[n[1].strVal]))
  result = copyNimNode(n)
  for c in n:
    result.add rewriteFieldAccess(c, param, umap)

proc rewriteUpdate(body, param: NimNode; kindMaps: Table[string, Table[string, string]]): NimNode =
  result = copyNimNode(body)
  for c in body:
    result.add rewriteUpdate(c, param, kindMaps)
  if result.kind == nnkCaseStmt and result.len > 0 and
     result[0].kind == nnkIdent and result[0].strVal == param.strVal:
    result[0] = newDotExpr(ident(param.strVal), ident"kind")
    for bi in 1 ..< result.len:
      let br = result[bi]
      if br.kind == nnkOfBranch:
        var umap = initTable[string, string]()
        for ki in 0 ..< br.len - 1:
          let kn = br[ki]
          if kn.kind in {nnkIdent, nnkSym} and kindMaps.hasKey(kn.strVal):
            for u, uq in kindMaps[kn.strVal]:
              umap[u] = uq
        if umap.len > 0:
          br[^1] = rewriteFieldAccess(br[^1], param, umap)

macro component*(identifier, body: untyped): untyped =
  expectKind(identifier, nnkIdent)
  expectKind(body, nnkStmtList)
  let
    name = identifier.strVal
    wType = identifier
    msgType = ident(name & "Msg")
    kindType = ident(name & "MsgKind")

  var
    stateFields = nnkRecList.newTree()
    variants: seq[tuple[kind: NimNode, fields: seq[tuple[user, uniq, typ: NimNode]]]] = @[]
    kindMaps = initTable[string, Table[string, string]]()
    updateParam: NimNode = nil
    updateBody: NimNode = nil
    viewParams: seq[NimNode] = @[]
    viewBody: NimNode = nil

  for section in body:
    expectKind(section, nnkCall)
    let head = section[0]
    let secBody = section[^1]
    if head.kind == nnkIdent and head.strVal == "state":
      for f in secBody:
        stateFields.add stateField(f)
    elif head.kind == nnkIdent and head.strVal == "msg":
      for v in secBody:
        var kindNode: NimNode
        var flds: seq[tuple[user, uniq, typ: NimNode]] = @[]
        if v.kind == nnkIdent:
          kindNode = v
        elif v.kind in {nnkObjConstr, nnkCall}:
          kindNode = v[0]
          for i in 1 ..< v.len:
            expectKind(v[i], nnkExprColonExpr)
            let uname = v[i][0]
            flds.add (uname, ident(lowerFirst(kindNode.strVal) & "_" & uname.strVal), rewriteMsgRefs(v[i][1]))
        else:
          error("unsupported msg variant", v)
        var mp = initTable[string, string]()
        for f in flds:
          mp[f.user.strVal] = f.uniq.strVal
        kindMaps[kindNode.strVal] = mp
        variants.add (kindNode, flds)
    elif head.kind == nnkObjConstr and head[0].strVal == "update":
      updateParam = head[1]
      updateBody = secBody
    elif head.kind == nnkObjConstr and head[0].strVal == "view":
      for i in 1 ..< head.len:
        viewParams.add head[i]
      viewBody = secBody
    elif head.kind == nnkIdent and head.strVal == "view":
      viewBody = secBody
    else:
      error("unsupported component section", section)

  if viewBody.isNil:
    error("component requires a view section", body)
  if variants.len == 0:
    variants.add (ident(name & "Idle"), newSeq[tuple[user, uniq, typ: NimNode]]())

  var enumTy = nnkEnumTy.newTree(newEmptyNode())
  for v in variants:
    enumTy.add v.kind

  var recCase = nnkRecCase.newTree(
    nnkIdentDefs.newTree(exported(ident"kind"), kindType, newEmptyNode()))
  for v in variants:
    var rl = nnkRecList.newTree()
    for f in v.fields:
      rl.add nnkIdentDefs.newTree(exported(f.uniq), copyNimTree(f.typ), newEmptyNode())
    recCase.add nnkOfBranch.newTree(v.kind, rl)

  let objTy = nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(),
    nnkRecList.newTree(recCase))

  result = newStmtList()
  result.add nnkTypeSection.newTree(
    nnkTypeDef.newTree(exported(kindType), newEmptyNode(), enumTy),
    nnkTypeDef.newTree(exported(wType), newEmptyNode(),
      nnkObjectTy.newTree(newEmptyNode(), newEmptyNode(), stateFields)),
    nnkTypeDef.newTree(exported(msgType), newEmptyNode(), objTy))

  for v in variants:
    var params = nnkFormalParams.newTree(msgType)
    var objc = nnkObjConstr.newTree(msgType,
      nnkExprColonExpr.newTree(ident"kind", v.kind))
    for f in v.fields:
      params.add nnkIdentDefs.newTree(f.user, copyNimTree(f.typ), newEmptyNode())
      objc.add nnkExprColonExpr.newTree(f.uniq, f.user)
    result.add nnkProcDef.newTree(
      exported(v.kind), newEmptyNode(), newEmptyNode(), params,
      newEmptyNode(), newEmptyNode(), newStmtList(objc))

  result.add nnkTemplateDef.newTree(
    exported(ident"msgTypeFor"), newEmptyNode(), newEmptyNode(),
    nnkFormalParams.newTree(ident"typedesc",
      nnkIdentDefs.newTree(ident"t",
        nnkBracketExpr.newTree(ident"typedesc", wType), newEmptyNode())),
    newEmptyNode(), newEmptyNode(), newStmtList(msgType))

  let pname = if updateParam != nil: updateParam[0] else: ident"msg"
  let ubody =
    if updateBody != nil: rewriteUpdate(updateBody, pname, kindMaps)
    else: newStmtList(nnkDiscardStmt.newTree(ident"state"), nnkDiscardStmt.newTree(pname))
  result.add nnkProcDef.newTree(
    exported(ident"update"), newEmptyNode(), newEmptyNode(),
    nnkFormalParams.newTree(newEmptyNode(),
      nnkIdentDefs.newTree(ident"state", nnkVarTy.newTree(wType), newEmptyNode()),
      nnkIdentDefs.newTree(pname, msgType, newEmptyNode())),
    newEmptyNode(), newEmptyNode(), ubody)

  var vparams = nnkFormalParams.newTree(newEmptyNode(),
    nnkIdentDefs.newTree(ident"state", nnkVarTy.newTree(wType), newEmptyNode()),
    nnkIdentDefs.newTree(ident"ui", nnkVarTy.newTree(ident"UI"), newEmptyNode()))
  for vp in viewParams:
    vparams.add nnkIdentDefs.newTree(vp[0], vp[1], newEmptyNode())
  vparams.add nnkIdentDefs.newTree(ident"disp",
    nnkBracketExpr.newTree(ident"Dispatcher", msgType), newEmptyNode())
  result.add nnkProcDef.newTree(
    exported(ident"view"), newEmptyNode(), newEmptyNode(), vparams,
    newEmptyNode(), newEmptyNode(), viewBody)

proc nameOf(n: NimNode): string =
  case n.kind
  of nnkIdent, nnkSym: n.strVal
  of nnkOpenSymChoice, nnkClosedSymChoice, nnkAccQuoted: n[0].strVal
  else: ""

proc msgCtorExpr(message: NimNode): NimNode =
  case message.kind
  of nnkIdent, nnkSym, nnkOpenSymChoice, nnkClosedSymChoice, nnkAccQuoted:
    result = newCall(ident(nameOf(message)))
  of nnkObjConstr, nnkCall, nnkCommand:
    result = newCall(ident(nameOf(message[0])))
    for i in 1 ..< message.len:
      let a = message[i]
      if a.kind == nnkExprColonExpr:
        result.add nnkExprEqExpr.newTree(a[0], a[1])
      else:
        result.add a
  else:
    result = message

macro on*(id, event, message: untyped): untyped =
  newCall(newDotExpr(ident"disp", ident"event"), id, event, msgCtorExpr(message))

macro emit*(id, message, body: untyped): untyped =
  newStmtList(body, newCall(newDotExpr(ident"disp", ident"event"), id, ident"Clicked", msgCtorExpr(message)))

macro onKey*(id, code, message: untyped): untyped =
  newCall(newDotExpr(ident"disp", ident"key"), id, code, msgCtorExpr(message))

template onText*(id; make): untyped {.dirty.} =
  disp.text(id, proc(ch: string): msgTypeFor(typeof(state)) = make(ch))

template child*(childState; id: string; wrap): untyped {.dirty.} =
  view(childState, ui, id, Dispatcher[msgTypeFor(typeof(childState))](
    event: proc(cid: string; cev: UiEvent; cm: msgTypeFor(typeof(childState))) = disp.event(cid, cev, wrap(cm)),
    text: proc(cid: string; make: proc(ch: string): msgTypeFor(typeof(childState))) =
      disp.text(cid, proc(ch: string): msgTypeFor(typeof(state)) = wrap(make(ch))),
    key: proc(cid: string; code: KeyCode; cm: msgTypeFor(typeof(childState))) = disp.key(cid, code, wrap(cm))))

template mount*(childState; id: string): untyped {.dirty.} =
  view(childState, ui, id, Dispatcher[msgTypeFor(typeof(childState))](
    event: proc(cid: string; cev: UiEvent; cm: msgTypeFor(typeof(childState))) = discard,
    text: proc(cid: string; make: proc(ch: string): msgTypeFor(typeof(childState))) = discard,
    key: proc(cid: string; code: KeyCode; cm: msgTypeFor(typeof(childState))) = discard))

proc scrolledViewportAt(ui: UI; rects: Table[string, Rect]; p: Point): string =
  var bestArea = high(int)
  for vp, s in ui.scrollByViewport:
    if not s.enableY:
      continue
    if vp in rects and rects[vp].contains(p):
      let a = rects[vp].w * rects[vp].h
      if a < bestArea:
        bestArea = a
        result = vp

proc runProgram*[W](model: var W; rootId: string; cfg = defaultRuntimeConfig()) =
  mixin msgTypeFor, view, update
  when defined(shuiHostedOnly):
    raise newException(CatchableError, "runProgram is unavailable when compiled with -d:shuiHostedOnly")
  else:
    initBackend()

  var screenLayout = createWindow(cfg.width, cfg.height)
  setWindowTitle(cfg.title)

  var font = Font(0)
  var metrics: FontMetrics
  let fontPath = findFontPath(cfg.fontPath)
  if fontPath.len > 0:
    font = openFont(fontPath, cfg.fontSize, metrics)
  else:
    echo "[shui] no usable font found; set cfg.fontPath or SHUI_FONT_PATH for text rendering"

  var ui = initUi()
  type MsgT = msgTypeFor(W)
  var eventBindings = initTable[(string, UiEvent), MsgT]()
  var textBindings = initTable[string, proc(ch: string): MsgT {.closure.}]()
  var keyBindings = initTable[(string, KeyCode), MsgT]()
  let disp = Dispatcher[MsgT](
    event: proc(id: string; ev: UiEvent; m: MsgT) = eventBindings[(id, ev)] = m,
    text: proc(id: string; make: proc(ch: string): MsgT {.closure.}) = textBindings[id] = make,
    key: proc(id: string; code: KeyCode; m: MsgT) = keyBindings[(id, code)] = m)

  var running = true
  var hosted = initHostedUiState()
  var pressedId = ""
  var prevHovered = ""
  var focusedId = ""
  var scrollMem = initTable[string, (int, int)]()
  while running:
    beginFrame(ui)
    eventBindings.clear()
    textBindings.clear()
    keyBindings.clear()
    view(model, ui, rootId, disp)
    if font != Font(0):
      ui.ensureTextMeasures(font)
    for vp, off in scrollMem:
      ui.setScrollOffset(vp, off[0], off[1])
      if vp in ui.scrollByViewport:
        ui.setFloating(ui.scrollByViewport[vp].contentId, anchor = AnchorTopLeft, anchorToId = vp, offsetX = -off[0], offsetY = -off[1])

    var frame = ui.layoutFrame(rootId, screenLayout.width, screenLayout.height, cfg)

    if focusedId.len > 0 and focusedId notin textBindings:
      focusedId = ""
    let flags = if focusedId.len > 0: {WantTextInput} else: {}

    var ev: Event
    while pollEvent(ev, flags):
      case ev.kind
      of QuitEvent, WindowCloseEvent:
        running = false
      of WindowResizeEvent:
        screenLayout.width = ev.x
        screenLayout.height = ev.y
        frame = ui.layoutFrame(rootId, screenLayout.width, screenLayout.height, cfg)
      of MouseWheelEvent:
        if frame.ok:
          let vp = scrolledViewportAt(ui, frame.rects, point(hosted.mouseX, hosted.mouseY))
          if vp.len > 0 and vp in ui.scrollByViewport:
            var s = ui.scrollByViewport[vp]
            s.offsetY = max(0, s.offsetY - ev.y * 40)
            ui.scrollByViewport[vp] = s
      else:
        discard
      discard ui.handleEvent(hosted, rootId, cfg, ev, screenLayout.width, screenLayout.height)
      if frame.ok:
        if ev.kind == MouseDownEvent and ev.button == LeftButton:
          let hit = ui.hitTestControlId(rootId, frame.rects, point(ev.x, ev.y))
          pressedId = hit
          focusedId = if hit in textBindings: hit else: ""
          if hit.len > 0 and (hit, Pressed) in eventBindings:
            update(model, eventBindings[(hit, Pressed)])
        elif ev.kind == MouseUpEvent and ev.button == LeftButton:
          let hit = ui.hitTestControlId(rootId, frame.rects, point(ev.x, ev.y))
          if hit.len > 0 and (hit, Released) in eventBindings:
            update(model, eventBindings[(hit, Released)])
          if hit.len > 0 and hit == pressedId and (hit, Clicked) in eventBindings:
            update(model, eventBindings[(hit, Clicked)])
          pressedId = ""
        elif ev.kind == TextInputEvent and focusedId in textBindings:
          var ch = ""
          for c in ev.text:
            if c != '\0': ch.add c
          if ch.len > 0:
            update(model, textBindings[focusedId](ch))
        elif ev.kind == KeyDownEvent and (focusedId, ev.key) in keyBindings:
          update(model, keyBindings[(focusedId, ev.key)])

    if frame.ok and hosted.mouseX >= 0:
      let hov = ui.hitTestControlId(rootId, frame.rects, point(hosted.mouseX, hosted.mouseY))
      if hov != prevHovered:
        if prevHovered.len > 0 and (prevHovered, HoverOut) in eventBindings:
          update(model, eventBindings[(prevHovered, HoverOut)])
        if hov.len > 0 and (hov, HoverIn) in eventBindings:
          update(model, eventBindings[(hov, HoverIn)])
        prevHovered = hov

    scrollMem.clear()
    for vp, st in ui.scrollByViewport:
      scrollMem[vp] = (st.offsetX, st.offsetY)

    if frame.ok:
      ui.updateHovered(hosted, rootId, frame)
      ui.drawFrame(rootId, frame, cfg, font, screenLayout.width, screenLayout.height)
      refresh()

    if cfg.targetFps > 0:
      input.sleep(1000 div cfg.targetFps)

  if font != Font(0):
    closeFont(font)
  shutdown()
