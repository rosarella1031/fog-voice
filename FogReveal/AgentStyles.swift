import SwiftUI

/// 小助手的几种样子。都读同一组动画值（AgentMotion）：
/// expansion（收起 ↔ 展开）、voice（说话音量）、gather（搜索中）、orbit（搜索时转动）。
/// 所以换样子不用改任何流程，只是换一种“身体”。
enum AgentLook: String, CaseIterable, Identifiable {
    case dots, bloom, phyllo, fireflies, orbits, blob, bars, orb
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dots: "圆点环"
        case .bloom: "花环"
        case .phyllo: "向日葵"
        case .fireflies: "萤火"
        case .orbits: "轨道"
        case .blob: "液滴"
        case .bars: "声波"
        case .orb: "光球"
        }
    }
}

struct AgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32
    /// 不传就用设置里选的样式；预览页用它强制指定
    var look: AgentLook? = nil
    @AppStorage("agentLook") private var stored: AgentLook = .bloom

    var body: some View {
        switch look ?? stored {
        case .dots: DotAgentView(motion: motion, size: size)
        case .bloom: BloomAgentView(motion: motion, size: size)
        case .phyllo: PhylloAgentView(motion: motion, size: size)
        case .fireflies: FireflyAgentView(motion: motion, size: size)
        case .orbits: OrbitAgentView(motion: motion, size: size)
        case .blob: BlobAgentView(motion: motion, size: size)
        case .bars: BarsAgentView(motion: motion, size: size)
        case .orb: OrbAgentView(motion: motion, size: size)
        }
    }
}

/// 右上角的样式切换，方便对比
struct AgentLookMenu: View {
    @AppStorage("agentLook") private var look: AgentLook = .bloom
    @State private var showPreview = ProcessInfo.processInfo.arguments.contains("-agentPreview")

    var body: some View {
        Menu {
            Picker("小助手样式", selection: $look) {
                ForEach(AgentLook.allCases) { Text($0.label).tag($0) }
            }
            Divider()
            Button("并排预览…", systemImage: "square.grid.2x2") { showPreview = true }
        } label: {
            HStack(spacing: 6) {
                Text(look.label)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
        }
        .accessibilityLabel("小助手样式：\(look.label)")
        .sheet(isPresented: $showPreview) { AgentPreviewSheet() }
    }
}

private let agentBlue = Color(hex: 0xA8C8F1)

// MARK: - 液滴：一团会变形的水

/// 收起时是一个小点；展开后变成一滴水。说话时边缘按 3 瓣、5 瓣两种波纹起伏，
/// 搜索时波纹绕着转。形状 = 半径 × (1 + 振幅 × 两个正弦叠加)。
struct BlobAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / 32, y: size.height / 32)
                let e = motion.expansion.value(at: t)
                let g = motion.gather.value(at: t)
                let v = motion.voice.value(at: t)

                let r0 = mix(4, 10.5, e) * (1 + 0.1 * v)
                let amp = e * (0.035 + 0.14 * v + 0.09 * g)
                let spin = g * 2 * sin(t * 1.5)
                var path = Path()
                for k in 0...72 {
                    let a = Double(k) / 72 * 2 * .pi
                    let wobble = 0.6 * sin(3 * a + t * 1.4 + spin) + 0.4 * sin(5 * a - t * 1.1 - spin * 0.5)
                    let r = r0 * (1 + amp * wobble)
                    let p = CGPoint(x: 16 + r * cos(a), y: 16 + r * sin(a))
                    if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.closeSubpath()

                var glow = ctx
                glow.addFilter(.blur(radius: 2.5))
                glow.opacity = 0.5 * e
                glow.fill(path, with: .color(agentBlue))

                ctx.fill(path, with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xE2EEFD), Color(hex: 0x8FB3E3), Color(hex: 0x5F86C4)]),
                    center: CGPoint(x: 13, y: 12), startRadius: 0, endRadius: r0 * 1.5))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 声波：五根竖条

/// 收起时五根条叠在中间成一个点；展开后排开。说话时中间高两边低地跳，
/// 搜索时一道波从左往右走过去。
struct BarsAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32
    private let offsets: [Double] = [-11, -5.5, 0, 5.5, 11]
    private let profile: [Double] = [0.55, 0.8, 1, 0.8, 0.55]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.scaleBy(x: size.width / 32, y: size.height / 32)
                let e = motion.expansion.value(at: t)
                let g = motion.gather.value(at: t)
                let v = motion.voice.value(at: t)
                let orbit = motion.orbit(at: t)
                let w = 3.2

                for i in 0..<5 {
                    let x = 16 + offsets[i] * e
                    let idle = 0.5 + 0.5 * sin(t * 2.1 + Double(i) * 0.9)
                    let talk = v * profile[i] * (0.65 + 0.35 * sin(t * 11 + Double(i) * 1.7))
                    let wave = (1 - cos(2 * .pi * (orbit * 1.5 - Double(i) / 5))) / 2
                    let h = w + e * (3 + 2 * idle * (1 - g) + 16 * talk + 9 * g * wave)
                    var bar = ctx
                    bar.opacity = i == 2 ? 1 : smooth(span(e, 0.1, 0.6))
                    bar.fill(Path(roundedRect: CGRect(x: x - w / 2, y: 16 - h / 2, width: w, height: h), cornerRadius: w / 2),
                             with: .color(Color(hex: 0xC4DDFA)))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 光球：里面在流动的网格渐变

/// 和封面一样用 MeshGradient，中间几个控制点慢慢绕圈，所以球里的颜色一直在流。
/// 说话时球随音量胀一点，搜索时流得更快。
struct OrbAgentView: View {
    let motion: AgentMotion
    var size: CGFloat = 32

    private static let colors: [Color] = [0xE6F0FF, 0xC4DDFA, 0xA8C8F1,
                                          0x8FB3E3, 0xF1DCFF, 0x749BCE,
                                          0xA8C8F1, 0x5F86C4, 0xC4DDFA].map(Color.init(hex:))

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let e = motion.expansion.value(at: t)
            let g = motion.gather.value(at: t)
            let v = motion.voice.value(at: t)
            let d = mix(8, 24, e) * (1 + 0.14 * v)
            let a = t * 0.9 + 1.6 * g * sin(t * 1.7) + t * 1.2 * g
            let k = Float(0.2 * (1 + v))

            ZStack {
                Circle().fill(agentBlue)
                    .frame(width: d + 6, height: d + 6)
                    .blur(radius: 5)
                    .opacity(0.55 * e)
                MeshGradient(width: 3, height: 3, points: [
                    [0, 0], [0.5 + k * Float(cos(a)), 0], [1, 0],
                    [0, 0.5 + k * Float(sin(a * 1.3))],
                    [0.5 + 1.1 * k * Float(cos(a * 1.1 + 1)), 0.5 + 1.1 * k * Float(sin(a * 0.9 + 2))],
                    [1, 0.5 + k * Float(cos(a * 0.8 + 0.5))],
                    [0, 1], [0.5 + k * Float(sin(a + 3)), 1], [1, 1],
                ], colors: Self.colors, smoothsColors: true)
                .frame(width: d, height: d)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.35 * e), lineWidth: 0.5))
            }
            .frame(width: 32, height: 32)
            .scaleEffect(size / 32)
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}
