import SwiftUI

/// Interactive, asset-free mechanics sandbox using the existing 2D physics engine.
struct CMPlaygroundView: View {
 @State private var world = CMPlaygroundView.makeWorld()
 @State private var running = false
 @State private var lastTick: Date?
 @State private var accumulator = 0.0
 @State private var draggingBall: Int?
 private static let fixedStep = 1.0 / 120.0
 private static func makeWorld() -> CMPhysicsWorld2D {
  var w=CMPhysicsWorld2D()
  w.floorY=0
  w.floorFriction=0.4
  w.segments=[CMStaticSegment2D(start:SIMD2(0.8,2.2),end:SIMD2(5.6,0.8),friction:0.2)]
  w.bodies=[CMPhysicsBody2D(position:SIMD2(1.2,4.5),radius:0.28,restitution:0.5,surfaceFriction:0.5)]
  return w
 }
 var body: some View {
  VStack(spacing:12) {
   Text("Mechanics playground").font(.headline)
   Text("Drop the ball onto the ramp").font(.caption).foregroundStyle(.secondary)
   GeometryReader { geometry in
   TimelineView(.animation(minimumInterval:1.0/60.0,paused:!running)) { timeline in
    Canvas { context,size in
     let scale=min(size.width/7,size.height/6)
     func point(_ p:SIMD2<Double>)->CGPoint {
      CGPoint(x:CGFloat(p.x)*scale,y:size.height-CGFloat(p.y)*scale)
     }
     let floor=point(SIMD2(0,world.floorY))
     var floorPath=Path()
     floorPath.move(to:CGPoint(x:0,y:floor.y))
     floorPath.addLine(to:CGPoint(x:size.width,y:floor.y))
     context.stroke(floorPath,with:.color(.gray),lineWidth:4)
     for segment in world.segments {
      var path=Path()
      path.move(to:point(segment.start))
      path.addLine(to:point(segment.end))
      context.stroke(path,with:.color(.orange),style:StrokeStyle(lineWidth:8,lineCap:.round))
     }
     for ball in world.bodies {
      let center=point(ball.position)
      let r=CGFloat(ball.radius)*scale
      context.fill(Path(ellipseIn:CGRect(x:center.x-r,y:center.y-r,width:2*r,height:2*r)),with:.color(.cyan))
     }
    }
    .background(Color.black.opacity(0.85),in:RoundedRectangle(cornerRadius:14))
    .contentShape(Rectangle())
    .gesture(DragGesture(minimumDistance:0)
     .onChanged { gesture in
      guard !running else { return }
      let scale=min(geometry.size.width/7,geometry.size.height/6)
      guard scale > 0 else { return }
      let position=SIMD2<Double>(Double(gesture.location.x/scale),Double((geometry.size.height-gesture.location.y)/scale))
      if draggingBall == nil {
       draggingBall=world.bodies.indices.first { index in
        let d=world.bodies[index].position-position
        return d.x*d.x+d.y*d.y < 0.7*0.7
       }
      }
      guard let index=draggingBall else { return }
      let radius=world.bodies[index].radius
      world.bodies[index].position=SIMD2(min(max(position.x,radius),6.8),max(position.y,radius))
      world.bodies[index].velocity = .zero
      world.bodies[index].angularVelocity=0
     }
     .onEnded { _ in draggingBall=nil })
    .onChange(of:timeline.date) { _,now in
     guard running else { return }
     guard let previous=lastTick else { lastTick=now;return }
     let elapsed=min(max(now.timeIntervalSince(previous),0),0.1)
     lastTick=now
     accumulator+=elapsed
     var steps=0
     while accumulator >= Self.fixedStep && steps < 12 {
      world.step(dt:Self.fixedStep)
      accumulator-=Self.fixedStep
      steps+=1
     }
    }
   }
   }
   .frame(height:350)
   Text("Pause to drag balls into position").font(.caption2).foregroundStyle(.secondary)
   HStack {
    Button(running ? "Pause" : "Run") {
     running.toggle()
     lastTick=nil
    }
    .buttonStyle(.borderedProminent)
    Button("Reset") {
     running=false
     world=Self.makeWorld()
     lastTick=nil
     accumulator=0
     draggingBall=nil
    }
    .buttonStyle(.bordered)
    Button("Add ball") {
     if world.bodies.count < 20 {
      let x=1.0+Double(world.bodies.count % 5)*0.65
      world.bodies.append(CMPhysicsBody2D(position:SIMD2(x,5),radius:0.23,restitution:0.45))
     }
    }
    .buttonStyle(.bordered)
   }
  }
  .padding()
 }
}
