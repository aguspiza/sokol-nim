#-------------------------------------------------------------------------------
# bouncing_ball.nim
# Authentic Amiga "Boing!" demo - red/white checkerboard sphere.
#-------------------------------------------------------------------------------
import sokol/log as slog
import sokol/gfx as sg
import sokol/app as sapp
import sokol/gl as sgl
import sokol/glue as sglue
import std/math

const
  passAction = PassAction(
    colors: [ColorAttachmentAction(loadAction: loadActionClear, clearValue: (0.1f, 0.1f, 0.2f, 1f))]
  )
  gridLines = 20        # total lines per axis (10 per direction)
  gridSpacing = 30.0f   # spacing between grid lines in world units
  ballRadiusConst = 70f
  gridExtent: float32 = gridLines.float32 / 2.0f * gridSpacing  # half-extent of grid

var
  ballPip: sgl.Pipeline  # pipeline 3d con culling + depth

proc drawPerspectiveGrid() =
  # Draw a checkerboard-like perspective grid on the floor (y=0 plane)
  # Grid lines converge toward the horizon (perspective effect)
  let halfW = gridExtent
  let halfD = gridExtent
  
  # Horizontal lines (along X axis, going into depth Z)
  for i in 0..gridLines:
    let zi: float32 = i.float32
    let z = -halfD + zi * gridSpacing
    # Color variation for checkerboard bands
    let isEven = (i mod 2) == 0
    let (r, g, b) = if isEven: (0.15f, 0.15f, 0.35f) else: (0.12f, 0.12f, 0.30f)
    sgl.c3f(r, g, b)
    sgl.beginLines()
    sgl.v3f(-halfW, 0.0f, z)
    sgl.v3f( halfW, 0.0f, z)
    sgl.end()
  
  # Vertical lines (along Z axis, coming toward camera)
  for i in 0..gridLines:
    let xi: float32 = i.float32
    let x = -halfW + xi * gridSpacing
    let isEven = (i mod 2) == 0
    let (r, g, b) = if isEven: (0.15f, 0.15f, 0.35f) else: (0.12f, 0.12f, 0.30f)
    sgl.c3f(r, g, b)
    sgl.beginLines()
    sgl.v3f(x, 0.0f, -halfD)
    sgl.v3f(x, 0.0f,  halfD)
    sgl.end()

var
  ballX, ballY: float32
  ballVx, ballVy: float32
  ballRadius: float32 = 70f
  rotZ, rotX: float32 = 0f
  winW, winH: float32

const
  worldFloorY = 0.0f
  worldBallMinX = -gridExtent + ballRadiusConst
  worldBallMaxX = gridExtent - ballRadiusConst
  worldBallMaxY = 350f  # max bounce height

proc init() {.cdecl.} =
  sg.setup(sg.Desc(environment: sglue.environment(), logger: sg.Logger(fn: slog.fn)))
  sgl.setup(sgl.Desc(logger: sgl.Logger(fn: slog.fn)))
  
  # Create 3D pipeline with back-face culling and depth testing
  ballPip = sgl.makePipeline(sg.PipelineDesc(
    cullMode: cullModeBack,
    depth: DepthState(
      writeEnabled: true,
      compare: compareFuncLessEqual
    )
  ))
  
  winW = sapp.widthf()
  winH = sapp.heightf()
  ballX = 50.0f
  ballY = worldBallMaxY
  ballVx = 120.0f
  ballVy = -500.0f

proc frame() {.cdecl.} =
  let dt = sapp.frameDuration()
  const gravity = 800f
  
  # Apply gravity (in world space) - Y=0 is floor, Y+ is up, so gravity pulls down (negative vy)
  ballVy -= gravity * dt
  
  # Update position
  ballX += ballVx * dt
  ballY += ballVy * dt
  
  # Bounce off FLOOR (y=0 in world space)
  if ballY < worldFloorY + ballRadius:
    ballY = worldFloorY + ballRadius
    ballVy = 500.0f  # Fixed upward velocity
  
  # Bounce off ceiling
  if ballY > worldBallMaxY:
    ballY = worldBallMaxY
    ballVy = -500.0f  # Fixed downward velocity
  
  # Bounce off side walls (in world space)
  if ballX < worldBallMinX:
    ballX = worldBallMinX
    ballVx = abs(ballVx)
  elif ballX > worldBallMaxX:
    ballX = worldBallMaxX
    ballVx = -abs(ballVx)
  
  # Update rotation based on movement
  rotZ += ballVx * dt * 0.3f    # Rotate with horizontal movement
  rotX += ballVy * dt * 0.2f    # Y-axis spin with vertical movement
  
  winW = sapp.widthf()
  winH = sapp.heightf()
  
  sg.beginPass(Pass(action: passAction, swapchain: sglue.swapchain()))
  sgl.defaults()
  sgl.loadPipeline(ballPip)
  
  # Perspective projection - camera looking down at the floor
  let aspect = winW / winH
  sgl.matrixModeProjection()
  sgl.perspective(sgl.asRadians(60.0f), aspect, 1.0f, 2000.0f)
  
  sgl.matrixModeModelview()
  # Camera positioned above and back, looking at the play area
  sgl.lookat(0.0f, 250.0f, -600.0f,  0.0f, 0.0f, 0.0f,  0.0f, 1.0f, 0.0f)
  
  # Draw perspective grid floor
  drawPerspectiveGrid()
  
  # Draw the ball in 3D (floor is at y=0, ball bounces above it)
  sgl.pushMatrix()
  sgl.translate(ballX, ballY, 0.0f)
  sgl.rotate(sgl.asRadians(rotZ), 0, 0, 1)
  sgl.rotate(sgl.asRadians(rotX), 1, 0, 0)
  
  const bands = 6
  const segs = 12
  for lat in 0..<bands:
    let t1 = PI * (lat.float32 / bands.float32) - PI/2f
    let t2 = PI * ((lat + 1).float32 / bands.float32) - PI/2f
    for lon in 0..<segs:
      let p1 = 2f * PI * (lon.float32 / segs.float32)
      let p2 = 2f * PI * ((lon + 1).float32 / segs.float32)
      let isRed = ((lat + lon) mod 2) == 0
      let (r, g, b) = if isRed: (0.9f, 0.1f, 0.1f) else: (1f, 1f, 1f)
      sgl.c3f(r, g, b)
      sgl.beginQuads()
      sgl.v3f(ballRadius * cos(t1) * cos(p1), ballRadius * sin(t1), ballRadius * cos(t1) * sin(p1))
      sgl.v3f(ballRadius * cos(t1) * cos(p2), ballRadius * sin(t1), ballRadius * cos(t1) * sin(p2))
      sgl.v3f(ballRadius * cos(t2) * cos(p2), ballRadius * sin(t2), ballRadius * cos(t2) * sin(p2))
      sgl.v3f(ballRadius * cos(t2) * cos(p1), ballRadius * sin(t2), ballRadius * cos(t2) * sin(p1))
      sgl.end()
  
  sgl.popMatrix()
  
  sgl.draw()
  sg.endPass()
  sg.commit()

proc cleanup() {.cdecl.} =
  sgl.shutdown()
  sg.shutdown()

sapp.run(sapp.Desc(
  initCb: init, frameCb: frame, cleanupCb: cleanup,
  width: 800, height: 600, windowTitle: "Amiga Boing! Ball",
  icon: IconDesc(sokol_default: true), logger: sapp.Logger(fn: slog.fn)
))
