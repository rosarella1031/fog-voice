import SwiftUI

// 和圆点环同一家族：都是细小的点或线，在 32×32 里画，读同一组动画值。
// 区别在“点怎么排、怎么动”：
//   向日葵 —— 点按黄金角排成螺旋，像花盘；
//   萤火   —— 点散成一团，各自慢慢漂，搜索时被卷成一个旋涡；
//   轨道   —— 三条细椭圆轨道交叉，每条上有一颗珠子在跑。

private let dotColor = Color(hex: 0xC4DDFA)
private let coreGradient = Gradient(colors: [Color(hex: 0xA8C8F1), Color(hex: 0x749BCE)])

/// 收起时中间那颗实心点（和圆点环一样：展开时缩小并淡出）
private func drawCore(_ ctx: GraphicsContext, expansion e: Double, keep: Double = 0) {
    let r = mix(4, mix(2, 2.2, keep), span(e, 0, 0.5))
    var c = ctx
    c.opacity = max(keep, mix(1, 0, smooth(span(e, 0.17, 0.57))))
    c.fill(Path(ellipseIn: CGRect(x: 16 - r, y: 16 - r, width: r * 2, height: r * 2)),
           with: .radialGradient(coreGradient, center: CGPoint(x: 16, y: 16), startRadius: 0, endRadius: r))
}

private func dot(_ ctx: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double) {
    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(dotColor))
}

// MARK: - 向日葵

/// 34 颗点按黄金角（137.5°）一圈圈排开，越往外越大。
/// 说话时一道涟漪从中心往外推；搜索时整盘慢慢转，亮度沿螺旋流动。
struct PhylloAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32
    private let count = 34
    private let golden = 137.508 * Double.pi / 180

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, canvas in
                ctx.scaleBy(x: canvas.width / 32, y: canvas.height / 32)
                let e = motion.expansion.value(at: t)
                let g = motion.gather.value(at: t)
                let v = motion.voice.value(at: t)
                let spin = motion.orbit(at: t) * .pi
                drawCore(ctx, expansion: e)

                var field = ctx
                let reveal = smooth(span(e, 0.15, 0.7))
                guard reveal > 0.001 else { return }
                let c = 13.2 / sqrt(Double(count))
                for i in 0..<count {
                    let k = Double(i) / Double(count)
                    var r = c * sqrt(Double(i) + 0.5)
                    let ripple = sin(r * 0.9 - t * 9) * v
                    r *= e * (1 + 0.1 * ripple)
                    let a = Double(i) * golden + spin * g
                    let wave = (1 - cos(2 * .pi * (motion.orbit(at: t) * 2 - k * 3))) / 2
                    field.opacity = reveal * mix(1, 0.35 + 0.65 * wave, g)
                    dot(&field, 16 + r * cos(a), 16 + r * sin(a), mix(0.45, 1.25, k) * (1 + 0.25 * max(0, ripple)))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 萤火

/// 18 颗点散成一团，各自绕着中心慢慢漂、一闪一闪。
/// 说话时整团随音量胀缩；搜索时点被拉到同一个半径上，卷成旋涡。
struct FireflyAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32

    private struct Mote { let angle, radius, speed, phase, size: Double }
    private static let motes: [Mote] = (0..<18).map { i in
        // 固定的伪随机，每次打开都一样
        func r(_ k: Int) -> Double { let x = sin(Double(i * 12 + k) * 91.7) * 43758.5453; return x - floor(x) }
        // 角度先均匀分开再加一点抖动，不然伪随机会让点挤在一边
        return Mote(angle: (Double(i) + 0.7 * r(1)) / 18 * 2 * .pi, radius: 5 + 8 * r(2), speed: 0.5 + r(3),
                    phase: r(4) * 2 * .pi, size: 0.7 + 0.7 * r(5))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, canvas in
                ctx.scaleBy(x: canvas.width / 32, y: canvas.height / 32)
                let e = motion.expansion.value(at: t)
                let g = motion.gather.value(at: t)
                let v = motion.voice.value(at: t)
                let swirl = motion.orbit(at: t) * 2 * .pi
                drawCore(ctx, expansion: e)

                var field = ctx
                let reveal = smooth(span(e, 0.15, 0.7))
                guard reveal > 0.001 else { return }
                for (i, m) in Self.motes.enumerated() {
                    let drift = 1.3 * sin(t * 0.8 * m.speed + m.phase)
                    let breath = 1 + 0.28 * v * sin(t * 7 + Double(i))
                    let loose = (m.radius + drift) * breath
                    let ring = 11 + 1.2 * sin(t * 3 + Double(i))
                    let r = e * mix(loose, ring, 0.85 * g)
                    let a = m.angle + t * 0.3 * m.speed + swirl * g * (0.6 + 0.4 * m.speed)
                    field.opacity = reveal * (0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.2 * m.speed + m.phase)))
                    dot(&field, 16 + r * cos(a), 16 + r * sin(a), m.size)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 轨道

/// 三条细椭圆轨道互成 60°，中间留一颗小核。每条轨道上一颗珠子在跑。
/// 说话时轨道随音量“鼓起来”（短轴变长）；搜索时珠子加速、轨道整体慢慢转。
struct OrbitAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, canvas in
                ctx.scaleBy(x: canvas.width / 32, y: canvas.height / 32)
                let e = motion.expansion.value(at: t)
                let g = motion.gather.value(at: t)
                let v = motion.voice.value(at: t)
                let orbit = motion.orbit(at: t)
                drawCore(ctx, expansion: e, keep: smooth(span(e, 0.3, 1)))

                let reveal = smooth(span(e, 0.15, 0.7))
                guard reveal > 0.001 else { return }
                let turn = t * 0.25 + orbit * .pi * g
                for k in 0..<3 {
                    let tilt = Double(k) * .pi / 3 + turn
                    let rx = 12.5 * e
                    let ry = (4.2 + 3.2 * v * (0.6 + 0.4 * sin(t * 6 + Double(k) * 2))) * e
                    var ring = ctx
                    ring.translateBy(x: 16, y: 16)
                    ring.rotate(by: .radians(tilt))
                    ring.opacity = reveal * 0.45
                    ring.stroke(Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)),
                                with: .color(dotColor), lineWidth: 0.6)
                    // 珠子：搜索时跑得更快
                    let b = t * 1.3 + Double(k) * 2.1 + orbit * 4 * .pi * g
                    var bead = ring
                    bead.opacity = reveal
                    dot(&bead, rx * cos(b), ry * sin(b), 1.25)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 花环：圆环的点开成花，再收回圆环

/// 48 颗点先排成一个圆环（和圆点环一样），之后每换一个状态就开成一种花，最后收回圆环：
///   聆听 —— 五瓣樱花，粉色，花瓣随说话音量张开；
///   搜索 —— 八瓣雏菊，瓣尖白、瓣根金黄，慢慢转，亮度沿着花瓣流动；
///   核对 —— 三瓣三色堇，瓣尖淡紫、瓣根深紫；
///   出结果 / 待机 —— 回到五瓣樱花，开得浅一点、安静一点（不是圆圈）；
///   待机时整朵花缩到一半、颜色压深一点，放在浅灰圆底的按钮里；点了之后圆底淡出。
/// 每颗点在花上的“角度”固定不变，只改它离中心的距离，所以变形时点不会在轮廓上滑来滑去。
/// 花型：r = R × (1 − 深度 × (1 − |cos(瓣数·θ/2)|^0.8))，深度为 0 就是圆。
/// 颜色：每颗点按它在花瓣上的位置取色——瓣尖一种颜色、瓣根一种颜色，形状和颜色一起补间。
struct BloomAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32
    @State private var morph = Morph()

    private static let count = 48 // 8 瓣时每瓣 6 颗，花瓣轮廓才读得出来
    private static let ringRadius = 13.0

    private typealias RGB = SIMD3<Double>
    private static func rgb(_ hex: UInt32) -> RGB {
        RGB(Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF)) / 255
    }

    private struct Flower {
        var k: Double, depth: Double, voiceDepth = 0.0
        /// 瓣根（花瓣之间的凹处）和瓣尖的颜色
        var base: RGB, tip: RGB

        /// 0 = 瓣根，1 = 瓣尖
        func profile(at angle: Double) -> Double { pow(abs(cos(k * angle / 2)), 0.8) }

        func radius(at angle: Double, voice: Double) -> Double {
            let d = depth + voiceDepth * voice
            return BloomAgentView.ringRadius * (1 - d * (1 - profile(at: angle)))
        }

        func color(at angle: Double) -> RGB {
            depth == 0 ? tip : base + (tip - base) * profile(at: angle)
        }
    }

    /// 静止时的样子：五瓣樱花，比聆听时开得稍浅，不随声音动
    private static let rest = Flower(k: 5, depth: 0.3, base: rgb(0xF27BA6), tip: rgb(0xFFE3EE))
    private static let sakura = Flower(k: 5, depth: 0.22, voiceDepth: 0.45, base: rgb(0xF27BA6), tip: rgb(0xFFE3EE))
    private static let daisy = Flower(k: 8, depth: 0.62, base: rgb(0xFFC23D), tip: rgb(0xFFFFFF))
    private static let pansy = Flower(k: 3, depth: 0.64, base: rgb(0x6B4FD8), tip: rgb(0xDCCBFF))

    private static func flower(for state: AgentState) -> Flower {
        switch state {
        case .resting, .ready: rest
        case .listening: sakura
        case .searching: daisy
        case .reviewing: pansy
        }
    }

    /// 记住“从哪个样子变过来”：状态一变，就把当前每颗点的半径和颜色存下来，再往新花补间
    private final class Morph {
        var seen: AgentState = .resting
        var fromR = BloomAgentView.restRadii
        var lastR = BloomAgentView.restRadii
        var fromC = BloomAgentView.restColors
        var lastC = BloomAgentView.restColors
        var start = 0.0
    }

    private static let restRadii = (0..<count).map { rest.radius(at: Double($0) / Double(count) * 2 * .pi, voice: 0) }
    private static let restColors = (0..<count).map { rest.color(at: Double($0) / Double(count) * 2 * .pi) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, canvas in
                ctx.scaleBy(x: canvas.width / 32, y: canvas.height / 32)
                let e = motion.expansion.value(at: t)
                let g = motion.gather.value(at: t)
                let v = motion.voice.value(at: t)
                let orbit = motion.orbit(at: t)
                // 待机时不收成一个点，而是缩成一半大小的一朵小花放在按钮里
                let scale = mix(0.5, 1, e)
                // 待机时小花在浅灰圆底上，浅粉的瓣尖会看不见；收起时整体压深一点
                let deep = Self.rgb(0xD2508A)

                if motion.state != morph.seen {
                    morph.seen = motion.state
                    morph.fromR = morph.lastR
                    morph.fromC = morph.lastC
                    morph.start = t
                }
                let target = Self.flower(for: motion.state)
                let blend = podcastCurve(clamp01((t - morph.start) / 0.75))

                var field = ctx
                let rot = t * 0.18 + orbit * .pi * g
                // 点多了要小一点，不然会连成一条实线；缩小成按钮里的小花时点也跟着变小
                let dotR = mix(0.92, 1.18, v) * mix(0.62, 1, e)

                for i in 0..<Self.count {
                    let base = Double(i) / Double(Self.count) * 2 * .pi
                    let r = mix(morph.fromR[i], target.radius(at: base, voice: v), blend)
                    let c = morph.fromC[i] + (target.color(at: base) - morph.fromC[i]) * blend
                    morph.lastR[i] = r
                    morph.lastC[i] = c
                    let a = base + rot
                    let wave = (1 - cos(2 * .pi * (orbit * 2 - Double(i) / Double(Self.count) * 2))) / 2
                    field.opacity = mix(1, 0.7 + 0.3 * wave, g)
                    let x = 16 + r * scale * cos(a), y = 16 + r * scale * sin(a)
                    field.fill(Path(ellipseIn: CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)),
                               with: .color({ let d = c + (deep - c) * (1 - e) * 0.75; return Color(red: d.x, green: d.y, blue: d.z) }()))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
