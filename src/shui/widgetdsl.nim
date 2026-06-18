import std/macros

proc buildWidget*(backing, contentParam: string; content, body: NimNode): NimNode =
  let stmts = if body == nil: newStmtList() else: body
  var namedArgs: seq[(string, NimNode)] = @[]
  var bindings: seq[NimNode] = @[]
  var extras: seq[NimNode] = @[]
  var keyNode: NimNode = nil
  for st in stmts:
    if st.kind == nnkAsgn and st[0].kind == nnkIdent:
      if st[0].strVal == "key":
        keyNode = st[1]
      else:
        namedArgs.add (st[0].strVal, st[1])
    elif st.kind in {nnkCall, nnkCommand} and st.len >= 1 and
         st[0].kind == nnkIdent and st[0].strVal in ["on", "onText", "onKey"]:
      bindings.add st
    else:
      extras.add st

  let locNode = if content != nil: content else: stmts
  let li = locNode.lineInfoObj
  let loc = "@" & $li.line & ":" & $li.column

  let wid = genSym(nskLet, "wid")
  var idExpr = infix(ident"rootId", "&", newLit(loc))
  if keyNode != nil:
    idExpr = infix(idExpr, "&", newLit("#"))
    idExpr = infix(idExpr, "&", newCall(ident"$", keyNode))

  result = newStmtList()
  result.add newLetStmt(wid, idExpr)

  var call = newCall(newDotExpr(ident"ui", ident(backing)), wid)
  if content != nil and contentParam.len > 0:
    call.add nnkExprEqExpr.newTree(ident(contentParam), content)
  for (n, v) in namedArgs:
    call.add nnkExprEqExpr.newTree(ident(n), v)
  result.add call

  for b in bindings:
    var nb = newCall(b[0], wid)
    for i in 1 ..< b.len:
      nb.add b[i]
    result.add nb

  for e in extras:
    result.add e

macro defWidget*(wrapper, backing, contentParam: untyped): untyped =
  let bl = newLit(backing.strVal)
  let cl = newLit(contentParam.strVal)
  result = quote do:
    macro `wrapper`*(content, body: untyped): untyped =
      buildWidget(`bl`, `cl`, content, body)
    macro `wrapper`*(content: untyped): untyped =
      buildWidget(`bl`, `cl`, content, nil)

macro text*(content, body: untyped): untyped = buildWidget("textLabel", "value", content, body)
macro text*(content: untyped): untyped = buildWidget("textLabel", "value", content, nil)

macro button*(content, body: untyped): untyped = buildWidget("pushButton", "label", content, body)
macro button*(content: untyped): untyped = buildWidget("pushButton", "label", content, nil)

macro input*(content, body: untyped): untyped = buildWidget("inputField", "text", content, body)
macro input*(content: untyped): untyped = buildWidget("inputField", "text", content, nil)

macro image*(content, body: untyped): untyped = buildWidget("imageNode", "spec", content, body)
macro image*(content: untyped): untyped = buildWidget("imageNode", "spec", content, nil)

macro box*(body: untyped): untyped = buildWidget("boxNode", "", nil, body)
