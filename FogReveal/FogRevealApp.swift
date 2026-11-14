import SwiftUI

@main
struct FogRevealApp: App {
    @State private var player = Player()

    var body: some Scene {
        WindowGroup {
            // -clean：只有一屏，没有样式菜单和 tab 栏，用来录作品集视频
            //   -clean           底部雾点歌
            //   -clean -full     整屏雾点歌
            //   -clean -playlist AI 歌单
            if ProcessInfo.processInfo.arguments.contains("-clean") {
                Group {
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("-playlist") { PlaylistScreen() }
                    else { AssistantScreen(fullFog: args.contains("-full")) }
                }
                .environment(player)
                .preferredColorScheme(.light)
            } else {
            TabView {
                AssistantScreen()
                    .tabItem { Label("底部雾", systemImage: "rectangle.bottomhalf.filled") }
                AssistantScreen(fullFog: true)
                    .tabItem { Label("整屏雾", systemImage: "rectangle.fill") }
                PlaylistScreen()
                    .tabItem { Label("AI 歌单", systemImage: "music.note.list") }
                HoldToDeleteScreen()
                    .tabItem { Label("按住删除", systemImage: "hand.tap") }
            }
            .overlay(alignment: .topTrailing) {
                AgentLookMenu().padding(.trailing, 20).padding(.top, 2)
            }
            .environment(player)
            .preferredColorScheme(.light)
            }
        }
    }
}
