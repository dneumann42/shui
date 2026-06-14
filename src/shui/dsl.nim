import std/[macros, strutils]

proc lowerCamel(name: string): string =
  if name.len == 0:
    return name
  result = name
  result[0] = result[0].toLowerAscii()

proc exported(name: NimNode): NimNode =
  nnkPostfix.newTree(ident"*", name)

proc isSection(node: NimNode; name: string): bool =
  node.kind == nnkCall and node.len == 2 and node[0].kind == nnkIdent and node[0].strVal == name

proc stateField(node: NimNode): NimNode =
  expectKind(node, nnkCall)
  expectLen(node, 2)
  expectKind(node[0], nnkIdent)
  expectKind(node[1], nnkStmtList)
  expectLen(node[1], 1)

  let fieldName = node[0]
  let spec = node[1][0]
  case spec.kind
  of nnkAsgn:
    nnkIdentDefs.newTree(exported(fieldName), spec[0], newEmptyNode())
  else:
    nnkIdentDefs.newTree(exported(fieldName), spec, newEmptyNode())

proc renderTemplate(widgetName, renderNode: NimNode): NimNode =
  expectKind(renderNode, nnkCall)
  expectLen(renderNode, 2)
  expectKind(renderNode[1], nnkStmtList)

  let call = renderNode[0]
  var params = nnkFormalParams.newTree(newEmptyNode())
  params.add nnkIdentDefs.newTree(
    ident"state",
    nnkVarTy.newTree(widgetName),
    newEmptyNode()
  )

  if call.kind == nnkObjConstr:
    expectKind(call[0], nnkIdent)
    if call[0].strVal != "render":
      error("expected render section", call)
    for i in 1 ..< call.len:
      expectKind(call[i], nnkExprColonExpr)
      params.add nnkIdentDefs.newTree(call[i][0], call[i][1], newEmptyNode())
  elif call.kind == nnkIdent and call.strVal == "render":
    discard
  else:
    error("expected render section", call)

  let procName = ident(lowerCamel(widgetName.strVal))
  var renderBody = newStmtList()
  renderBody.add nnkDiscardStmt.newTree(ident"state")
  for stmt in renderNode[1]:
    renderBody.add stmt

  nnkTemplateDef.newTree(
    exported(procName),
    newEmptyNode(),
    newEmptyNode(),
    params,
    nnkPragma.newTree(ident"dirty"),
    newEmptyNode(),
    renderBody
  )

macro widget*(identifier, body: untyped): untyped =
  expectKind(identifier, nnkIdent)
  expectKind(body, nnkStmtList)

  let widgetName = identifier
  var fields = nnkRecList.newTree()
  var renderNode: NimNode = nil

  for section in body:
    if isSection(section, "state"):
      expectKind(section[1], nnkStmtList)
      for field in section[1]:
        fields.add stateField(field)
    elif section.kind == nnkCall:
      let call = section[0]
      if (call.kind == nnkObjConstr and call[0].kind == nnkIdent and call[0].strVal == "render") or
         (call.kind == nnkIdent and call.strVal == "render"):
        renderNode = section
      elif isSection(section, "event") or isSection(section, "handle"):
        discard
      else:
        error("unsupported widget section", section)
    else:
      error("unsupported widget section", section)

  if renderNode.isNil:
    error("widget requires a render section", body)

  result = newStmtList()
  result.add nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      exported(widgetName),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        fields
      )
    )
  )
  result.add renderTemplate(widgetName, renderNode)
