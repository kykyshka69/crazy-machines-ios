import SwiftUI
import UniformTypeIdentifiers

struct CMJSONLevelFile: FileDocument {
 static var readableContentTypes: [UTType] { [.json] }
 static var writableContentTypes: [UTType] { [.json] }
 var data: Data
 init(data:Data) { self.data=data }
 init(configuration:ReadConfiguration) throws {
  guard let data=configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
  self.data=data
 }
 func fileWrapper(configuration:WriteConfiguration) throws -> FileWrapper {
  FileWrapper(regularFileWithContents:data)
 }
}

/// Asset-free interactive physics sandbox. World coordinates are in metres, Y points up.
struct CMPlaygroundView: View {
 @Environment(\.scenePhase) private var scenePhase
 @State private var world = CMPlaygroundView.makeWorld()
 @State private var pins: [CMPinJoint2D] = []
 @State private var pinUndoStack: [[CMPinJoint2D]] = []
 @State private var pinRedoStack: [[CMPinJoint2D]] = []
 @State private var startingPins: [CMPinJoint2D]?
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
 @State private var selectedSaveSlot = 1
 @State private var levelName = "Untitled experiment"
 @State private var confirmingOverwrite = false
 @State private var confirmingDelete = false
 @State private var restoredDraft = false
 @State private var exportingLevel = false
 @State private var importingLevel = false
 @State private var exportFile: CMJSONLevelFile?
 @State private var confirmingImport = false
 @State private var confirmingReset = false
 @State private var confirmingClear = false
 @State private var pendingImport: CMPhysicsWorld2D?
 @State private var pendingImportPins: [CMPinJoint2D] = []
 @State private var pendingImportName = ""
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
   world.applyPins(pins)
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
 private func clearScene() {
  guard !running else { return }
  saveUndo()
  world.bodies=[]
  world.segments=[]
  pins=[]
  clearExperimentState()
  storageMessage="Cleared scene (Undo to restore)"
 }
 private func nudgeSelected(dx:Double,dy:Double) {
  guard !running,let selection else { return }
  let delta=SIMD2<Double>(dx,dy)
  switch selection {
  case .ball(let i):
   guard world.bodies.indices.contains(i) else { return }
   let ball=world.bodies[i]
   let p=ball.position+delta
   guard p.x>=ball.radius,p.x<=Self.worldWidth-ball.radius,
    p.y>=ball.radius,p.y<=Self.worldHeight-ball.radius,
    world.bodies.enumerated().allSatisfy({ entry in
     entry.offset == i || squaredDistance(p,entry.element.position)>=pow(ball.radius+entry.element.radius+0.02,2)
    }),
    world.segments.allSatisfy({ segment in
     segmentDistanceSquared(p,segment)>=pow(ball.radius+0.02,2)
    }) else {
    storageMessage="Move blocked by boundary or object"
    return
   }
   saveUndo()
   world.bodies[i].position=p
   world.bodies[i].velocity = .zero
   world.bodies[i].angularVelocity=0
  case .ramp(let i):
   guard world.segments.indices.contains(i) else { return }
   let ramp=world.segments[i]
   let a=ramp.start+delta,b=ramp.end+delta
   guard [a,b].allSatisfy({ p in
    p.x>=0.2 && p.x<=Self.worldWidth-0.2 && p.y>=0.2 && p.y<=Self.worldHeight-0.2
   }),
   world.bodies.allSatisfy({ ball in
    segmentDistanceSquared(ball.position,CMStaticSegment2D(start:a,end:b))>=pow(ball.radius+0.02,2)
   }) else {
    storageMessage="Move blocked by boundary or ball"
    return
   }
   saveUndo()
   world.segments[i].start=a
   world.segments[i].end=b
  }
  startingLayout=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
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
  pins=[]
  pinUndoStack=[]
  pinRedoStack=[]
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
  pins=startingPins ?? pins
  gravityStrength = -layout.gravity.y
  simulationSteps=0
  trails=[]
  dragStart=nil
  initialSegment=nil
  dragSnapshot=nil
  dragChanged=false
 }
 private static let savedLevelKey = "cm.playground.savedLevel.v1"
 private func saveKey(for slot:Int) -> String {
  slot == 1 ? Self.savedLevelKey : Self.savedLevelKey+".slot.\(slot)"
 }
 private func levelNameKey(for slot:Int) -> String {
  saveKey(for:slot)+".name"
 }
 private func deleteSavedLevel() {
  let key=saveKey(for:selectedSaveSlot)
  guard UserDefaults.standard.data(forKey:key) != nil else {
   storageMessage="Slot \(selectedSaveSlot) is already empty"
   return
  }
  UserDefaults.standard.removeObject(forKey:key)
  UserDefaults.standard.removeObject(forKey:levelNameKey(for:selectedSaveSlot))
  storageMessage="Deleted saved experiment in slot \(selectedSaveSlot)"
 }
 private func requestSave() {
  if UserDefaults.standard.data(forKey:saveKey(for:selectedSaveSlot)) != nil {
   confirmingOverwrite=true
  } else {
   saveLevel()
  }
 }
 private func requestDelete() {
  if UserDefaults.standard.data(forKey:saveKey(for:selectedSaveSlot)) != nil {
   confirmingDelete=true
  } else {
   storageMessage="Slot \(selectedSaveSlot) is already empty"
  }
 }
 private static let draftKey = "cm.playground.autosave.draft.v1"
 private static let draftNameKey = "cm.playground.autosave.name.v1"
 private var draftData: Data? {
  let document=CMLevelDocument(world:startingLayout ?? world,pins:startingPins ?? pins)
  guard (try? document.makeWorld()) != nil else { return nil }
  return try? JSONEncoder().encode(document)
 }
 private func saveDraft() {
  guard restoredDraft, dragSnapshot == nil, gravityEditSnapshot == nil else { return }
  do {
   guard let data=draftData else { return }
   UserDefaults.standard.set(data,forKey:Self.draftKey)
   UserDefaults.standard.set(levelName,forKey:Self.draftNameKey)
  } catch {
   storageMessage="Could not autosave draft"
  }
 }
 private func restoreDraft() {
  guard !restoredDraft else { return }
  restoredDraft=true
  guard let data=UserDefaults.standard.data(forKey:Self.draftKey) else { return }
  do {
   let loaded=try JSONDecoder().decode(CMLevelDocument.self,from:data).makeWorld()
   world=loaded
   pins=try JSONDecoder().decode(CMLevelDocument.self,from:data).makePins()
   gravityStrength = -loaded.gravity.y
   levelName=UserDefaults.standard.string(forKey:Self.draftNameKey) ?? "Untitled experiment"
   clearExperimentState()
   storageMessage="Recovered your unfinished experiment"
  } catch {
   storageMessage="Autosaved draft is invalid; original layout retained"
  }
 }
 private func exportLevel() {
  do {
   let document=CMLevelDocument(world:startingLayout ?? world)
   _ = try document.makeWorld()
   let encoder=JSONEncoder()
   encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
   exportFile=CMJSONLevelFile(data:try encoder.encode(document))
   exportingLevel=true
  } catch {
   storageMessage="Export failed: \(error.localizedDescription)"
  }
 }
 private func applyPendingImport() {
  guard let imported=pendingImport else { return }
  running=false
  undoStack=[]
  redoStack=[]
  world=imported
  pins=pendingImportPins
  pinUndoStack=[]
  pinRedoStack=[]
  gravityStrength = -imported.gravity.y
  levelName=pendingImportName
  clearExperimentState()
  pendingImport=nil
  pendingImportPins=[]
  saveDraft()
  storageMessage="Imported level successfully"
 }
 private func importLevel(from url:URL) {
  let accessed=url.startAccessingSecurityScopedResource()
  defer { if accessed { url.stopAccessingSecurityScopedResource() } }
  do {
   let data=try Data(contentsOf:url)
   guard data.count <= 1_000_000 else {
    storageMessage="Import failed: file is too large"
    return
   }
   let imported=try JSONDecoder().decode(CMLevelDocument.self,from:data).makeWorld()
   pendingImport=imported
   pendingImportPins=try JSONDecoder().decode(CMLevelDocument.self,from:data).makePins()
   pendingImportName=String(url.deletingPathExtension().lastPathComponent.prefix(60))
   confirmingImport=true
  } catch {
   storageMessage="Import failed: invalid level JSON"
  }
 }
 private func saveLevel() {
  do {
   let layout=startingLayout ?? world
   let document=CMLevelDocument(world:layout)
   _ = try document.makeWorld() // Do not overwrite a good save with an invalid layout.
   let data=try JSONEncoder().encode(document)
   UserDefaults.standard.set(data,forKey:saveKey(for:selectedSaveSlot))
   let cleanName=String(levelName.trimmingCharacters(in:.whitespacesAndNewlines).prefix(60))
   UserDefaults.standard.set(cleanName.isEmpty ? "Untitled experiment" : cleanName,forKey:levelNameKey(for:selectedSaveSlot))
   storageMessage="Experiment saved to slot \(selectedSaveSlot)"
  } catch {
   storageMessage="Save failed: \(error.localizedDescription)"
  }
 }
 private func loadLevel() {
  guard let data=UserDefaults.standard.data(forKey:saveKey(for:selectedSaveSlot)) else {
   storageMessage="Slot \(selectedSaveSlot) is empty"
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
   pins=try JSONDecoder().decode(CMLevelDocument.self,from:data).makePins()
   pinUndoStack=[]
   pinRedoStack=[]
   levelName=UserDefaults.standard.string(forKey:levelNameKey(for:selectedSaveSlot)) ?? "Untitled experiment"
   gravityStrength = -loaded.gravity.y
   clearExperimentState()
   storageMessage="Loaded experiment from slot \(selectedSaveSlot)"
  } catch {
   storageMessage="Saved experiment is invalid"
  }
 }
 private func saveUndo() {
  guard !running else { return }
  undoStack.append(world)
  pinUndoStack.append(pins)
  if pinUndoStack.count > 30 { pinUndoStack.removeFirst() }
  if undoStack.count > 30 { undoStack.removeFirst() }
  redoStack=[]
  pinRedoStack=[]
 }
 private func undo() {
  guard !running,let previous=undoStack.popLast() else { return }
  redoStack.append(world)
  pinRedoStack.append(pins)
  if pinRedoStack.count > 30 { pinRedoStack.removeFirst() }
  pins=pinUndoStack.popLast() ?? []
  if redoStack.count > 30 { redoStack.removeFirst() }
  world=previous
  gravityStrength = -previous.gravity.y
  clearExperimentState()
 }
 private func redo() {
  guard !running,let next=redoStack.popLast() else { return }
  undoStack.append(world)
  pinUndoStack.append(pins)
  if pinUndoStack.count > 30 { pinUndoStack.removeFirst() }
  pins=pinRedoStack.popLast() ?? []
  if undoStack.count > 30 { undoStack.removeFirst() }
  world=next
  gravityStrength = -next.gravity.y
  clearExperimentState()
 }
 private func clearExperimentState() {
  startingLayout=nil
  startingPins=nil
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
  if startingLayout == nil { startingLayout=world; startingPins=pins }
  let before=world.bodies.map(\.position)
  world.step(dt:Self.fixedStep)
  world.applyPins(pins)
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
 private func adjustSelected(_ property: String, by delta: Double) {
  guard !running,let selection else { return }
  switch selection {
  case .ball(let i):
   guard world.bodies.indices.contains(i) else { return }
   let ball=world.bodies[i]
   switch property {
   case "mass":
    let next=min(max((ball.mass+delta)*10,1),1000).rounded()/10
    guard abs(next-ball.mass)>1e-9 else { return }
    saveUndo()
    world.bodies[i].mass=next
   case "radius":
    let next=min(max((ball.radius+delta)*20,2),12).rounded()/20
    guard abs(next-ball.radius)>1e-9,
     ball.position.x>=next,ball.position.x<=Self.worldWidth-next,
     ball.position.y>=next,ball.position.y<=Self.worldHeight-next else { return }
    saveUndo()
    world.bodies[i].radius=next
   case "bounce":
    let next=min(max((ball.restitution+delta)*10,0),10).rounded()/10
    guard abs(next-ball.restitution)>1e-9 else { return }
    saveUndo()
    world.bodies[i].restitution=next
   case "friction":
    let next=min(max((ball.surfaceFriction+delta)*10,0),10).rounded()/10
    guard abs(next-ball.surfaceFriction)>1e-9 else { return }
    saveUndo()
    world.bodies[i].surfaceFriction=next
   default: return
   }
  case .ramp(let i):
   guard property=="friction",world.segments.indices.contains(i) else { return }
   let current=world.segments[i].friction
   let next=min(max((current+delta)*10,0),10).rounded()/10
   guard abs(next-current)>1e-9 else { return }
   saveUndo()
   world.segments[i].friction=next
  }
  startingLayout=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
 }
 private func propertyControl(_ name:String,value:Double,step:Double,key:String) -> some View {
  HStack {
   Text(name).font(.caption).frame(width:75,alignment:.leading)
   Button("−") { adjustSelected(key,by:-step) }
    .accessibilityLabel("Decrease "+name)
   Text(String(format:"%.2f",value)).font(.caption.monospacedDigit()).frame(minWidth:48)
   Button("+") { adjustSelected(key,by:step) }
    .accessibilityLabel("Increase "+name)
  }.buttonStyle(.bordered)
 }
 private func togglePin() {
  guard !running,case .ball(let i)=selection,world.bodies.indices.contains(i) else { return }
  saveUndo()
  if let index=pins.firstIndex(where:{$0.bodyIndex == i}) {
   pins.remove(at:index)
   storageMessage="Ball unpinned"
  } else {
   pins.append(CMPinJoint2D(bodyIndex:i,anchor:world.bodies[i].position))
   storageMessage="Ball pinned in place"
  }
  startingLayout=nil
  startingPins=nil
 }
 private func duplicateSelected() {
  guard !running,let selection else { return }
  let offsets:[SIMD2<Double>]=[
   SIMD2(0.5,0.5),SIMD2(-0.5,0.5),SIMD2(0.5,-0.5),
   SIMD2(-0.5,-0.5),SIMD2(1,0),SIMD2(-1,0),SIMD2(0,1),SIMD2(0,-1)
  ]
  switch selection {
  case .ball(let i):
   guard world.bodies.indices.contains(i),world.bodies.count < 20 else { return }
   let original=world.bodies[i]
   guard let position=offsets.map({ original.position+$0 }).first(where: { p in
    p.x>=original.radius && p.x<=Self.worldWidth-original.radius &&
    p.y>=original.radius && p.y<=Self.worldHeight-original.radius &&
    world.bodies.allSatisfy({ other in
     squaredDistance(p,other.position) >= pow(original.radius+other.radius+0.05,2)
    }) && world.segments.allSatisfy({ segment in
     segmentDistanceSquared(p,segment) >= pow(original.radius+0.05,2)
    })
   }) else {
    storageMessage="No free space to duplicate ball"
    return
   }
   saveUndo()
   var copy=original
   copy.position=position
   copy.velocity = .zero
   copy.angularVelocity=0
   world.bodies.append(copy)
   self.selection = .ball(world.bodies.count-1)
  case .ramp(let i):
   guard world.segments.indices.contains(i),world.segments.count < 12 else { return }
   let original=world.segments[i]
   guard let copy=offsets.map({ offset in
    CMStaticSegment2D(start:original.start+offset,end:original.end+offset,friction:original.friction)
   }).first(where: { candidate in
    [candidate.start,candidate.end].allSatisfy({ p in
     p.x>=0.2 && p.x<=Self.worldWidth-0.2 && p.y>=0.2 && p.y<=Self.worldHeight-0.2
    }) &&
    world.bodies.allSatisfy({ ball in
     segmentDistanceSquared(ball.position,candidate)>=pow(ball.radius+0.12,2)
    }) &&
    world.segments.allSatisfy({ existing in
     segmentDistanceSquared(candidate.start,existing)>0.12*0.12 &&
     segmentDistanceSquared(candidate.end,existing)>0.12*0.12 &&
     segmentDistanceSquared((candidate.start+candidate.end)*0.5,existing)>0.12*0.12 &&
     segmentDistanceSquared(existing.start,candidate)>0.12*0.12 &&
     segmentDistanceSquared(existing.end,candidate)>0.12*0.12
    })
   }) else {
    storageMessage="No free space to duplicate ramp"
    return
   }
   saveUndo()
   world.segments.append(copy)
   self.selection = .ramp(world.segments.count-1)
  }
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
   pins=pins.compactMap { pin in
    if pin.bodyIndex == i { return nil }
    return CMPinJoint2D(bodyIndex:pin.bodyIndex > i ? pin.bodyIndex-1 : pin.bodyIndex,anchor:pin.anchor)
   }
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
      for pin in pins where world.bodies.indices.contains(pin.bodyIndex) {
       let center=screen(pin.anchor,size)
       context.stroke(Path(ellipseIn:CGRect(x:center.x-7,y:center.y-7,width:14,height:14)),with:.color(.purple),lineWidth:3)
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
       if dragChanged { saveDraft() }
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
     if !running && startingLayout == nil { startingLayout=world; startingPins=pins }
     running.toggle()
     lastTick=nil
     dragStart=nil
    }
    .buttonStyle(.borderedProminent)
    Button("Step") { stepOnce() }.disabled(running || reachedGoal)
    .buttonStyle(.bordered)
    Button("Retry") { restartExperiment() }.disabled(startingLayout == nil).buttonStyle(.bordered)
    Button("Reset") { confirmingReset=true }.buttonStyle(.bordered)
   }
   HStack {
    Button("New blank scene") { confirmingClear=true }
    Button("←") { nudgeSelected(dx:-0.25,dy:0) }
    Button("→") { nudgeSelected(dx:0.25,dy:0) }
    Button("↑") { nudgeSelected(dx:0,dy:0.25) }
    Button("↓") { nudgeSelected(dx:0,dy:-0.25) }
   }.buttonStyle(.bordered).disabled(running)
   TextField("Level name",text:$levelName).textFieldStyle(.roundedBorder).disabled(running)
   HStack {
    Button("Export JSON") { exportLevel() }
    Button("Import JSON") { importingLevel=true }
   }.buttonStyle(.bordered).disabled(running)
   HStack {
    Text("Save slot").font(.caption)
    Picker("Save slot",selection:$selectedSaveSlot) {
     ForEach(1...5,id:\.self) { slot in Text("Slot \(slot)").tag(slot) }
    }.pickerStyle(.menu)
    Button("Save") { requestSave() }
    Button("Load") { loadLevel() }
    Button("Delete save") { requestDelete() }
   }.buttonStyle(.bordered)
   if let storageMessage { Text(storageMessage).font(.caption).foregroundStyle(.secondary) }
   HStack {
    Button("Undo") { undo() }.disabled(running || undoStack.isEmpty)
    Button("Redo") { redo() }.disabled(running || redoStack.isEmpty)
   }.buttonStyle(.bordered)
   HStack {
    Button("Add ball") { addBall() }.disabled(running || world.bodies.count >= 20)
    Button("Add ramp") { addRamp() }.disabled(running || world.segments.count >= 12)
    Button("Pin / Unpin") { togglePin() }.disabled(running || { if case .ball = selection { return false }; return true }())
    Button("Duplicate") { duplicateSelected() }.disabled(running || selection == nil)
    Button("Delete") { deleteSelected() }.disabled(running || selection == nil)
   }
   .buttonStyle(.bordered)
   HStack {
    Button("Rotate ↶") { rotateSelectedRamp(by: .pi/12) }
    Button("Rotate ↷") { rotateSelectedRamp(by: -.pi/12) }
   }
   .buttonStyle(.bordered)
   .disabled(running || { if case .ramp = selection { return false }; return true }())
   if let selection {
    VStack(alignment:.leading,spacing:6) {
     Text("Selected object properties").font(.subheadline.bold())
     switch selection {
     case .ball(let i):
      if world.bodies.indices.contains(i) {
       propertyControl("Mass",value:world.bodies[i].mass,step:0.1,key:"mass")
       propertyControl("Radius",value:world.bodies[i].radius,step:0.05,key:"radius")
       propertyControl("Bounce",value:world.bodies[i].restitution,step:0.1,key:"bounce")
       propertyControl("Friction",value:world.bodies[i].surfaceFriction,step:0.1,key:"friction")
      }
     case .ramp(let i):
      if world.segments.indices.contains(i) {
       propertyControl("Friction",value:world.segments[i].friction,step:0.1,key:"friction")
      }
     }
    }.disabled(running)
   }
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
        saveDraft()
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
  .fileExporter(isPresented:$exportingLevel,document:exportFile,contentType:.json,defaultFilename:"crazy-machines-level") { result in
   switch result {
   case .success: storageMessage="Level exported"
   case .failure(let error): storageMessage="Export failed: \(error.localizedDescription)"
   }
  }
  .fileImporter(isPresented:$importingLevel,allowedContentTypes:[.json]) { result in
   switch result {
   case .success(let url): importLevel(from:url)
   case .failure(let error): storageMessage="Import failed: \(error.localizedDescription)"
   }
  }
  .onAppear { restoreDraft() }
  .onChange(of:draftData) { _,_ in
   if !running { saveDraft() }
  }
  .onChange(of:levelName) { _,_ in
   saveDraft()
  }
  .onDisappear { saveDraft() }
  .onChange(of:scenePhase) { _,phase in
   if phase != .active { saveDraft() }
  }
  .confirmationDialog("Replace current experiment?",isPresented:$confirmingImport,titleVisibility:.visible) {
   Button("Import and replace",role:.destructive) { applyPendingImport() }
   Button("Cancel",role:.cancel) { pendingImport=nil }
  } message: {
   Text("The current unsaved editor layout will be replaced. Saved slots are not affected.")
  }
  .confirmationDialog("Reset experiment?",isPresented:$confirmingReset,titleVisibility:.visible) {
   Button("Reset to starter scene",role:.destructive) {
    let previous=world
    reset()
    undoStack.append(previous)
    storageMessage="Reset scene (Undo to restore)"
   }
   Button("Cancel",role:.cancel) {}
  } message: {
   Text("The current scene will be replaced. Undo can restore it.")
  }
  .confirmationDialog("Start a blank scene?",isPresented:$confirmingClear,titleVisibility:.visible) {
   Button("Clear all objects",role:.destructive) { clearScene() }
   Button("Cancel",role:.cancel) {}
  } message: {
   Text("All balls and ramps will be removed. Undo can restore them.")
  }
  .confirmationDialog("Overwrite slot \(selectedSaveSlot)?",isPresented:$confirmingOverwrite,titleVisibility:.visible) {
   Button("Overwrite saved level",role:.destructive) { saveLevel() }
   Button("Cancel",role:.cancel) {}
  } message: {
   Text("The existing experiment in this slot will be replaced.")
  }
  .confirmationDialog("Delete slot \(selectedSaveSlot)?",isPresented:$confirmingDelete,titleVisibility:.visible) {
   Button("Delete saved level",role:.destructive) { deleteSavedLevel() }
   Button("Cancel",role:.cancel) {}
  } message: {
   Text("This saved experiment cannot be recovered.")
  }
 }
}
