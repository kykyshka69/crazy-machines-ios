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
 @State private var startingLayout: CMPhysicsWorld2D?
 @State private var simulationSteps = 0
 @State private var showHelp = false
 @State private var showGrid = true
 @State private var snapToGrid = false
 @State private var gravityStrength = 9.81
 @State private var trailsEnabled = true
 @State private var trails: [[SIMD2<Double>]] = []
 @State private var undoStack: [CMPhysicsWorld2D] = []
 @State private var redoStack: [CMPhysicsWorld2D] = []
 @State private var dragSnapshot: CMPhysicsWorld2D?
 @State private var dragChanged = false
 @State private var gravityEditSnapshot: CMPhysicsWorld2D?
 @State private var storageMessage: String?
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
 private func snapped(_ p:SIMD2<Double>) -> SIMD2<Double> {
  guard snapToGrid else { return p }
  return SIMD2((p.x*4).rounded()/4,(p.y*4).rounded()/4)
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
   let before=world.bodies.map(\.position)
   world.step(dt:Self.fixedStep)
   recordTrails()
   simulationSteps+=1
   accumulator-=Self.fixedStep
   steps+=1
   checkGoal(previousPositions:before)
   if reachedGoal {
    // A finished attempt must not carry leftover simulation time into Retry.
    accumulator=0
    break
   }
  }
 }
 private func recordTrails() {
  guard trailsEnabled else { return }
  if trails.count != world.bodies.count { trails=world.bodies.map { [$0.position] } }
  for i in world.bodies.indices {
   if simulationSteps % 3 == 0 {
    trails[i].append(world.bodies[i].position)
    if trails[i].count > 90 { trails[i].removeFirst() }
   }
  }
 }
 private func checkGoal(previousPositions: [SIMD2<Double>] = []) {
  let hit=world.bodies.enumerated().contains { index,ball in
   let radius=Self.goalRadius+ball.radius
   if squaredDistance(ball.position,Self.goal) <= radius*radius { return true }
   guard previousPositions.indices.contains(index) else { return false }
   let start=previousPositions[index]
   let travel=ball.position-start
   let length=travel.x*travel.x+travel.y*travel.y
   guard length > 1e-12 else { return false }
   let toGoal=Self.goal-start
   let fraction=min(max((toGoal.x*travel.x+toGoal.y*travel.y)/length,0),1)
   return squaredDistance(start+travel*fraction,Self.goal) <= radius*radius
  }
  if hit {
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
  undoStack=[]
  redoStack=[]
  dragSnapshot=nil
  dragChanged=false
  gravityEditSnapshot=nil
  world.gravity.y = -gravityStrength
  startingLayout=nil
  simulationSteps=0
  trails=[]
 }
 private func restartExperiment() {
  guard let layout=startingLayout else { return }
  running=false
  lastTick=nil
  accumulator=0
  reachedGoal=false
  selection=nil
  world=layout
  gravityStrength = -layout.gravity.y
  simulationSteps=0
  trails=[]
  dragStart=nil
  initialSegment=nil
  dragSnapshot=nil
  dragChanged=false
 }
 private static let savedLevelKey = "cm.playground.savedLevel.v1"
 private func saveLevel() {
  do {
   let layout=startingLayout ?? world
   let document=CMLevelDocument(world:layout)
   _ = try document.makeWorld() // Do not overwrite a good save with an invalid layout.
   let data=try JSONEncoder().encode(document)
   UserDefaults.standard.set(data,forKey:Self.savedLevelKey)
   storageMessage="Experiment saved on this device"
  } catch {
   storageMessage="Save failed: \(error.localizedDescription)"
  }
 }
 private func loadLevel() {
  guard let data=UserDefaults.standard.data(forKey:Self.savedLevelKey) else {
   storageMessage="No saved experiment yet"
   return
  }
  do {
   let loaded=try JSONDecoder().decode(CMLevelDocument.self,from:data).makeWorld()
   running=false
   lastTick=nil
   accumulator=0
   undoStack=[]
   redoStack=[]
   world=loaded
   gravityStrength = -loaded.gravity.y
   clearExperimentState()
   storageMessage="Saved experiment loaded"
  } catch {
   storageMessage="Saved experiment is invalid"
  }
 }
 private func saveUndo() {
  guard !running else { return }
  undoStack.append(world)
  if undoStack.count > 30 { undoStack.removeFirst() }
  redoStack=[]
 }
 private func undo() {
  guard !running,let previous=undoStack.popLast() else { return }
  redoStack.append(world)
  if redoStack.count > 30 { redoStack.removeFirst() }
  world=previous
  gravityStrength = -previous.gravity.y
  clearExperimentState()
 }
 private func redo() {
  guard !running,let next=redoStack.popLast() else { return }
  undoStack.append(world)
  if undoStack.count > 30 { undoStack.removeFirst() }
  world=next
  gravityStrength = -next.gravity.y
  clearExperimentState()
 }
 private func clearExperimentState() {
  startingLayout=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  selection=nil
  dragStart=nil
  initialSegment=nil
  dragSnapshot=nil
  dragChanged=false
  gravityEditSnapshot=nil
  lastTick=nil
  accumulator=0
 }
 private func rotateSelectedRamp(by angle:Double) {
  guard !running,case .ramp(let index)=selection,world.segments.indices.contains(index) else { return }
  let segment=world.segments[index]
  let midpoint=(segment.start+segment.end)*0.5
  let half=(segment.end-segment.start)*0.5
  let rotated=SIMD2(half.x*cos(angle)-half.y*sin(angle),half.x*sin(angle)+half.y*cos(angle))
  let a=midpoint-rotated,b=midpoint+rotated
  guard a.x >= 0.2,a.x <= Self.worldWidth-0.2,b.x >= 0.2,b.x <= Self.worldWidth-0.2,
        a.y >= 0.2,a.y <= Self.worldHeight-0.2,b.y >= 0.2,b.y <= Self.worldHeight-0.2 else { return }
  guard squaredDistance(a,segment.start) > 1e-12 || squaredDistance(b,segment.end) > 1e-12 else { return }
  saveUndo()
  world.segments[index].start=a
  world.segments[index].end=b
  startingLayout=nil
  simulationSteps=0
  reachedGoal=false
  trails=[]
 }

 private func stepOnce() {
  guard !running && !reachedGoal else { return }
  if startingLayout == nil { startingLayout=world }
  let before=world.bodies.map(\.position)
  world.step(dt:Self.fixedStep)
  recordTrails()
  simulationSteps+=1
  checkGoal(previousPositions:before)
 }
 private func beginDrag(_ point:SIMD2<Double>) {
  guard editMode && !running else { return }
  selection=select(at:point)
  dragSnapshot=selection == nil ? nil : world
  dragChanged=false
  dragStart=point
  if case .ramp(let i)=selection { initialSegment=world.segments[i] }
  else { initialSegment=nil }
 }
 private func moveDrag(_ point:SIMD2<Double>) {
  guard editMode && !running,let selection else { return }
  let p=bounded(snapped(point))
  switch selection {
  case .ball(let i):
   guard world.bodies.indices.contains(i) else { return }
   let radius=world.bodies[i].radius
   let next=SIMD2(min(max(p.x,radius),Self.worldWidth-radius),min(max(p.y,radius),Self.worldHeight-radius))
   guard squaredDistance(next,world.bodies[i].position) > 1e-10 else { return }
   dragChanged=true
   world.bodies[i].position=next
   world.bodies[i].velocity = .zero
   world.bodies[i].angularVelocity=0
  case .ramp(let i):
   guard world.segments.indices.contains(i),let original=initialSegment,let start=dragStart else { return }
   let requested=snapped(point)-start
   // Clamp the translation once for both endpoints, preserving ramp length and slope.
   let dx=min(max(requested.x,0.2-min(original.start.x,original.end.x)),Self.worldWidth-0.2-max(original.start.x,original.end.x))
   let dy=min(max(requested.y,0.2-min(original.start.y,original.end.y)),Self.worldHeight-0.2-max(original.start.y,original.end.y))
   let delta=SIMD2(dx,dy)
   let targetStart=original.start+delta
   guard squaredDistance(targetStart,world.segments[i].start) > 1e-10 else { return }
   dragChanged=true
   world.segments[i].start=targetStart
   world.segments[i].end=original.end+delta
  }
  reachedGoal=false
  startingLayout=nil
  simulationSteps=0
  trails=[]
 }
 private func addBall() {
  guard !running && world.bodies.count < 20 else { return }
  let radius=0.25
  let candidates=(0..<6).flatMap { row in
   (0..<12).map { col in SIMD2<Double>(0.5+Double(col)*0.5,5.5-Double(row)*0.75) }
  }
  guard let position=candidates.first(where: { candidate in
   world.bodies.allSatisfy { other in
    squaredDistance(candidate,other.position) >= pow(radius+other.radius+0.05,2)
   } && world.segments.allSatisfy { segment in
    segmentDistanceSquared(candidate,segment) >= pow(radius+0.05,2)
   }
  }) else {
   storageMessage="No free space for another ball"
   return
  }
  saveUndo()
  world.bodies.append(CMPhysicsBody2D(position:position,radius:radius,restitution:0.45,surfaceFriction:0.4))
  startingLayout=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
 }
 private func addRamp() {
  guard !running && world.segments.count < 12 else { return }
  let candidates=(0..<8).flatMap { row in
   (0..<5).map { col -> CMStaticSegment2D in
    let x=0.5+Double(col)*1.15
    let y=0.9+Double(row)*0.65
    return CMStaticSegment2D(start:SIMD2(x,y+0.35),end:SIMD2(x+0.9,y),friction:0.25)
   }
  }
  guard let segment=candidates.first(where: { candidate in
   let midpoint=(candidate.start+candidate.end)*0.5
   return world.bodies.allSatisfy { ball in
    segmentDistanceSquared(ball.position,candidate) >= pow(ball.radius+0.12,2)
   } && world.segments.allSatisfy { existing in
    segmentDistanceSquared(candidate.start,existing) > 0.12*0.12 &&
    segmentDistanceSquared(candidate.end,existing) > 0.12*0.12 &&
    segmentDistanceSquared(midpoint,existing) > 0.12*0.12 &&
    segmentDistanceSquared(existing.start,candidate) > 0.12*0.12 &&
    segmentDistanceSquared(existing.end,candidate) > 0.12*0.12
   }
  }) else {
   storageMessage="No free space for another ramp"
   return
  }
  saveUndo()
  world.segments.append(segment)
  startingLayout=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
 }
 private func deleteSelected() {
  guard !running,let selection else { return }
  switch selection {
  case .ball(let i):
   guard world.bodies.indices.contains(i) else { self.selection=nil; return }
  case .ramp(let i):
   guard world.segments.indices.contains(i) else { self.selection=nil; return }
  }
  saveUndo()
  switch selection {
  case .ball(let i):
   world.bodies.remove(at:i)
  case .ramp(let i):
   world.segments.remove(at:i)
  }
  self.selection=nil
  trails=[]
  startingLayout=nil
  reachedGoal=false
  simulationSteps=0
 }
 var body: some View {
  ScrollView {
  VStack(spacing:10) {
   Text("Mechanics playground").font(.headline)
   Text(reachedGoal ? "Goal reached!" : "Guide a ball into the green target")
    .font(.subheadline)
    .foregroundColor(reachedGoal ? .green : .secondary)
   GeometryReader { geometry in
    TimelineView(.animation(minimumInterval:1.0/60.0,paused:!running)) { timeline in
     Canvas { context,size in
      if showGrid {
       var grid=Path()
       let unit=scale(size)*0.5
       if unit > 0 {
        for i in 0...Int(Double(size.width)/unit) {
         let x=Double(i)*unit
         grid.move(to:CGPoint(x:x,y:0))
         grid.addLine(to:CGPoint(x:x,y:size.height))
        }
        for i in 0...Int(Double(size.height)/unit) {
         let y=Double(i)*unit
         grid.move(to:CGPoint(x:0,y:y))
         grid.addLine(to:CGPoint(x:size.width,y:y))
        }
       }
       context.stroke(grid,with:.color(.white.opacity(0.10)),lineWidth:0.5)
      }
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
      if trailsEnabled {
       for trail in trails where trail.count > 1 {
        var path=Path()
        path.move(to:screen(trail[0],size))
        for position in trail.dropFirst() { path.addLine(to:screen(position,size)) }
        context.stroke(path,with:.color(.cyan.opacity(0.35)),lineWidth:1.5)
       }
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
     .highPriorityGesture(DragGesture(minimumDistance:0)
      .onChanged { value in
       guard editMode && !running else { return }
       if dragStart == nil { beginDrag(location(value.startLocation,geometry.size)) }
       moveDrag(location(value.location,geometry.size))
      }
      .onEnded { _ in
       if dragChanged,let before=dragSnapshot {
        undoStack.append(before)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack=[]
       }
       dragSnapshot=nil
       dragChanged=false
       dragStart=nil
       initialSegment=nil
      })
     .onChange(of:timeline.date) { _,date in tick(date) }
    }
   }
   .frame(height:300)
   HStack {
    Text("Time: "+String(format:"%.2f",Double(simulationSteps)*Self.fixedStep)+" s")
    Spacer()
    Text("Balls: \(world.bodies.count) · Ramps: \(world.segments.count)")
   }
   .font(.caption.monospacedDigit())
   HStack {
    Toggle("Grid",isOn:$showGrid)
    Toggle("Snap",isOn:$snapToGrid).disabled(running)
    Toggle("Trails",isOn:$trailsEnabled)
   }
   .font(.caption)
   Toggle("Edit objects",isOn:$editMode).disabled(running)
   HStack {
    Button(running ? "Pause" : "Run") {
     if !running && reachedGoal { restartExperiment() }
     if !running && startingLayout == nil { startingLayout=world }
     running.toggle()
     lastTick=nil
     dragStart=nil
    }
    .buttonStyle(.borderedProminent)
    Button("Step") { stepOnce() }.disabled(running || reachedGoal)
    .buttonStyle(.bordered)
    Button("Retry") { restartExperiment() }.disabled(startingLayout == nil).buttonStyle(.bordered)
    Button("Reset") { reset() }.buttonStyle(.bordered)
   }
   HStack {
    Button("Save") { saveLevel() }
    Button("Load") { loadLevel() }
   }.buttonStyle(.bordered)
   if let storageMessage { Text(storageMessage).font(.caption).foregroundStyle(.secondary) }
   HStack {
    Button("Undo") { undo() }.disabled(running || undoStack.isEmpty)
    Button("Redo") { redo() }.disabled(running || redoStack.isEmpty)
   }.buttonStyle(.bordered)
   HStack {
    Button("Add ball") { addBall() }.disabled(running || world.bodies.count >= 20)
    Button("Add ramp") { addRamp() }.disabled(running || world.segments.count >= 12)
    Button("Delete") { deleteSelected() }.disabled(running || selection == nil)
   }
   .buttonStyle(.bordered)
   HStack {
    Button("Rotate ↶") { rotateSelectedRamp(by: .pi/12) }
    Button("Rotate ↷") { rotateSelectedRamp(by: -.pi/12) }
   }
   .buttonStyle(.bordered)
   .disabled(running || { if case .ramp = selection { return false }; return true }())
   HStack {
    Text("Gravity").font(.caption)
    Slider(value:$gravityStrength,in:0...20,step:0.5,onEditingChanged: { editing in
      if editing {
       gravityEditSnapshot=world
      } else if let before=gravityEditSnapshot {
       gravityEditSnapshot=nil
       if abs(before.gravity.y-world.gravity.y) > 1e-9 {
        undoStack.append(before)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack=[]
       }
      }
     })
     .disabled(running)
     .onChange(of:gravityStrength) { _,newValue in
      // Loading or retrying a level updates this slider programmatically.
      // Do not invalidate the restored experiment unless gravity actually changes.
      guard abs(world.gravity.y + newValue) > 1e-9 else { return }
      world.gravity.y = -newValue
      startingLayout=nil
      reachedGoal=false
      simulationSteps=0
      trails=[]
      lastTick=nil
      accumulator=0
     }
    Text(String(format:"%.1f",gravityStrength)).font(.caption.monospacedDigit()).frame(width:35)
   }
   HStack {
    Text("Speed").font(.caption)
    Slider(value:$speed,in:0.25...2.0,step:0.25)
    Text(String(format:"%.2gx",speed)).font(.caption.monospacedDigit()).frame(width:40)
   }
   Button(showHelp ? "Hide instructions" : "Instructions") { showHelp.toggle() }
    .font(.caption)
   if showHelp {
    Text("Pause the simulation to edit. Drag balls and ramps; tap to select. Rotate the selected ramp with the arrows. Run, pause, step frame by frame, or retry your setup. Reach the green circle to win.")
     .font(.caption).foregroundStyle(.secondary)
   }
   Text("Pause and drag a ball or ramp. Tap an object to select it.")
    .font(.caption2).foregroundStyle(.secondary)
  }
  .padding()
  }
 } 
}
