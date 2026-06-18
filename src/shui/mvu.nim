import std/[macros, tables]
import uirelays/[screen, input, coords]
when not defined(shuiHostedOnly):
  import uirelays/backend
import ./[elements, uirelay_runtime]

export uirelay_runtime

type UiEvent* = enum
  Clicked
  Pressed
  Released
  HoverIn
  HoverOut

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
  vparams.add nnkIdentDefs.newTree(ident"sink",
    nnkProcTy.newTree(
      nnkFormalParams.newTree(newEmptyNode(),
        nnkIdentDefs.newTree(ident"id", ident"string", newEmptyNode()),
        nnkIdentDefs.newTree(ident"ev", ident"UiEvent", newEmptyNode()),
        nnkIdentDefs.newTree(ident"m", msgType, newEmptyNode())),
      nnkPragma.newTree(ident"closure")),
    newEmptyNode())
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
  of nnkObjConstr:
    result = newCall(ident(nameOf(message[0])))
    for i in 1 ..< message.len:
      result.add nnkExprEqExpr.newTree(message[i][0], message[i][1])
  else:
    result = message

macro on*(id, event, message: untyped): untyped =
  newCall(ident"sink", id, event, msgCtorExpr(message))

macro emit*(id, message, body: untyped): untyped =
  newStmtList(body, newCall(ident"sink", id, ident"Clicked", msgCtorExpr(message)))

template child*(childState; id: string; wrap): untyped {.dirty.} =
  view(childState, ui, id,
    proc(cid: string; cev: UiEvent; cm: msgTypeFor(typeof(childState))) = sink(cid, cev, wrap(cm)))

template mount*(childState; id: string): untyped {.dirty.} =
  view(childState, ui, id,
    proc(cid: string; cev: UiEvent; cm: msgTypeFor(typeof(childState))) = discard)

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
  var bindings = initTable[(string, UiEvent), msgTypeFor(W)]()
  proc sink(id: string; ev: UiEvent; m: msgTypeFor(W)) = bindings[(id, ev)] = m

  template fire(targetId: string; uiEv: UiEvent) =
    if targetId.len > 0 and (targetId, uiEv) in bindings:
      update(model, bindings[(targetId, uiEv)])

  var running = true
  var hosted = initHostedUiState()
  var pressedId = ""
  var prevHovered = ""
  var scrollMem = initTable[string, (int, int)]()
  while running:
    beginFrame(ui)
    bindings.clear()
    view(model, ui, rootId, sink)
    if font != Font(0):
      ui.ensureTextMeasures(font)
    for vp, off in scrollMem:
      ui.setScrollOffset(vp, off[0], off[1])

    var frame = ui.layoutFrame(rootId, screenLayout.width, screenLayout.height, cfg)

    var ev: Event
    while pollEvent(ev):
      case ev.kind
      of QuitEvent, WindowCloseEvent:
        running = false
      of WindowResizeEvent:
        screenLayout.width = ev.x
        screenLayout.height = ev.y
        frame = ui.layoutFrame(rootId, screenLayout.width, screenLayout.height, cfg)
      else:
        discard
      discard ui.handleEvent(hosted, rootId, cfg, ev, screenLayout.width, screenLayout.height)
      if frame.ok:
        if ev.kind == MouseDownEvent and ev.button == LeftButton:
          let hit = ui.hitTestControlId(rootId, frame.rects, point(ev.x, ev.y))
          pressedId = hit
          fire(hit, Pressed)
        elif ev.kind == MouseUpEvent and ev.button == LeftButton:
          let hit = ui.hitTestControlId(rootId, frame.rects, point(ev.x, ev.y))
          fire(hit, Released)
          if hit.len > 0 and hit == pressedId:
            fire(hit, Clicked)
          pressedId = ""

    if frame.ok and hosted.mouseX >= 0:
      let hov = ui.hitTestControlId(rootId, frame.rects, point(hosted.mouseX, hosted.mouseY))
      if hov != prevHovered:
        fire(prevHovered, HoverOut)
        fire(hov, HoverIn)
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
