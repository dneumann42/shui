import options, macros, fusion/matching, sequtils, sugar, typetraits, typeinfo
import std/enumerate

type
  WidgetState* = enum
    normal
    active
    disabled

  HAlign* = enum
    left
    center
    right

  VAlign* = enum
    top
    center
    bottom

  Align* = tuple[v: VAlign, h: HAlign]

  Widget* = ref object of RootObj
    isHot*: bool
    state*: WidgetState = normal
    lastState*: WidgetState = normal
    align*: Align
    base: Widget
    pos*, size*: (float, float)

  Layout* = ref object of Widget
    nodes*: seq[Widget]

  Panel* = ref object of Layout
    fixedSize* = none((float, float))

  Horizontal* = ref object of Layout
  Vertical* = ref object of Layout

  Element* = ref object of Widget

  Text* = ref object of Element
    text*: string

  Button* = ref object of Text
    id*: string
    clicked*: bool

  Label* = ref object of Text

method spacing*(layout: Layout): float {.base.} = discard
method spacing*(layout: Vertical): float = layout.spacing
method spacing*(layout: Horizontal): float = layout.spacing
method spacing*(layout: Panel): float = layout.spacing

method measure*(elem: Element): (float, float) {.base.} = discard

proc x*(w: Widget): auto = w.pos[0]
proc y*(w: Widget): auto = w.pos[1]
proc w*(w: Widget): auto = w.size[0]
proc h*(w: Widget): auto = w.size[1]

converter toTuple*(w: Widget): (float, float, float, float) =
  (w.x, w.y, w.w, w.h)

proc name*(widget: Widget): string =
  if widget of Horizontal: "Horizontal"
  elif widget of Vertical: "Vertical"
  elif widget of Panel: "Panel"
  elif widget of Button: "Button"
  elif widget of Label: "Label"
  else: "Widget"

proc `$`*(widget: Widget): string =
  result = name(widget)
  if widget of Layout:
    result &= "("
    for i, node in enumerate(widget.Layout.nodes):
      result &= $node & (if i < widget.Layout.nodes.len - 1: ", " else: "")
    result &= ")"

proc `+`*(a, b: (float, float)): (float, float) =
  (a[0] + b[0], a[1] + b[1])

proc `+=`*(a: var (float, float), b: (float, float)) =
  a[0] += b[0]
  a[1] += b[1]

proc `-`*(a, b: (float, float)): (float, float) =
  (a[0] - b[0], a[1] - b[1])

proc `-=`*(a: var (float, float), b: (float, float)) =
  a[0] -= b[0]
  a[1] -= b[1]

macro layoutOr*(w, a, b: untyped): untyped =
  quote do: (if `w` is Layout: `a` else: `b`)

proc base*[T: Widget](w: T): Option[T] =
  if not w.base.isNil:
    result = some(w.base)

proc `base=`*(w: var Widget, p: Widget) =
  w.base = p

proc text*(widget: Widget): Option[string] =
  if widget of Text:
    widget.Text.text.some
  else:
    none(string)

proc add*(l: Layout, nodes: varargs[Widget]) =
  for node in nodes:
    if node.isNil:
      continue
    node.base = l
    l.nodes.add(node)

proc label*(text = ""): Label =
  result = Label(text: text)

proc initButton*(text = "", id: string): Button =
  result = Button(text: text, id: id)

template panel*(blk: untyped): Panel =
  let (w, h) = blk()
  Panel(nodes: @[], fixedSize: (w, h).some)

proc vertical*(nodes: varargs[Widget]): Layout =
  result = Vertical(nodes: @[])
  result.add(nodes)

proc horizontal*(nodes: varargs[Widget]): Layout =
  result = Horizontal(nodes: @[])
  result.add(nodes)
