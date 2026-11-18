import SwiftUI

/// Asset-free interactive physics sandbox. World coordinates are in metres, Y points up.
struct CMPlaygroundView: View {
 @State private var world = CMPlaygroundView.makeWorld()
 @State private var running = false
 @State private var lastTick: Date?
 @State private var accumulator = 0.0
 @State private var selection: Selection?
 @State private var dragStart: SIMD2<Double>?
 @State private var initialSegment: CMStaticSegment2D?
 @State private var speed = 1.0
 @State private var reachedGoal = false
 @State private var editMode = true
 private enum Selection: Equatable { case ball(Int), ramp(Int) }
 private static let fixedStep = 1.0 / 120.0
 private static let goal = SIMD2<Double>(6.2,0.6)
 private static let goalRadius = 0.55
 private static let worldWidth = 7.0
 private static let worldHeight = 6.0

 private static func makeWorld() -> CMPhysicsWorld2D {
  var w = CMPhysicsWorld2D()
  w.floorY = 0
  w.floorFriction = 0.4
  w.segments = [CMStaticSegment2D(start:SIMD2(0.8,2.2),end:SIMD2(5.6,0.8),friction:0.2)]
  w.bodies = [CMPhysicsBody2D(position:SIMD2(1.2,4.5),radius:0.28,restitution:0.5,surfaceFriction:0.5)]
  return w
 }
 private func scale(_ size:CGSize) -> Double {
  max(1,min(Double(size.width)/Self.worldWidth,Double(size.height)/Self.worldHeight))
 }
 private func screen(_ position:SIMD2<Double>,_ size:CGSize) -> CGPoint {
  let s=scale(size)
  return CGPoint(x:position.x*s,y:Double(size.height)-position.y*s)
 }
 private func location(_ point:CGPoint,_ size:CGSize) -> SIMD2<Double> {
  let s=scale(size)
  return SIMD2(Double(point.x)/s,(Double(size.height)-Double(point.y))/s)
 }
 private func bounded(_ p:SIMD2<Double>) -> SIMD2<Double> {
  SIMD2(min(max(p.x,0.2),Self.worldWidth-0.2),min(max(p.y,0.2),Self.worldHeight-0.2))
 }
 private func squaredDistance(_ a:SIMD2<Double>,_ b:SIMD2<Double>) -> Double {
  let d=a-b
  return d.x*d.x+d.y*d.y
 }
 private func segmentDistanceSquared(_ p:SIMD2<Double>,_ segment:CMStaticSegment2D) -> Double {
  let axis=segment.end-segment.start
  let length=axis.x*axis.x+axis.y*axis.y
  guard length > 1e-10 else { return squaredDistance(p,segment.start) }
  let offset=p-segment.start
  let t=min(max((offset.x*axis.x+offset.y*axis.y)/length,0),1)
  return squaredDistance(p,segment.start+axis*t)
 }
 private func select(at p:SIMD2<Double>) -> Selection? {
  if let i=world.bodies.indices.reversed().first(where:{ squaredDistance(p,world.bodies[$0].position)<0.48*0.48 }) {
   return .ball(i)
  }
  if let i=world.segments.indices.reversed().first(where:{ segmentDistanceSquared(p,world.segments[$0])<0.28*0.28 }) {
   return .ramp(i)
  }
  return nil
 }
 private func tick(_ now:Date) {
  guard running else { lastTick=nil;return }
  guard let previous=lastTick else { lastTick=now;return }
  let elapsed=min(max(now.timeIntervalSince(previous),0),0.1)
  lastTick=now
  accumulator=min(accumulator+elapsed*speed,0.2)
  var steps=0
  while accumulator >= Self.fixedStep && steps < 24 {
   world.step(dt:Self.fixedStep)
   accumulator-=Self.fixedStep
   steps+=1
   checkGoal()
  }
 }
 private func checkGoal() {
  if world.bodies.contains(where:{ squaredDistance($0.position,Self.goal)<Self.goalRadius*Self.goalRadius }) {
   reachedGoal=true
   running=false
   lastTick=nil
  }
 }
 private func reset() {
  running=false
  lastTick=nil
  accumulator=0
  selection=nil
  dragStart=nil
  initialSegment=nil
  reachedGoal=false
  world=Self.makeWorld()
 }
 private func stepOnce() {
  guard !running else { return }
  world.step(dt:Self.fixedStep)
  checkGoal()
 }
 private func beginDrag(_ point:SIMD2<Double>) {
  guard editMode && !running else { return }
  selection=select(at:point)
  dragStart=point
  if case .ramp(let i)=selection { initialSegment=world.segments[i] }
  else { initialSegment=nil }
 }
 private func moveDrag(_ point:SIMD2<Double>) {
  guard editMode && !running,let selection else { return }
  let p=bounded(point)
  switch selection {
  case .ball(let i):
   guard world.bodies.indices.contains(i) else { return }
   world.bodies[i].position=p
   world.bodies[i].velocity = .zero
   world.bodies[i].angularVelocity=0
  case .ramp(let i):
   guard world.segments.indices.contains(i),let original=initialSegment,let start=dragStart else { return }
   let delta=p-start
   world.segments[i].start=bounded(original.start+delta)
   world.segments[i].end=bounded(original.end+delta)
  }
  reachedGoal=false
 }
 private func addBall() {
  guard !running && world.bodies.count < 20 else { return }
  let x=1.0+Double(world.bodies.count%6)*0.7
  world.bodies.append(CMPhysicsBody2D(position:SIMD2(x,5.2),radius:0.25,restitution:0.45,surfaceFriction:0.4))
 }
 private func addRamp() {
  guard !running && world.segments.count < 12 else { return }
  let y=1.4+Double(world.segments.count%4)*0.65
  world.segments.append(CMStaticSegment2D(start:SIMD2(2.2,y+0.5),end:SIMD2(4.2,y),friction:0.25))
 }
 private func deleteSelected() {
  guard !running,let selection else { return }
  switch selection {
  case .ball(let i):
   if world.bodies.indices.contains(i) { world.bodies.remove(at:i) }
  case .ramp(let i):
   if world.segments.indices.contains(i) { world.segments.remove(at:i) }
  }
  self.selection=nil
 }
 var body: some View {
  VStack(spacing:10) {
   Text("Mechanics playground").font(.headline)
   Text(reachedGoal ? "Goal reached!" : "Guide a ball into the green target")
    .font(.subheadline)
    .foregroundColor(reachedGoal ? .green : .secondary)
   GeometryReader { geometry in
    TimelineView(.animation(minimumInterval:1.0/60.0,paused:!running)) { timeline in
     Canvas { context,size in
      let floor=screen(SIMD2(0,world.floorY),size)
      var floorPath=Path()
      floorPath.move(to:CGPoint(x:0,y:floor.y))
      floorPath.addLine(to:CGPoint(x:size.width,y:floor.y))
      context.stroke(floorPath,with:.color(.gray),lineWidth:4)
      let goalCenter=screen(Self.goal,size)
      let goalRadius=Self.goalRadius*scale(size)
      context.stroke(Path(ellipseIn:CGRect(x:goalCenter.x-goalRadius,y:goalCenter.y-goalRadius,width:goalRadius*2,height:goalRadius*2)),with:.color(.green),lineWidth:4)
      for (i,segment) in world.segments.enumerated() {
       var path=Path()
       path.move(to:screen(segment.start,size))
       path.addLine(to:screen(segment.end,size))
       context.stroke(path,with:.color(selection == .ramp(i) ? .yellow : .orange),style:StrokeStyle(lineWidth:8,lineCap:.round))
      }
      for (i,ball) in world.bodies.enumerated() {
       let center=screen(ball.position,size)
       let radius=ball.radius*scale(size)
       let rect=CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2)
       context.fill(Path(ellipseIn:rect),with:.color(selection == .ball(i) ? .yellow : .cyan))
       let spoke=CGPoint(x:center.x+cos(ball.angle)*radius*0.8,y:center.y-sin(ball.angle)*radius*0.8)
       var line=Path()
       line.move(to:center)
       line.addLine(to:spoke)
       context.stroke(line,with:.color(.black.opacity(0.6)),lineWidth:2)
      }
     }
     .background(Color.black.opacity(0.85),in:RoundedRectangle(cornerRadius:14))
     .contentShape(Rectangle())
     .gesture(DragGesture(minimumDistance:0)
      .onChanged { value in
       guard editMode && !running else { return }
       if dragStart == nil { beginDrag(location(value.startLocation,geometry.size)) }
       moveDrag(location(value.location,geometry.size))
      }
      .onEnded { _ in dragStart=nil;initialSegment=nil })
     .onChange(of:timeline.date) { _,date in tick(date) }
    }
   }
   .frame(height:330)
   Toggle("Edit objects",isOn:$editMode).disabled(running)
   HStack {
    Button(running ? "Pause" : "Run") {
     running.toggle()
     lastTick=nil
     dragStart=nil
    }
    .buttonStyle(.borderedProminent)
    Button("Step") { stepOnce() }.disabled(running)
    .buttonStyle(.bordered)
    Button("Reset") { reset() }.buttonStyle(.bordered)
   }
   HStack {
    Button("Add ball") { addBall() }.disabled(running || world.bodies.count >= 20)
    Button("Add ramp") { addRamp() }.disabled(running || world.segments.count >= 12)
    Button("Delete") { deleteSelected() }.disabled(running || selection == nil)
   }
   .buttonStyle(.bordered)
   HStack {
    Text("Speed").font(.caption)
    Slider(value:$speed,in:0.25...2.0,step:0.25)
    Text(String(format:"%.2gx",speed)).font(.caption.monospacedDigit()).frame(width:40)
   }
   Text("Pause and drag a ball or ramp. Tap an object to select it.")
    .font(.caption2).foregroundStyle(.secondary)
  }
  .padding()
 }
}
