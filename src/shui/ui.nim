import widgets, containers, macros, strutils, macrocache

# Store the Painter type at compile time using macrocache
const painterTypeKey = "shuiPainterType"
const painterTypeCache = CacheTable(painterTypeKey)

macro setPainterType*(painterType: typed) =
  ## Call this from your app to set the Painter type at compile time
  ## Example: setPainterType(Drawing)
  painterTypeCache[painterTypeKey] = painterType
  result = newEmptyNode()

proc getPainterType(): NimNode =
  ## Get the cached Painter type, or use a default placeholder
  if painterTypeCache.hasKey(painterTypeKey):
    result = painterTypeCache[painterTypeKey]
  else:
    # Default to a generic ref object if not set
    result = ident("RootObj")

type
  DrawProc* = proc(widget: Widget, painter: pointer) {.closure.}

  AbstractComponentState = ref object of RootObj
  ComponentState*[T] = ref object of AbstractComponentState
    state*: T
  Component* = ref object of Widget
    abstractState*: AbstractComponentState
    drawProc*: DrawProc

proc childStmts*(blk: NimNode): NimNode =
  result = nnkStmtList.newTree()
  for child in blk:
    # Skip discard statements and empty nodes
    if child.kind == nnkDiscardStmt or child.kind == nnkEmpty:
      continue

    result.add(
      quote do:
        let childWidget = block:
          `child`
        if parent of Container:
          Container(parent).add(childWidget)
    )

macro doContainer(init, blk: untyped): untyped =
  quote do:
    block:
      var parent {.inject.} = `init`
      `blk`
      parent

proc buildContainerMacro(containerName: string, params: NimNode): NimNode =
  ## Helper to build container macros (row/column) with optional parameters
  let blk = params[^1]

  # Build the container constructor call with parameters (if any)
  var initCall = newCall(ident(containerName))
  if params.len > 1:
    # Has parameters before the block
    for i in 0 ..< params.len - 1:
      initCall.add(params[i])

  var stmts = blk.childStmts()
  result = quote do:
    doContainer(`initCall`, `stmts`)

macro row*(params: varargs[untyped]): untyped =
  buildContainerMacro("Row", params)

macro column*(params: varargs[untyped]): untyped =
  buildContainerMacro("Column", params)

template renderWidget*(widget: Widget, painter: untyped) =
  ## Recursively render a widget tree with the given painter
  ## Automatically calls draw() on all components and descends into containers
  proc renderImpl(w: Widget, p: pointer) {.gcSafe.} =
    # Call draw callback on components
    if w of Component:
      let comp = Component(w)
      if not comp.drawProc.isNil:
        {.cast(gcSafe).}:
          comp.drawProc(w, p)

      # Recurse into component children if they exist
      when compiles(comp.children):
        for child in comp.children:
          renderImpl(child, p)

    # Recurse into containers
    if w of Container:
      for child in Container(w).children:
        renderImpl(child, p)

  var painterPtr = cast[pointer](painter)
  renderImpl(widget, painterPtr)

macro component*(id, blk): untyped =
  expectKind(blk, nnkStmtList)
  let componentName = id
  let stateTypeName = ident(id.repr & "State")
  let constructorName = ident(id.repr.toLowerAscii)  # lowercase constructor

  result = nnkStmtList.newTree()

  var ctor: NimNode = nil
  var drawProc: NimNode = nil
  var measureProc: NimNode = nil
  var uiBlock: NimNode = nil
  var hasInit = false

  for stmt in blk:
    if stmt.kind == nnkCall and stmt[0].repr == "state":
      expectKind(stmt[1][0], nnkTupleTy)
      let tup = stmt[1][0]
      result.insert(0,
        quote do:
          type `stateTypeName`* = `tup`
      )
    elif stmt.kind == nnkCall and stmt[0].repr == "ui":
      uiBlock = stmt[1]
    elif stmt.kind == nnkProcDef and stmt[0].repr == "init":
      ctor = stmt
      hasInit = true
    elif stmt.kind == nnkProcDef and stmt[0].repr == "update":
      discard
    elif stmt.kind == nnkProcDef and stmt[0].repr == "draw":
      drawProc = stmt
    elif stmt.kind == nnkProcDef and stmt[0].repr == "measure":
      measureProc = stmt
    else:
      error("Unexpected statement in component:\n" & stmt.treeRepr)

  # Generate Component type (children field inherited from Widget)
  let painterType = getPainterType()
  result.add(quote do:
    type `componentName`* = ref object of Component
      painter: `painterType`
  )

  # Generate lowercase constructor from init proc
  if hasInit:
    let initParams = ctor[3]  # Formal params from init
    let initBody = ctor[6]    # Init body

    # Build constructor body statements
    var constructorBody = nnkStmtList.newTree(
      nnkCall.newTree(ident("new"), ident("result")),
      nnkAsgn.newTree(
        nnkDotExpr.newTree(ident("result"), ident("abstractState")),
        nnkObjConstr.newTree(
          nnkBracketExpr.newTree(ident("ComponentState"), stateTypeName),
          nnkExprColonExpr.newTree(
            ident("state"),
            nnkBlockStmt.newTree(
              newEmptyNode(),
              initBody
            )
          )
        )
      )
    )

    # Add UI children building if ui block exists
    if not uiBlock.isNil:
      # Initialize children array
      constructorBody.add(
        nnkAsgn.newTree(
          nnkDotExpr.newTree(ident("result"), ident("children")),
          nnkPrefix.newTree(ident("@"), nnkBracket.newTree())
        )
      )

      # Extract state for use in ui block
      constructorBody.add(
        nnkLetSection.newTree(
          nnkIdentDefs.newTree(
            ident("state"),
            newEmptyNode(),
            nnkDotExpr.newTree(
              nnkCall.newTree(
                nnkBracketExpr.newTree(ident("ComponentState"), stateTypeName),
                nnkDotExpr.newTree(ident("result"), ident("abstractState"))
              ),
              ident("state")
            )
          )
        )
      )

      # Add each child from ui block
      for child in uiBlock:
        if child.kind == nnkDiscardStmt or child.kind == nnkEmpty:
          continue
        constructorBody.add(
          nnkCall.newTree(
            nnkDotExpr.newTree(
              nnkDotExpr.newTree(ident("result"), ident("children")),
              ident("add")
            ),
            child
          )
        )

    # Add drawProc assignment if draw method exists
    if not drawProc.isNil:
      let drawBody = drawProc[6]  # Get the draw body
      constructorBody.add(
        nnkAsgn.newTree(
          nnkDotExpr.newTree(ident("result"), ident("drawProc")),
          nnkLambda.newTree(
            newEmptyNode(),
            newEmptyNode(),
            newEmptyNode(),
            nnkFormalParams.newTree(
              newEmptyNode(),
              nnkIdentDefs.newTree(ident("w"), ident("Widget"), newEmptyNode()),
              nnkIdentDefs.newTree(ident("p"), ident("pointer"), newEmptyNode())
            ),
            nnkPragma.newTree(ident("closure")),
            newEmptyNode(),
            nnkStmtList.newTree(
              nnkLetSection.newTree(
                nnkIdentDefs.newTree(
                  ident("self"),
                  newEmptyNode(),
                  nnkCall.newTree(componentName, ident("w"))
                )
              ),
              nnkLetSection.newTree(
                nnkIdentDefs.newTree(
                  ident("drawing"),
                  newEmptyNode(),
                  nnkCast.newTree(painterType, ident("p"))
                )
              ),
              nnkLetSection.newTree(
                nnkIdentDefs.newTree(
                  ident("state"),
                  newEmptyNode(),
                  nnkDotExpr.newTree(
                    nnkCall.newTree(
                      nnkBracketExpr.newTree(ident("ComponentState"), stateTypeName),
                      nnkDotExpr.newTree(ident("self"), ident("abstractState"))
                    ),
                    ident("state")
                  )
                )
              ),
              drawBody
            )
          )
        )
      )

    # Add measure call if measure method exists
    if not measureProc.isNil:
      let measureBody = measureProc[6]  # Get the measure body
      # Extract state for use in measure (if not already extracted for ui block)
      if uiBlock.isNil:
        constructorBody.add(
          nnkLetSection.newTree(
            nnkIdentDefs.newTree(
              ident("state"),
              newEmptyNode(),
              nnkDotExpr.newTree(
                nnkCall.newTree(
                  nnkBracketExpr.newTree(ident("ComponentState"), stateTypeName),
                  nnkDotExpr.newTree(ident("result"), ident("abstractState"))
                ),
                ident("state")
              )
            )
          )
        )
      # Create a block with self = result for the measure body
      constructorBody.add(
        nnkBlockStmt.newTree(
          newEmptyNode(),
          nnkStmtList.newTree(
            nnkLetSection.newTree(
              nnkIdentDefs.newTree(
                ident("self"),
                newEmptyNode(),
                ident("result")
              )
            ),
            measureBody
          )
        )
      )

    # Build constructor proc with same params as init
    let constructor = nnkProcDef.newTree(
      nnkPostfix.newTree(ident("*"), constructorName),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(componentName).add(initParams[1..^1]),  # Copy params from init
      newEmptyNode(),
      newEmptyNode(),
      constructorBody
    )
    result.add(constructor)
  else:
    error("Component must have an init proc", blk)

  # Draw proc is inlined into the drawProc closure in the constructor

