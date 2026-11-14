import SwiftUI

/// 四种小助手并排，自动循环走一遍：待机 → 聆听 → 搜索 → 核对 → 出结果 → 收起。
/// 四个格子读同一个 AgentMotion，所以每一帧都在同一个状态，直接对比。
/// 点状态条可以停在某一步；点格子把它设成 App 里用的样式。
struct AgentPreviewSheet: View {
    private enum Step: Int, CaseIterable, Identifiable {
        case resting, listening, searching, reviewing, ready
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .resting: "待机"
            case .listening: "聆听"
            case .searching: "搜索"
            case .reviewing: "核对"
            case .ready: "出结果"
            }
        }
        var agent: AgentState {
            switch self {
            case .resting: .resting
            case .listening: .listening
            case .searching: .searching
            case .reviewing: .reviewing
            case .ready: .ready
            }
        }
        /// 和真实流程一样的时长；聆听正好是一整段说话包络
        var seconds: Double {
            switch self {
            case .resting: 1.4
            case .listening: VoiceEnvelope.duration
            case .searching: 1.41
            case .reviewing: 1.32
            case .ready: 1.8
            }
        }
    }

    @State private var motion = AgentMotion()
    @State private var step: Step = .resting
    @State private var pinned: Step?
    @AppStorage("agentLook") private var chosen: AgentLook = .bloom
    @Environment(\.dismiss) private var dismiss

    /// 雾在白底上大致的颜色，小助手本来就是画在雾上的
    private let fogTone = Color(hex: 0x77737F)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("小助手样式").font(.system(size: 22, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }.font(.system(size: 17, weight: .semibold))
            }

            stepBar

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(AgentLook.allCases) { look in
                        Button { chosen = look } label: { cell(look) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(2)
            }
            .scrollIndicators(.hidden)

            Text(pinned == nil ? "自动循环中。点上面的状态可以停在那一步，再点一次继续循环。点格子把它设为 App 里用的样式。"
                               : "停在「\(pinned!.label)」。再点一次继续循环。")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(24)
        .foregroundStyle(Color.ink)
        .background(Color.paper.ignoresSafeArea())
        .presentationDetents([.large])
        .task { await loop() }
    }

    private var stepBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases) { s in
                Button {
                    pinned = pinned == s ? nil : s
                    if let pinned { go(pinned) }
                } label: {
                    Text(s.label)
                        .font(.system(size: 14, weight: step == s ? .semibold : .regular))
                        .foregroundStyle(step == s ? Color.white : Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(step == s ? Color.ink : Color.black.opacity(0.05), in: Capsule())
                        .overlay {
                            if pinned == s { Capsule().strokeBorder(Color.ink, lineWidth: 1.5).padding(-3) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.fog(duration: 0.25), value: step)
    }

    private func cell(_ look: AgentLook) -> some View {
        VStack(spacing: 14) {
            ZStack {
                // 待机时小助手下面那块浅灰圆底，和 App 里一致
                Circle()
                    .fill(Color(red: 204 / 255, green: 204 / 255, blue: 208 / 255).opacity(0.76))
                    .frame(width: 36 * 2.2, height: 36 * 2.2)
                    .opacity(step == .resting ? 1 : 0)
                    .scaleEffect(step == .resting ? 1 : 1.08)
                    .animation(.fog(duration: 0.46), value: step)
                AgentView(motion: motion, size: 32 * 2.2, look: look)
            }
            .frame(height: 96)
            HStack(spacing: 6) {
                Text(look.label).font(.system(size: 15, weight: .semibold))
                if chosen == look {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                }
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(fogTone, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            if chosen == look {
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.ink, lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func go(_ s: Step) {
        step = s
        motion.set(s.agent)
    }

    private func loop() async {
        var i = 0
        while !Task.isCancelled {
            if let pinned {
                // 停住时，聆听需要不断重放说话包络，不然会停在静音
                if pinned == .listening { motion.set(.listening) }
                try? await Task.sleep(for: .seconds(pinned == .listening ? VoiceEnvelope.duration : 0.3))
                continue
            }
            let s = Step.allCases[i % Step.allCases.count]
            go(s)
            try? await Task.sleep(for: .seconds(s.seconds))
            i += 1
        }
    }
}

#Preview { AgentPreviewSheet() }
