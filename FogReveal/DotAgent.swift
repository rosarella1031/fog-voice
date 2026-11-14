import SwiftUI

/// 小助手的状态（与原组件 AgentState 一致）
enum AgentState { case resting, listening, searching, reviewing, ready }

/// 驱动 24 个点的几组动画值。不是 @Observable：画面由 TimelineView 每帧重画，直接读当前值即可。
final class AgentMotion {
    private(set) var state: AgentState = .resting
    var expansion = Tween()        // 0 = 一个实心点，1 = 散开成一圈
    var gather = CriticalSpring()  // 搜索时把点拉到内外两条弧上
    var voice = VoiceEnvelope()    // 假的说话音量
    private var orbitStart: Double?
    private var orbitFrozen = 0.0

    func orbit(at t: Double) -> Double {
        guard let orbitStart else { return orbitFrozen }
        return ((t - orbitStart) / 2.05).truncatingRemainder(dividingBy: 1)
    }

    func set(_ new: AgentState, at t: Double = now()) {
        let wasExpanded = state != .resting, expanded = new != .resting
        if wasExpanded != expanded {
            expansion.retarget(expanded ? 1 : 0, at: t, duration: expanded ? 0.7 : 0.5)
        }
        gather.retarget(new == .searching ? 1 : 0, at: t)

        let inSearch = new == .searching || new == .reviewing
        if inSearch, orbitStart == nil { orbitStart = t }
        if !inSearch, orbitStart != nil { orbitFrozen = orbit(at: t); orbitStart = nil }

        voice.start = new == .listening ? t : nil
        state = new
    }
}

/// 24 个点：偶数在内圈，奇数在外圈。每个点有“弧线位置”和“扫过位置”两个目标。
private struct AgentDot {
    let index: Int, angle: Double
    let arc: CGPoint, sweep: CGPoint
}

private func dotPoint(_ angle: Double, _ radius: Double) -> CGPoint {
    CGPoint(x: 16 + radius * cos(angle), y: 16 + radius * sin(angle))
}

private let agentDots: [AgentDot] = (0..<24).map { i in
    let angle = Double(i) * .pi / 12
    let inner = i % 2 == 0
    return AgentDot(
        index: i, angle: angle,
        arc: dotPoint(angle + (inner ? 0.48 : -0.23), inner ? 8.2 : 13.6),
        sweep: dotPoint(angle + (inner ? 0.7 : -0.34), inner ? 9.1 : 13.5)
    )
}

/// 在 32×32 的坐标里画，和原组件的 SVG viewBox 相同
struct DotAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32

    private static let dotColor = Color(hex: 0xC4DDFA)
    private static let core = Gradient(colors: [Color(hex: 0xA8C8F1), Color(hex: 0x749BCE)])

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, canvasSize in
                ctx.scaleBy(x: canvasSize.width / 32, y: canvasSize.height / 32)
                let e = motion.expansion.value(at: t)
                let g = motion.gather.value(at: t)
                let orbit = motion.orbit(at: t)
                let breath = motion.voice.value(at: t)

                // 中心实心点：散开时缩小并淡出
                let coreR = mix(4, 2, span(e, 0, 0.5))
                var coreCtx = ctx
                coreCtx.opacity = mix(1, 0, smooth(span(e, 0.17, 0.57)))
                coreCtx.fill(Path(ellipseIn: CGRect(x: 16 - coreR, y: 16 - coreR, width: coreR * 2, height: coreR * 2)),
                             with: .radialGradient(Self.core, center: CGPoint(x: 16, y: 16), startRadius: 0, endRadius: coreR))

                // 一圈点
                var ring = ctx
                ring.opacity = smooth(span(e, 0.15, 0.7))
                guard ring.opacity > 0.001 else { return }
                let r = mix(1.08, 1.34, breath)
                for dot in agentDots {
                    // 一道沿圆环传播的波：每个点只在两个位置之间来回
                    let wave = (1 - cos(2 * .pi * (orbit - Double(dot.index) / 24))) / 2
                    let curveX = mix(dot.arc.x, dot.sweep.x, wave), curveY = mix(dot.arc.y, dot.sweep.y, wave)
                    // 说话时：圆环按 sin(2θ) 轻微变形成椭圆
                    let ripple = breath * sin(2 * dot.angle - .pi * breath)
                    let listening = dotPoint(dot.angle + 0.064 * breath, 13.5 + 0.85 * ripple)
                    let w = g * (0.54 + 0.46 * wave)
                    let x = mix(16, mix(listening.x, curveX, w), e)
                    let y = mix(16, mix(listening.y, curveY, w), e)
                    ring.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Self.dotColor))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
