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
 @State private var springs: [CMSpringJoint2D] = []
 @State private var pivots: [CMPivotJoint2D] = []
 @State private var pivotUndoStack: [[CMPivotJoint2D]] = []
 @State private var pivotRedoStack: [[CMPivotJoint2D]] = []
 @State private var startingPivots: [CMPivotJoint2D]?
 @State private var pendingImportPivots: [CMPivotJoint2D] = []
 @State private var springUndoStack: [[CMSpringJoint2D]] = []
 @State private var springRedoStack: [[CMSpringJoint2D]] = []
 @State private var startingSprings: [CMSpringJoint2D]?
 @State private var springSourceIndex: Int?
 @State private var selectedSpringIndex: Int?
 @State private var dragPinsSnapshot: [CMPinJoint2D]?
 @State private var dragPivotsSnapshot: [CMPivotJoint2D]?
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
 @State private var pendingImportSprings: [CMSpringJoint2D] = []
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
   world.applySprings(springs,dt:Self.fixedStep)
   world.step(dt:Self.fixedStep)
   world.applyPivots(pivots)
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
  guard !world.bodies.isEmpty || !world.segments.isEmpty || !pins.isEmpty || !springs.isEmpty || !pivots.isEmpty else {
   storageMessage="Scene is already empty"
   return
  }
  saveUndo()
  world.bodies=[]
  world.segments=[]
  pins=[]
  springs=[]
  pivots=[]
  selectedSpringIndex=nil
  springSourceIndex=nil
  clearExperimentState()
  saveDraft()
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
   if let pivotIndex=pivots.firstIndex(where:{$0.bodyIndex==i}) {
    let anchor=pivots[pivotIndex].anchor+delta
    guard (0...Self.worldWidth).contains(anchor.x),(0...Self.worldHeight).contains(anchor.y) else {
     storageMessage="Pivot anchor would leave the scene"
     return
    }
   }
   saveUndo()
   if let pivotIndex=pivots.firstIndex(where:{$0.bodyIndex==i}) { pivots[pivotIndex].anchor+=delta }
   world.bodies[i].position=p
   if let pinIndex=pins.firstIndex(where:{$0.bodyIndex == i}) { pins[pinIndex].anchor=p }
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
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
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
  springs=[]
  pivots=[]
  springUndoStack=[]
  pivotUndoStack=[]
  springRedoStack=[]
  pivotRedoStack=[]
  pinUndoStack=[]
  pinRedoStack=[]
  undoStack=[]
  redoStack=[]
  dragSnapshot=nil
  dragPinsSnapshot=nil
  dragPivotsSnapshot=nil
  dragChanged=false
  gravityEditSnapshot=nil
  world.gravity.y = -gravityStrength
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  selectedSpringIndex=nil
  springSourceIndex=nil
  simulationSteps=0
  trails=[]
  saveDraft()
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
  springs=startingSprings ?? springs
  pivots=startingPivots ?? pivots
  selectedSpringIndex=nil
  springSourceIndex=nil
  gravityStrength = -layout.gravity.y
  simulationSteps=0
  trails=[]
  dragStart=nil
  initialSegment=nil
  dragSnapshot=nil
  dragPinsSnapshot=nil
  dragPivotsSnapshot=nil
  dragChanged=false
  saveDraft()
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
  let document=CMLevelDocument(world:startingLayout ?? world,pins:startingPins ?? pins,springs:startingSprings ?? springs,pivots:startingPivots ?? pivots)
  guard (try? document.makePins()) != nil else { return nil }
  return try? JSONEncoder().encode(document)
 }
 private func saveDraft() {
  guard restoredDraft, dragSnapshot == nil, gravityEditSnapshot == nil else { return }
  guard let data=draftData else {
   storageMessage="Could not autosave invalid draft"
   return
  }
  UserDefaults.standard.set(data,forKey:Self.draftKey)
  UserDefaults.standard.set(levelName,forKey:Self.draftNameKey)
 }
 private func restoreDraft() {
  guard !restoredDraft else { return }
  restoredDraft=true
  guard let data=UserDefaults.standard.data(forKey:Self.draftKey) else { return }
  do {
   let document=try JSONDecoder().decode(CMLevelDocument.self,from:data)
   let loaded=try document.makeWorld()
   let loadedPins=try document.makePins()
   let loadedSprings=try document.makeSprings()
   let loadedPivots=try document.makePivots()
   world=loaded
   pins=loadedPins
   springs=loadedSprings
   pivots=loadedPivots
   selectedSpringIndex=nil
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
   let document=CMLevelDocument(world:startingLayout ?? world,pins:startingPins ?? pins,springs:startingSprings ?? springs,pivots:startingPivots ?? pivots)
   _ = try document.makePins()
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
  springs=pendingImportSprings
  pivots=pendingImportPivots
  selectedSpringIndex=nil
  pinUndoStack=[]
  pinRedoStack=[]
  springUndoStack=[]
  pivotUndoStack=[]
  springRedoStack=[]
  pivotRedoStack=[]
  gravityStrength = -imported.gravity.y
  levelName=pendingImportName
  clearExperimentState()
  pendingImport=nil
  pendingImportPins=[]
  pendingImportSprings=[]
  pendingImportPivots=[]
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
   let document=try JSONDecoder().decode(CMLevelDocument.self,from:data)
   let imported=try document.makeWorld()
   let importedPins=try document.makePins()
   let importedSprings=try document.makeSprings()
   let importedPivots=try document.makePivots()
   pendingImport=imported
   pendingImportPins=importedPins
   pendingImportSprings=importedSprings
   pendingImportPivots=importedPivots
   pendingImportName=String(url.deletingPathExtension().lastPathComponent.prefix(60))
   confirmingImport=true
  } catch {
   storageMessage="Import failed: invalid level JSON"
  }
 }
 private func saveLevel() {
  do {
   let layout=startingLayout ?? world
   let document=CMLevelDocument(world:layout,pins:startingPins ?? pins,springs:startingSprings ?? springs,pivots:startingPivots ?? pivots)
   _ = try document.makePins() // Do not overwrite a good save with an invalid layout.
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
   let document=try JSONDecoder().decode(CMLevelDocument.self,from:data)
   let loaded=try document.makeWorld()
   let loadedPins=try document.makePins()
   let loadedSprings=try document.makeSprings()
   let loadedPivots=try document.makePivots()
   running=false
   lastTick=nil
   accumulator=0
   undoStack=[]
   redoStack=[]
   world=loaded
   pins=loadedPins
   springs=loadedSprings
   pivots=loadedPivots
   pinUndoStack=[]
   pinRedoStack=[]
   springUndoStack=[]
  pivotUndoStack=[]
   springRedoStack=[]
  pivotRedoStack=[]
   levelName=UserDefaults.standard.string(forKey:levelNameKey(for:selectedSaveSlot)) ?? "Untitled experiment"
   gravityStrength = -loaded.gravity.y
   clearExperimentState()
   saveDraft()
   storageMessage="Loaded experiment from slot \(selectedSaveSlot)"
  } catch {
   storageMessage="Saved experiment is invalid"
  }
 }
 private func saveUndo() {
  guard !running else { return }
  undoStack.append(world)
  pinUndoStack.append(pins)
  springUndoStack.append(springs)
  pivotUndoStack.append(pivots)
  if springUndoStack.count > 30 { springUndoStack.removeFirst() }
  if pivotUndoStack.count > 30 { pivotUndoStack.removeFirst() }
  if pinUndoStack.count > 30 { pinUndoStack.removeFirst() }
  if undoStack.count > 30 { undoStack.removeFirst() }
  redoStack=[]
  pinRedoStack=[]
  springRedoStack=[]
  pivotRedoStack=[]
 }
 private func undo() {
  guard !running,let previous=undoStack.popLast() else { return }
  redoStack.append(world)
  pinRedoStack.append(pins)
  springRedoStack.append(springs)
  pivotRedoStack.append(pivots)
  if springRedoStack.count > 30 { springRedoStack.removeFirst() }
  if pivotRedoStack.count > 30 { pivotRedoStack.removeFirst() }
  if pinRedoStack.count > 30 { pinRedoStack.removeFirst() }
  pins=pinUndoStack.popLast() ?? []
  springs=springUndoStack.popLast() ?? []
  pivots=pivotUndoStack.popLast() ?? []
  selectedSpringIndex=nil
  if redoStack.count > 30 { redoStack.removeFirst() }
  world=previous
  gravityStrength = -previous.gravity.y
  clearExperimentState()
  saveDraft()
 }
 private func redo() {
  guard !running,let next=redoStack.popLast() else { return }
  undoStack.append(world)
  pinUndoStack.append(pins)
  springUndoStack.append(springs)
  pivotUndoStack.append(pivots)
  if springUndoStack.count > 30 { springUndoStack.removeFirst() }
  if pivotUndoStack.count > 30 { pivotUndoStack.removeFirst() }
  if pinUndoStack.count > 30 { pinUndoStack.removeFirst() }
  pins=pinRedoStack.popLast() ?? []
  springs=springRedoStack.popLast() ?? []
  pivots=pivotRedoStack.popLast() ?? []
  selectedSpringIndex=nil
  if undoStack.count > 30 { undoStack.removeFirst() }
  world=next
  gravityStrength = -next.gravity.y
  clearExperimentState()
  saveDraft()
 }
 private func clearExperimentState() {
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  springSourceIndex=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  selection=nil
  dragStart=nil
  initialSegment=nil
  dragSnapshot=nil
  dragPinsSnapshot=nil
  dragPivotsSnapshot=nil
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
  saveDraft()
 }

 private func stepOnce() {
  guard !running && !reachedGoal else { return }
  if startingLayout == nil { startingLayout=world; startingPins=pins; startingSprings=springs; startingPivots=pivots }
  let before=world.bodies.map(\.position)
  world.applySprings(springs,dt:Self.fixedStep)
  world.step(dt:Self.fixedStep)
  world.applyPivots(pivots)
   world.applyPins(pins)
  recordTrails()
  simulationSteps+=1
  checkGoal(previousPositions:before)
 }
 private func beginDrag(_ point:SIMD2<Double>) {
  guard editMode && !running else { return }
  selection=select(at:point)
  dragSnapshot=selection == nil ? nil : world
  dragPinsSnapshot=selection == nil ? nil : pins
  dragPivotsSnapshot=selection == nil ? nil : pivots
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
   let delta=next-world.bodies[i].position
   world.bodies[i].position=next
   if let pivotIndex=pivots.firstIndex(where:{$0.bodyIndex==i}) {
    let anchor=pivots[pivotIndex].anchor+delta
    if (0...Self.worldWidth).contains(anchor.x) && (0...Self.worldHeight).contains(anchor.y) {
     pivots[pivotIndex].anchor=anchor
    } else { world.bodies[i].position-=delta; return }
   }
   dragChanged=true
   if let pinIndex=pins.firstIndex(where:{$0.bodyIndex == i}) { pins[pinIndex].anchor=next }
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
 private func loadMechanismPreset(_ preset:Int) {
  guard !running else { return }
  var scene=CMPhysicsWorld2D()
  scene.gravity=SIMD2(0,-gravityStrength)
  scene.floorFriction=world.floorFriction
  var newPins:[CMPinJoint2D]=[]
  var newSprings:[CMSpringJoint2D]=[]
  var newPivots:[CMPivotJoint2D]=[]
  let ballA=CMPhysicsBody2D(position:SIMD2(2,3.5),radius:0.25)
  let ballB=CMPhysicsBody2D(position:SIMD2(4,3.5),radius:0.25)
  switch preset {
  case 0: // Pendulum already offset from vertical: gravity creates motion.
   scene.bodies=[CMPhysicsBody2D(position:SIMD2(3.5,3.5),radius:0.25)]
   newPivots=[CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(2.5,4.5),length:sqrt(2))]
  case 1: // Two coupled masses, connected by an elastic spring.
   scene.bodies=[ballA,ballB]
   newSprings=[CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1.3,stiffness:35,damping:3)]
  case 2: // Stationary support with a free mass attached by a spring.
   scene.bodies=[ballA,ballB]
   newPins=[CMPinJoint2D(bodyIndex:0,anchor:ballA.position)]
   newSprings=[CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1.2,stiffness:40,damping:4)]
  case 3: // Two independent swinging arms.
   scene.bodies=[
    CMPhysicsBody2D(position:SIMD2(1.5,3.5),radius:0.25),
    CMPhysicsBody2D(position:SIMD2(5.5,3.5),radius:0.25)
   ]
   newPivots=[
    CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(2.5,4.5),length:sqrt(2)),
    CMPivotJoint2D(bodyIndex:1,anchor:SIMD2(4.5,4.5),length:sqrt(2))
   ]
  case 4: // Inclined ramp launches a rolling ball toward the target.
   scene.bodies=[CMPhysicsBody2D(position:SIMD2(1.1,4.8),radius:0.25)]
   scene.segments=[
    CMStaticSegment2D(start:SIMD2(0.5,4.2),end:SIMD2(3.8,1.6),friction:0.15),
    CMStaticSegment2D(start:SIMD2(3.9,1.4),end:SIMD2(6.5,0.7),friction:0.15)
   ]
  case 5: // Elastic coupling between a pendulum and a free ball.
   scene.bodies=[
    CMPhysicsBody2D(position:SIMD2(2.4,3.4),radius:0.25),
    CMPhysicsBody2D(position:SIMD2(4.4,3.4),radius:0.25)
   ]
   newPivots=[CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(1.5,4.5),length:sqrt(2.02))]
   newSprings=[CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1.4,stiffness:25,damping:2)]
  case 6: // Three hanging masses transfer momentum through collisions.
   scene.bodies=[
    CMPhysicsBody2D(position:SIMD2(2.0,3.7),radius:0.25),
    CMPhysicsBody2D(position:SIMD2(3.2,3.7),radius:0.25),
    CMPhysicsBody2D(position:SIMD2(3.72,3.7),radius:0.25)
   ]
   newPivots=[
    CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(2.6,4.8),length:sqrt(1.57)),
    CMPivotJoint2D(bodyIndex:1,anchor:SIMD2(3.2,4.8),length:1.1),
    CMPivotJoint2D(bodyIndex:2,anchor:SIMD2(3.72,4.8),length:1.1)
   ]
  case 7: // A pinned support suspends two linked masses in series.
   scene.bodies=[
    CMPhysicsBody2D(position:SIMD2(2.5,4.6),radius:0.25),
    CMPhysicsBody2D(position:SIMD2(3.2,3.2),radius:0.25),
    CMPhysicsBody2D(position:SIMD2(4.3,2.6),radius:0.25)
   ]
   newPins=[CMPinJoint2D(bodyIndex:0,anchor:SIMD2(2.5,4.6))]
   newSprings=[
    CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1.1,stiffness:32,damping:2),
    CMSpringJoint2D(firstIndex:1,secondIndex:2,restLength:1.0,stiffness:24,damping:2)
   ]
  case 8: // Cascading ramps redirect a ball through three slopes.
   scene.bodies=[CMPhysicsBody2D(position:SIMD2(0.8,5.3),radius:0.25)]
   scene.segments=[
    CMStaticSegment2D(start:SIMD2(0.4,4.7),end:SIMD2(2.6,3.7),friction:0.12),
    CMStaticSegment2D(start:SIMD2(2.8,2.9),end:SIMD2(5.1,3.6),friction:0.12),
    CMStaticSegment2D(start:SIMD2(4.5,1.7),end:SIMD2(6.6,0.9),friction:0.12)
   ]
  case 9: // A spring connects two independent pendulum arms.
   scene.bodies=[
    CMPhysicsBody2D(position:SIMD2(2.2,3.5),radius:0.25),
    CMPhysicsBody2D(position:SIMD2(4.8,3.5),radius:0.25)
   ]
   newPivots=[
    CMPivotJoint2D(bodyIndex:0,anchor:SIMD2(2.8,4.6),length:sqrt(1.57)),
    CMPivotJoint2D(bodyIndex:1,anchor:SIMD2(4.2,4.6),length:sqrt(1.57))
   ]
   newSprings=[CMSpringJoint2D(firstIndex:0,secondIndex:1,restLength:1.8,stiffness:22,damping:2)]
  case 10: // An elevated launch toward the fixed goal: tune the initial impulse.
   scene.bodies=[
    CMPhysicsBody2D(position:SIMD2(1.1,3.8),velocity:SIMD2(3.0,1.6),radius:0.25)
   ]
   scene.segments=[
    CMStaticSegment2D(start:SIMD2(0.4,3.1),end:SIMD2(2.2,2.8),friction:0.18),
    CMStaticSegment2D(start:SIMD2(4.3,1.1),end:SIMD2(6.5,0.45),friction:0.15)
   ]
  default: return
  }
  let document=CMLevelDocument(world:scene,pins:newPins,springs:newSprings,pivots:newPivots)
  guard (try? document.makeWorld()) != nil,
   (try? document.makePins()) != nil,
   (try? document.makeSprings()) != nil,
   (try? document.makePivots()) != nil else {
   storageMessage="Mechanism preset failed validation"
   return
  }
  saveUndo()
  world=scene
  pins=newPins
  springs=newSprings
  pivots=newPivots
  clearExperimentState()
  saveDraft()
  storageMessage=["Pendulum","Coupled spring","Spring and pin","Double pendulum","Ramp run","Spring pendulum","Collision pendulums","Spring chain","Ramp cascade","Linked pendulums","Target shot"][preset]+" preset loaded (Undo to restore)"
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
  saveDraft()
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
  saveDraft()
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
  saveDraft()
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
 private func selectNextSpring() {
  guard !running,!springs.isEmpty else { return }
  selectedSpringIndex=((selectedSpringIndex ?? -1)+1)%springs.count
  springSourceIndex=nil
  storageMessage="Spring \(selectedSpringIndex!+1) of \(springs.count) selected"
 }
 private func selectPreviousSpring() {
  guard !running,!springs.isEmpty else { return }
  selectedSpringIndex=((selectedSpringIndex ?? 0)+springs.count-1)%springs.count
  springSourceIndex=nil
  storageMessage="Previous spring selected"
 }
 private func removeSelectedSpring() {
  guard !running,let index=selectedSpringIndex,springs.indices.contains(index) else { return }
  saveUndo()
  springs.remove(at:index)
  selectedSpringIndex=springs.isEmpty ? nil : min(index,springs.count-1)
  springSourceIndex=nil
  clearExperimentState()
  saveDraft()
  storageMessage="Spring removed (Undo to restore)"
 }
 private func adjustSpring(_ property: String, by delta: Double) {
  guard !running,let index=selectedSpringIndex,springs.indices.contains(index),
   delta.isFinite else { return }
  var updated=springs[index]
  switch property {
  case "length": updated.restLength=min(10,max(0,updated.restLength+delta))
  case "stiffness": updated.stiffness=min(1000,max(0,updated.stiffness+delta))
  case "damping": updated.damping=min(100,max(0,updated.damping+delta))
  default: return
  }
  guard updated.restLength != springs[index].restLength ||
   updated.stiffness != springs[index].stiffness ||
   updated.damping != springs[index].damping else { return }
  saveUndo()
  springs[index]=updated
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
 }
 private func springControl(_ title: String, value: Double, step: Double, key: String) -> some View {
  HStack {
   Text(title).font(.caption)
   Spacer()
   Text(String(format:"%.2f",value)).font(.caption.monospacedDigit())
   Button("−") { adjustSpring(key,by:-step) }
   Button("+") { adjustSpring(key,by:step) }
  }.buttonStyle(.bordered).disabled(running)
 }
 private func connectSpring() {
  guard !running,case .ball(let index)=selection,world.bodies.indices.contains(index) else { return }
  guard let first=springSourceIndex else {
   springSourceIndex=index
   storageMessage="Select another ball and tap Spring again"
   return
  }
  guard first != index,world.bodies.indices.contains(first) else {
   springSourceIndex=nil
   storageMessage="Choose two different balls"
   return
  }
  guard springs.count < 20 else { storageMessage="Spring limit reached";return }
  guard !springs.contains(where: {
   ($0.firstIndex == first && $0.secondIndex == index) ||
   ($0.firstIndex == index && $0.secondIndex == first)
  }) else {
   springSourceIndex=nil
   storageMessage="These balls are already connected"
   return
  }
  let delta=world.bodies[index].position-world.bodies[first].position
  let distance=sqrt(delta.x*delta.x+delta.y*delta.y)
  guard distance.isFinite,distance > 0.01 else {
   springSourceIndex=nil
   storageMessage="Move balls apart before connecting"
   return
  }
  saveUndo()
  springs.append(CMSpringJoint2D(firstIndex:first,secondIndex:index,restLength:distance))
  selectedSpringIndex=springs.count-1
  springSourceIndex=nil
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  storageMessage="Spring connected"
  saveDraft()
 }
 private func removeSpringsForSelection() {
  guard !running,case .ball(let index)=selection else { return }
  guard springs.contains(where:{$0.firstIndex == index || $0.secondIndex == index}) else {
   storageMessage="No springs on selected ball"
   return
  }
  saveUndo()
  springs.removeAll(where:{$0.firstIndex == index || $0.secondIndex == index})
  selectedSpringIndex=nil
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  storageMessage="Removed selected ball's springs"
  saveDraft()
 }
 private func stopAllBalls() {
  guard !running else { return }
  guard world.bodies.contains(where: {
   $0.velocity.x != 0 || $0.velocity.y != 0 || $0.angularVelocity != 0
  }) else { return }
  saveUndo()
  for index in world.bodies.indices {
   world.bodies[index].velocity=SIMD2<Double>(0,0)
   world.bodies[index].angularVelocity=0
  }
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
  storageMessage="All balls stopped (Undo to restore)"
 }
 private func stopSelectedBall() {
  guard !running,case .ball(let index)=selection,
   world.bodies.indices.contains(index) else { return }
  let velocity=world.bodies[index].velocity
  guard velocity.x != 0 || velocity.y != 0 ||
   world.bodies[index].angularVelocity != 0 else { return }
  saveUndo()
  world.bodies[index].velocity=SIMD2<Double>(0,0)
  world.bodies[index].angularVelocity=0
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
  storageMessage="Ball motion cleared (Undo to restore)"
 }
 private func launchSelectedBall(dx:Double,dy:Double) {
  guard !running,case .ball(let index)=selection,
   world.bodies.indices.contains(index),
   !pins.contains(where:{$0.bodyIndex==index}),
   !pivots.contains(where:{$0.bodyIndex==index}),
   dx.isFinite,dy.isFinite,abs(dx)<=5,abs(dy)<=5 else { return }
  let body=world.bodies[index]
  let velocity=body.velocity+SIMD2<Double>(dx,dy)
  guard velocity.x.isFinite,velocity.y.isFinite,
   abs(velocity.x)<=20,abs(velocity.y)<=20 else {
   storageMessage="Launch speed exceeds safe limit"
   return
  }
  saveUndo()
  world.bodies[index].velocity=velocity
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
  storageMessage="Ball launch velocity adjusted (Undo to restore)"
 }
 private func kickSelectedPivot(speed:Double) {
  guard !running,case .ball(let bodyIndex)=selection,
   let index=pivots.firstIndex(where:{$0.bodyIndex==bodyIndex}) else { return }
  let previous=world
  guard world.kickPivot(pivots[index],speed:speed) else { return }
  // A push is an editor action: keep it undoable and persist the new velocity.
  undoStack.append(previous)
  pinUndoStack.append(pins)
  springUndoStack.append(springs)
  pivotUndoStack.append(pivots)
  if undoStack.count>30 { undoStack.removeFirst() }
  if pinUndoStack.count>30 { pinUndoStack.removeFirst() }
  if springUndoStack.count>30 { springUndoStack.removeFirst() }
  if pivotUndoStack.count>30 { pivotUndoStack.removeFirst() }
  redoStack=[]
  pinRedoStack=[]
  springRedoStack=[]
  pivotRedoStack=[]
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
  storageMessage=speed>0 ? "Pendulum pushed counterclockwise" : "Pendulum pushed clockwise"
 }
 private func adjustPivotAnchor(dx:Double,dy:Double) {
  guard !running,case .ball(let bodyIndex)=selection,
   let index=pivots.firstIndex(where:{$0.bodyIndex==bodyIndex}) else { return }
  let proposed=pivots[index].anchor+SIMD2(dx,dy)
  guard proposed.x.isFinite,proposed.y.isFinite,
   (0...Self.worldWidth).contains(proposed.x),
   (0...Self.worldHeight).contains(proposed.y) else {
   storageMessage="Pivot anchor outside scene"
   return
  }
  let offset=world.bodies[bodyIndex].position-proposed
  let length=sqrt(offset.x*offset.x+offset.y*offset.y)
  guard length.isFinite,(0.01...10).contains(length) else {
   storageMessage="Pivot length outside allowed range"
   return
  }
  saveUndo()
  pivots[index].anchor=proposed
  pivots[index].length=length
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
 }
 private func adjustPivotLength(by delta:Double) {
  guard !running,case .ball(let bodyIndex)=selection,
   let index=pivots.firstIndex(where:{$0.bodyIndex==bodyIndex}),
   delta.isFinite else { return }
  let current=pivots[index]
  let next=min(10,max(0.01,current.length+delta))
  guard abs(next-current.length)>1e-9 else { return }
  let body=world.bodies[bodyIndex]
  let offset=body.position-current.anchor
  let distance=sqrt(offset.x*offset.x+offset.y*offset.y)
  guard distance.isFinite,distance>1e-9 else { return }
  let proposed=current.anchor+offset*(next/distance)
  guard proposed.x>=body.radius,proposed.x<=Self.worldWidth-body.radius,
   proposed.y>=body.radius,proposed.y<=Self.worldHeight-body.radius,
   world.bodies.enumerated().allSatisfy({ entry in
    entry.offset==bodyIndex || squaredDistance(proposed,entry.element.position)>=pow(body.radius+entry.element.radius+0.02,2)
   }),
   world.segments.allSatisfy({ segment in
    segmentDistanceSquared(proposed,segment)>=pow(body.radius+0.02,2)
   }) else {
   storageMessage="Pivot resize blocked by boundary or object"
   return
  }
  saveUndo()
  pivots[index].length=next
  world.bodies[bodyIndex].position=proposed
  world.bodies[bodyIndex].velocity = .zero
  world.bodies[bodyIndex].angularVelocity=0
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
 }
 private func togglePivot() {
  guard !running,case .ball(let index)=selection,world.bodies.indices.contains(index) else { return }
  if let existing=pivots.firstIndex(where:{$0.bodyIndex==index}) {
   saveUndo()
   pivots.remove(at:existing)
   storageMessage="Pivot removed"
  } else {
   guard !pins.contains(where:{$0.bodyIndex==index}) else {
    storageMessage="Unpin ball before adding a pivot"
    return
   }
   let position=world.bodies[index].position
   // Put the pivot above the ball so gravity starts a hanging pendulum.
   let horizontal=position.x < Self.worldWidth*0.5 ? 0.6 : -0.6
   let anchor=SIMD2(position.x+horizontal,min(Self.worldHeight,position.y+0.8))
   let delta=position-anchor
   let length=sqrt(delta.x*delta.x+delta.y*delta.y)
   guard length >= 0.01,(0...Self.worldWidth).contains(anchor.x),
    (0...Self.worldHeight).contains(anchor.y) else {
    storageMessage="Not enough room for pivot"; return
   }
   saveUndo()
   pivots.append(CMPivotJoint2D(bodyIndex:index,anchor:anchor,length:length))
   storageMessage="Pivot added"
  }
  startingLayout=nil
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
 }
 private func togglePin() {
  guard !running,case .ball(let i)=selection,world.bodies.indices.contains(i) else { return }
  if pins.firstIndex(where:{$0.bodyIndex == i}) == nil && pivots.contains(where:{$0.bodyIndex == i}) {
   storageMessage="Remove pivot before pinning"
   return
  }
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
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
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
   // A duplicated disk starts free, even if its source was pinned.
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
  startingPins=nil
  startingSprings=nil
  startingPivots=nil
  reachedGoal=false
  simulationSteps=0
  trails=[]
  saveDraft()
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
   selectedSpringIndex=nil
   springs=springs.compactMap { spring in
    if spring.firstIndex == i || spring.secondIndex == i { return nil }
    var next=spring
    if next.firstIndex > i { next.firstIndex-=1 }
    if next.secondIndex > i { next.secondIndex-=1 }
    return next
   }
   pivots=pivots.compactMap { pivot in
    if pivot.bodyIndex == i { return nil }
    var next=pivot
    if next.bodyIndex > i { next.bodyIndex-=1 }
    return next
   }
   pins=pins.compactMap { pin in
    if pin.bodyIndex == i { return nil }
    return CMPinJoint2D(bodyIndex:pin.bodyIndex > i ? pin.bodyIndex-1 : pin.bodyIndex,anchor:pin.anchor)
   }
  case .ramp(let i):
   world.segments.remove(at:i)
  }
  self.selection=nil
  springSourceIndex=nil
  trails=[]
  startingSprings=nil
  startingPivots=nil
  startingPins=nil
  startingLayout=nil
  reachedGoal=false
  simulationSteps=0
  saveDraft()
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
      for (springIndex,spring) in springs.enumerated() where world.bodies.indices.contains(spring.firstIndex) && world.bodies.indices.contains(spring.secondIndex) {
       var connector=Path()
       connector.move(to:screen(world.bodies[spring.firstIndex].position,size))
       connector.addLine(to:screen(world.bodies[spring.secondIndex].position,size))
       context.stroke(connector,with:.color(selectedSpringIndex == springIndex ? .yellow : .mint),style:StrokeStyle(lineWidth:selectedSpringIndex == springIndex ? 5 : 3,dash:[6,4]))
      }
      for pivot in pivots where world.bodies.indices.contains(pivot.bodyIndex) {
       let anchor=screen(pivot.anchor,size)
       let body=screen(world.bodies[pivot.bodyIndex].position,size)
       var rod=Path()
       rod.move(to:anchor)
       rod.addLine(to:body)
       context.stroke(rod,with:.color(.orange),lineWidth:3)
       context.fill(Path(ellipseIn:CGRect(x:anchor.x-5,y:anchor.y-5,width:10,height:10)),with:.color(.orange))
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
        pinUndoStack.append(dragPinsSnapshot ?? pins)
        springUndoStack.append(springs)
        pivotUndoStack.append(dragPivotsSnapshot ?? pivots)
        if springUndoStack.count > 30 { springUndoStack.removeFirst() }
  if pivotUndoStack.count > 30 { pivotUndoStack.removeFirst() }
        if pinUndoStack.count > 30 { pinUndoStack.removeFirst() }
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack=[]
        pinRedoStack=[]
        springRedoStack=[]
  pivotRedoStack=[]
       }
       dragSnapshot=nil
       dragPinsSnapshot=nil
       dragPivotsSnapshot=nil
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
    Button("Pendulum preset") { loadMechanismPreset(0) }.disabled(running)
    Button("Spring preset") { loadMechanismPreset(1) }.disabled(running)
    Button("Support preset") { loadMechanismPreset(2) }.disabled(running)
    Button("Dual pivots") { loadMechanismPreset(3) }.disabled(running)
    Button("Ramp run") { loadMechanismPreset(4) }.disabled(running)
    Button("Spring pendulum") { loadMechanismPreset(5) }.disabled(running)
    Button("Collision pendulums") { loadMechanismPreset(6) }.disabled(running)
    Button("Spring chain") { loadMechanismPreset(7) }.disabled(running)
    Button("Ramp cascade") { loadMechanismPreset(8) }.disabled(running)
    Button("Linked pendulums") { loadMechanismPreset(9) }.disabled(running)
    Button("Target shot") { loadMechanismPreset(10) }.disabled(running)
    Button("Stop all balls") { stopAllBalls() }.disabled(running)
    Button("Add ball") { addBall() }.disabled(running || world.bodies.count >= 20)
    Button("Add ramp") { addRamp() }.disabled(running || world.segments.count >= 12)
    Button("Spring") { connectSpring() }.disabled(running)
    Button("Remove springs") { removeSpringsForSelection() }.disabled(running)
    Button("Select spring") { selectNextSpring() }.disabled(running || springs.isEmpty)
    Button("Previous spring") { selectPreviousSpring() }.disabled(running || springs.isEmpty)
    Button("Delete spring") { removeSelectedSpring() }.disabled(running || selectedSpringIndex == nil)
    Button("Pivot / Unpivot") { togglePivot() }.disabled(running || { if case .ball = selection { return false }; return true }())
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
   if let springIndex=selectedSpringIndex,springs.indices.contains(springIndex) {
    VStack(alignment:.leading,spacing:6) {
     Text("Spring \(springIndex+1) properties").font(.subheadline.bold())
     springControl("Rest length",value:springs[springIndex].restLength,step:0.1,key:"length")
     springControl("Stiffness",value:springs[springIndex].stiffness,step:5,key:"stiffness")
     springControl("Damping",value:springs[springIndex].damping,step:0.5,key:"damping")
    }
   }
   if case .ball(let bodyIndex)=selection,
    let pivotIndex=pivots.firstIndex(where:{$0.bodyIndex==bodyIndex}) {
    VStack(alignment:.leading,spacing:6) {
     Text("Pivot anchor and length").font(.subheadline.bold())
     Text("Anchor X: "+String(format:"%.2f",pivots[pivotIndex].anchor.x)+"  Y: "+String(format:"%.2f",pivots[pivotIndex].anchor.y)).font(.caption.monospacedDigit())
     HStack {
      Button("Anchor ←") { adjustPivotAnchor(dx:-0.1,dy:0) }
      Button("Anchor →") { adjustPivotAnchor(dx:0.1,dy:0) }
      Button("Anchor ↑") { adjustPivotAnchor(dx:0,dy:0.1) }
      Button("Anchor ↓") { adjustPivotAnchor(dx:0,dy:-0.1) }
     }.buttonStyle(.bordered)
     HStack {
      Button("Swing ↶") { kickSelectedPivot(speed:1.5) }
      Button("Swing ↷") { kickSelectedPivot(speed:-1.5) }
     }.buttonStyle(.bordered)
     HStack {
      Text("Length: "+String(format:"%.2f",pivots[pivotIndex].length)).font(.caption.monospacedDigit())
      Button("−") { adjustPivotLength(by:-0.1) }
      Button("+") { adjustPivotLength(by:0.1) }
     }.buttonStyle(.bordered)
    }.disabled(running)
   }
   if let selection {
    VStack(alignment:.leading,spacing:6) {
     Text("Selected object properties").font(.subheadline.bold())
     switch selection {
     case .ball(let i):
      if world.bodies.indices.contains(i) {
       if !pins.contains(where:{$0.bodyIndex==i}) &&
        !pivots.contains(where:{$0.bodyIndex==i}) {
        HStack {
         Button("Launch ←") { launchSelectedBall(dx:-1.5,dy:0) }
         Button("Launch →") { launchSelectedBall(dx:1.5,dy:0) }
         Button("Launch ↑") { launchSelectedBall(dx:0,dy:1.5) }
         Button("Launch ↓") { launchSelectedBall(dx:0,dy:-1.5) }
        }.buttonStyle(.bordered).disabled(running)
       }
       Button("Stop ball") { stopSelectedBall() }.disabled(running)
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
        pinUndoStack.append(pins)
        springUndoStack.append(springs)
        pivotUndoStack.append(pivots)
        if undoStack.count > 30 { undoStack.removeFirst() }
        if pinUndoStack.count > 30 { pinUndoStack.removeFirst() }
        if springUndoStack.count > 30 { springUndoStack.removeFirst() }
        if pivotUndoStack.count > 30 { pivotUndoStack.removeFirst() }
        redoStack=[]
        pinRedoStack=[]
        springRedoStack=[]
        pivotRedoStack=[]
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
    let previousPins=pins
    let previousSprings=springs
    reset()
    undoStack.append(previous)
    pinUndoStack.append(previousPins)
    springUndoStack.append(previousSprings)
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
