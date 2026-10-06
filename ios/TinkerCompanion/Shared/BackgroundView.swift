// One bounded Canvas/Timeline driver for phone effects. Particle count and frame
// cadence are capped; inactive, paused, reduced-motion and low-power states draw
// a static frame without changing the persisted choice. Solid creates no timeline.
import SwiftUI
import UIKit

struct BackgroundView: View {
    let theme: ThemeBundle
    let visible: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var epoch = Date()
    private var animate: Bool { visible && scenePhase == .active && !reduceMotion && !lowPower && !theme.effect.paused }
    var body: some View {
        ZStack {
            theme.color("background")
            if theme.effect.name != "Solid" {
                if animate {
                    TimelineView(.animation(minimumInterval:1.0/30)) { timeline in drawing(time:timeline.date.timeIntervalSince(epoch)) }
                } else { drawing(time:0) }
            }
        }.ignoresSafeArea()
            .onReceive(NotificationCenter.default.publisher(for:.NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
            .onChange(of:animate) { _,active in if active { epoch = Date() } }
            .accessibilityHidden(true).allowsHitTesting(false)
    }
    /// Smooth gradient noise supplies the flow field; deterministic lattice
    /// gradients keep adjacent paths coherent without retaining unbounded trails.
    static func noise(x: Double,y: Double) -> Double {
        let ix = floor(x), iy = floor(y), fx = x-ix, fy = y-iy
        func gradient(_ gx: Double,_ gy: Double,_ dx: Double,_ dy: Double) -> Double {
            let hash = sin(gx*127.1 + gy*311.7)*43758.5453
            let angle = (hash-floor(hash))*Double.pi*2
            return cos(angle)*dx + sin(angle)*dy
        }
        func fade(_ t: Double) -> Double { t*t*t*(t*(t*6-15)+10) }
        let u = fade(fx), v = fade(fy)
        let a = gradient(ix,iy,fx,fy), b = gradient(ix+1,iy,fx-1,fy)
        let c = gradient(ix,iy+1,fx,fy-1), d = gradient(ix+1,iy+1,fx-1,fy-1)
        return (a+(b-a)*u)*(1-v)+(c+(d-c)*u)*v
    }
    /// Deterministic seeds avoid random allocations on each frame and keep static
    /// fallbacks stable; no persistent effect selection is mutated by the driver.
    private func drawing(time: Double) -> some View {
        Canvas { context,size in
            let effect = theme.effect
            let count = min(100,max(8,Int(28 * effect.intensity * effect.quality)))
            let phase = time * effect.speed
            let color = Color(hex:effect.color)
            var points: [CGPoint] = []
            for index in 0..<count {
                let seed = Double(index + 1)
                let x = (seed * 0.61803398875).truncatingRemainder(dividingBy:1)
                let y = (seed * 0.41421356237).truncatingRemainder(dividingBy:1)
                let drift = phase * (0.008 + (seed.truncatingRemainder(dividingBy:7))/700)
                let px = (x + sin(phase * 0.2 + seed) * 0.035) * size.width
                let py = (y + drift).truncatingRemainder(dividingBy:1) * size.height
                let point = CGPoint(x:px,y:py); points.append(point)
                let radius = effect.size * (effect.name == "Dots" ? 1.5 : 3)
                var path = Path()
                switch effect.name {
                case "Rain":
                    path.move(to:point); path.addLine(to:CGPoint(x:px - radius,y:py + radius * 8))
                    context.stroke(path,with:.color(color.opacity(0.3)),lineWidth:1)
                case "Leaves","Petals":
                    let rect = CGRect(x:px,y:py,width:radius * 2,height:radius * 4)
                    context.drawLayer { layer in
                        layer.translateBy(x:px,y:py); layer.rotate(by:.radians(sin(phase * 0.4 + seed)))
                        layer.fill(Path(ellipseIn:CGRect(x:0,y:0,width:rect.width,height:rect.height)),with:.color(color.opacity(0.2)))
                    }
                case "Perlin Flow":
                    path.move(to:point)
                    let angle = Self.noise(x:Double(px)/100,y:Double(py)/100 + phase * 0.05) * Double.pi * 4
                    path.addQuadCurve(to:CGPoint(x:px + cos(angle) * 40,y:py + sin(angle) * 40),control:CGPoint(x:px + cos(angle+0.5)*25,y:py + sin(angle+0.5)*25))
                    context.stroke(path,with:.color(color.opacity(0.22)),lineWidth:effect.size)
                case "Sparkles":
                    path.move(to:CGPoint(x:px-radius * 2,y:py)); path.addLine(to:CGPoint(x:px+radius * 2,y:py))
                    path.move(to:CGPoint(x:px,y:py-radius * 2)); path.addLine(to:CGPoint(x:px,y:py+radius * 2))
                    context.stroke(path,with:.color(color.opacity(0.25 + 0.15 * sin(phase + seed))),lineWidth:1)
                case "Embers":
                    context.fill(Path(ellipseIn:CGRect(x:px,y:size.height - py,width:radius,height:radius * 2)),with:.color(color.opacity(0.35)))
                default:
                    context.fill(Path(ellipseIn:CGRect(x:px,y:py,width:radius,height:radius)),with:.color(color.opacity(0.28)))
                }
            }
            if effect.name == "Synapse" || effect.name == "Constellations" {
                // O(n), bounded adjacency rather than all-pairs particle work.
                for index in 1..<points.count {
                    let a = points[index - 1], b = points[index]
                    if hypot(a.x-b.x,a.y-b.y) < 100 {
                        var path = Path(); path.move(to:a); path.addLine(to:b)
                        context.stroke(path,with:.color(color.opacity(effect.name == "Synapse" ? 0.22 : 0.12)),lineWidth:0.75)
                    }
                }
            }
        }
    }
}
