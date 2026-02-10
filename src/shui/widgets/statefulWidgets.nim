## Stateful Widget Macro
##
## Provides a macro for defining stateful UI widgets with local event handling.
## This allows creating reusable, self-contained UI components with their own
## state management and event handling logic.

import macros

proc transformEmitCalls(node: NimNode, eventName: NimNode): NimNode =
  ## Transform `emit EventKind` into `emit(Event(kind: EventKind))`
  ## and `emit EventKind(field: value)` into `emit(Event(kind: EventKind, field: value))`
  case node.kind:
  of nnkCommand:
    if node.len >= 2 and node[0].eqIdent("emit"):
      # emit EventKind or emit EventKind(args)
      let eventKind = node[1]
      if eventKind.kind == nnkIdent:
        # Simple: emit EventKind -> emit(Event(kind: EventKind))
        return newCall(
          ident("emit"),
          nnkObjConstr.newTree(
            eventName,
            nnkExprColonExpr.newTree(
              ident("kind"),
              eventKind
            )
          )
        )
      elif eventKind.kind == nnkCall or eventKind.kind == nnkObjConstr:
        # With params: emit EventKind(args) -> emit(Event(kind: EventKind, args...))
        let kind = if eventKind.kind == nnkCall: eventKind[0] else: eventKind[0]
        var objConstr = nnkObjConstr.newTree(eventName)
        objConstr.add(
          nnkExprColonExpr.newTree(
            ident("kind"),
            kind
          )
        )
        # Add all the fields from the event constructor
        for i in 1 ..< eventKind.len:
          objConstr.add(eventKind[i])
        return newCall(ident("emit"), objConstr)
  else:
    discard

  # Recursively transform children
  result = copyNimNode(node)
  for child in node:
    result.add(transformEmitCalls(child, eventName))

macro widget*(args: varargs[untyped]): untyped =
  ## Define a stateful Shui widget with local event handling
  ##
  ## Example:
  ##   widget Counter:
  ##     state:
  ##       count: int = 0
  ##     event:
  ##       Increment
  ##       Decrement
  ##       SetValue(value: int)
  ##     handle(evt):
  ##       case evt.kind
  ##       of Increment: state.count += 1
  ##       of Decrement: state.count -= 1
  ##       of SetValue: state.count = evt.value
  ##     render(ui: var UI):
  ##       button("Click"):
  ##         onClick: emit Increment

  # Parse: widget Name: body
  # args[0] is the name, args[1] is the body
  if args.len != 2:
    error("widget expects: widget Name: <body>")

  let name = args[0]
  let body = args[1]

  expectKind(body, nnkStmtList)

  var stateSection, eventSection, handleSection, renderSection: NimNode

  # Parse the component definition sections
  for stmt in body:
    if stmt.kind == nnkCall and stmt.len >= 2:
      let sectionName = stmt[0]
      if sectionName.eqIdent("state"):
        stateSection = stmt[1]
      elif sectionName.eqIdent("event"):
        eventSection = stmt[1]
      elif sectionName.eqIdent("handle"):
        handleSection = stmt
      elif sectionName.kind == nnkObjConstr and sectionName[0].eqIdent("render"):
        # render(params): body is parsed as Call(ObjConstr(render, params...), body)
        renderSection = stmt

  # Generate type names
  let stateName = ident($name & "State")
  let eventKindName = ident($name & "EventKind")
  let eventName = ident($name & "Event")
  let renderProcName = ident("render" & $name)

  result = newStmtList()

  # 1. Generate state type
  var stateFields = nnkRecList.newTree()
  if stateSection != nil:
    for field in stateSection:
      case field.kind:
      of nnkCall:
        # This is: fieldName: Type = value
        # Structure: Call(Ident fieldName, StmtList(Asgn(Type, value)))
        if field.len == 2 and field[0].kind == nnkIdent and field[1].kind == nnkStmtList:
          # fieldName: Type = value format
          let fieldName = field[0]
          let stmtList = field[1]
          if stmtList.len > 0 and stmtList[0].kind == nnkAsgn:
            let fieldType = stmtList[0][0]
            let defaultValue = stmtList[0][1]
            stateFields.add(
              nnkIdentDefs.newTree(
                nnkPostfix.newTree(ident("*"), fieldName),
                fieldType,
                defaultValue
              )
            )
          else:
            error("Invalid state field format: " & repr(field), field)
        else:
          error("Invalid state field structure: " & repr(field), field)
      of nnkAsgn:
        # fieldName: Type = defaultValue
        let nameAndType = field[0]
        let defaultValue = field[1]
        if nameAndType.kind == nnkExprColonExpr:
          let fieldName = nameAndType[0]
          let fieldType = nameAndType[1]
          stateFields.add(
            nnkIdentDefs.newTree(
              nnkPostfix.newTree(ident("*"), fieldName),
              fieldType,
              defaultValue
            )
          )
        else:
          error("Invalid state field format: " & repr(field), field)
      of nnkIdentDefs:
        # Already in correct format
        stateFields.add(field)
      else:
        error("Invalid state field kind " & $field.kind & ": " & repr(field), field)

  let stateTypeDef = nnkTypeDef.newTree(
    nnkPostfix.newTree(ident("*"), stateName),
    newEmptyNode(),
    nnkObjectTy.newTree(
      newEmptyNode(),
      newEmptyNode(),
      stateFields
    )
  )
  result.add(nnkTypeSection.newTree(stateTypeDef))

  # 2. Generate event types
  if eventSection != nil:
    var eventKinds = nnkEnumTy.newTree(newEmptyNode())
    var eventRecCase = nnkRecCase.newTree(
      nnkIdentDefs.newTree(ident("kind"), eventKindName, newEmptyNode())
    )

    for eventDef in eventSection:
      case eventDef.kind:
      of nnkIdent:
        # Simple event with no data: EventName
        eventKinds.add(eventDef)
        eventRecCase.add(
          nnkOfBranch.newTree(eventDef, nnkRecList.newTree())
        )
      of nnkCall, nnkObjConstr:
        # Event with data: EventName(field: Type) or EventName(field: Type, field2: Type2)
        let eventKind = eventDef[0]
        eventKinds.add(eventKind)
        var fieldList = nnkRecList.newTree()
        for i in 1 ..< eventDef.len:
          let param = eventDef[i]
          case param.kind:
          of nnkExprColonExpr:
            # field: Type format
            let fieldName = param[0]
            let fieldType = param[1]
            fieldList.add(
              nnkIdentDefs.newTree(
                nnkPostfix.newTree(ident("*"), fieldName),
                fieldType,
                newEmptyNode()
              )
            )
          of nnkIdentDefs:
            # Already in the right format
            fieldList.add(param)
          else:
            error("Invalid event parameter: " & repr(param), param)
        eventRecCase.add(
          nnkOfBranch.newTree(eventKind, fieldList)
        )
      else:
        error("Invalid event definition kind " & $eventDef.kind & ": " & repr(eventDef), eventDef)

    let eventKindTypeDef = nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), eventKindName),
      newEmptyNode(),
      eventKinds
    )
    result.add(nnkTypeSection.newTree(eventKindTypeDef))

    let eventTypeDef = nnkTypeDef.newTree(
      nnkPostfix.newTree(ident("*"), eventName),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        nnkRecList.newTree(eventRecCase)
      )
    )
    result.add(nnkTypeSection.newTree(eventTypeDef))

  # 3. Generate render proc with emit and handle
  if renderSection != nil:
    # renderSection is Call(ObjConstr(render, ExprColonExpr...), StmtList(body))
    let objConstr = renderSection[0]
    let renderBody = renderSection[1]

    # Build the parameter list for render proc
    var procParams = nnkFormalParams.newTree(newEmptyNode())

    # Add custom parameters from ObjConstr
    for i in 1 ..< objConstr.len:
      let paramExpr = objConstr[i]
      if paramExpr.kind == nnkExprColonExpr:
        let paramName = paramExpr[0]
        let paramType = paramExpr[1]
        procParams.add(
          nnkIdentDefs.newTree(
            paramName,
            paramType,
            newEmptyNode()
          )
        )

    # Add state parameter
    procParams.add(
      nnkIdentDefs.newTree(
        ident("state"),
        nnkVarTy.newTree(stateName),
        newEmptyNode()
      )
    )

    # Build the emit template (not a proc, to avoid closure capture issues)
    let emitTemplateBody = newStmtList()
    if handleSection != nil and handleSection.len >= 3:
      # handleSection is Call(Ident "handle", Ident "evt", StmtList(body))
      let handleParam = handleSection[1]  # evt parameter name
      let handleCode = handleSection[2]    # body
      let eventParam = ident("event")

      # Build: let evt = event; <handleCode>
      emitTemplateBody.add(
        nnkLetSection.newTree(
          nnkIdentDefs.newTree(
            handleParam,
            newEmptyNode(),
            eventParam
          )
        )
      )
      emitTemplateBody.add(handleCode)

    let emitTemplate = nnkTemplateDef.newTree(
      ident("emit"),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        newEmptyNode(),
        nnkIdentDefs.newTree(
          ident("event"),
          eventName,
          newEmptyNode()
        )
      ),
      newEmptyNode(),
      newEmptyNode(),
      emitTemplateBody
    )

    # Transform emit calls in render body
    let transformedRenderBody = transformEmitCalls(renderBody, eventName)

    # Build the render proc body with emit template and render code
    let renderProcBody = newStmtList()
    renderProcBody.add(emitTemplate)
    renderProcBody.add(transformedRenderBody)

    # Build render proc
    result.add(
      nnkProcDef.newTree(
        nnkPostfix.newTree(ident("*"), renderProcName),
        newEmptyNode(),
        newEmptyNode(),
        procParams,
        nnkPragma.newTree(ident("gcsafe")),
        newEmptyNode(),
        renderProcBody
      )
    )
