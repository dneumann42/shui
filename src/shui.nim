## Shui - A simple GUI framework
##
## This is the main entry point for the Shui GUI framework.

type
  Widget* = ref object of RootObj
    ## Base widget type for all GUI elements
    x*, y*: int
    width*, height*: int

proc newWidget*(x, y, width, height: int): Widget =
  ## Create a new basic widget
  Widget(x: x, y: y, width: width, height: height)

proc render*(widget: Widget) {.base.} =
  ## Base render method for widgets
  discard

when isMainModule:
  echo "Shui GUI Framework v0.1.0"
