import SwiftUI

/// 背景页面和“按住删除”列表用的歌曲（虚构的歌名和艺人）
struct Song: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let artist: String
    let duration: String
    let colors: [Color]
    /// AI 生成的歌单：封面用前四首拼成 2×2
    var mosaic: [Track] = []
}

extension Song {
    static let samples: [Song] = [
        Song(name: "Low Tide", artist: "Mina Aoki", duration: "38:12", colors: Palette.tulip),
        Song(name: "Night Bus", artist: "Northbound Static", duration: "41:05", colors: Palette.hydrangea),
        Song(name: "Blue Hour", artist: "Lio Carver", duration: "3:18", colors: Palette.iris),
        Song(name: "Kettle Steam", artist: "The Quiet Hours", duration: "5:10", colors: Palette.lavender),
        Song(name: "Linen", artist: "Ada Morrow", duration: "3:55", colors: Palette.daisy),
    ]
}

/// 封面配色：每组取自一种花，4 个颜色从亮到暗（瓣尖 → 花心 / 花萼）
enum Palette {
    static let tulip     = [0xFFE3D3, 0xFF9E7A, 0xE8505B, 0x7A1E3A].map(Color.init(hex:)) // 郁金香
    static let hydrangea = [0xE8F1FF, 0xA9C6F5, 0x7E8EE0, 0x3C3F8F].map(Color.init(hex:)) // 绣球
    static let iris      = [0xEDE7FF, 0x9C8BEA, 0x4E4BB8, 0x1E2A5A].map(Color.init(hex:)) // 鸢尾
    static let lavender  = [0xF2EEFF, 0xC8B8F0, 0x8E7CC3, 0x3F3566].map(Color.init(hex:)) // 薰衣草
    static let daisy     = [0xFFFDF5, 0xFFE9A8, 0xF6B92B, 0x5E7A2E].map(Color.init(hex:)) // 雏菊：白瓣、金心、绿萼
    static let pansy     = [0xF3E8FF, 0xB79CF2, 0x6B4FD8, 0x2A1B5E].map(Color.init(hex:)) // 三色堇
    static let sakura    = [0xFFF1F5, 0xFFC9DA, 0xF48FB1, 0x9C3D6B].map(Color.init(hex:)) // 樱花
    static let peony     = [0xFFEAF0, 0xF7A8C4, 0xD8457A, 0x5E1236].map(Color.init(hex:)) // 牡丹
    static let camellia  = [0xFFE6E6, 0xF58A8A, 0xC4384B, 0x4D1020].map(Color.init(hex:)) // 山茶
    static let sunflower = [0xFFF6CC, 0xFFD23F, 0xE89A1C, 0x4A2C12].map(Color.init(hex:)) // 向日葵
}

/// 2×2 拼贴封面：歌单还没满四首时，空格是一块淡淡的底
struct MosaicCover: View {
    let tracks: [Track]
    var radius: CGFloat = 14
    var gap: CGFloat = 2

    var body: some View {
        GeometryReader { g in
            let s = (g.size.width - gap) / 2
            VStack(spacing: gap) {
                ForEach(0..<2, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<2, id: \.self) { c in
                            let i = r * 2 + c
                            ZStack {
                                Rectangle().fill(Color.white.opacity(0.08))
                                if i < tracks.count {
                                    Cover(colors: tracks[i].colors, radius: 0, seed: tracks[i].id)
                                        .id(tracks[i].id)
                                        .transition(.opacity)
                                }
                            }
                            .frame(width: s, height: s)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    // 纯白背景；文字用不带色偏的中性灰
    static let paper = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x1C1C1E)
    static let inkMuted = Color(hex: 0x6E6E73)
}

/// 封面：3×3 的网格渐变（MeshGradient）。
/// 中间和四条边中点的位置按 seed 轻微错开，所以同一组颜色、不同的歌也会长出不同的形状；
/// 再叠一层左上角的柔光和底部的压暗，让它有一点纸面/釉面的厚度。
struct Cover: View {
    let colors: [Color]
    var radius: CGFloat = 17
    var seed: String = ""

    init(colors: [Color], radius: CGFloat = 17, seed: String = "") {
        self.colors = colors; self.radius = radius; self.seed = seed
    }
    init(song: Song, radius: CGFloat = 17) { self.init(colors: song.colors, radius: radius, seed: song.name) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let h = Self.hash(seed)
        shape
            .fill(mesh(h))
            .overlay {
                // 左上角柔光
                RadialGradient(colors: [.white.opacity(0.28), .clear], center: UnitPoint(x: 0.2, y: 0.15),
                               startRadius: 0, endRadius: 140)
                    .blendMode(.softLight)
            }
            .overlay {
                // 底部压暗
                LinearGradient(colors: [.clear, .black.opacity(0.16)], startPoint: .center, endPoint: .bottom)
            }
            .clipShape(shape)
    }

    private func mesh(_ h: UInt64) -> MeshGradient {
        // 取 hash 的不同 4 位当作 -0.5…0.5 的偏移
        func j(_ k: Int, _ amp: Float) -> Float { (Float((h >> (k * 4)) & 0xF) / 15 - 0.5) * amp }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5 + j(0, 0.35), 0], [1, 0],
            [0, 0.5 + j(1, 0.35)], [0.5 + j(2, 0.45), 0.5 + j(3, 0.45)], [1, 0.5 + j(4, 0.35)],
            [0, 1], [0.5 + j(5, 0.35), 1], [1, 1],
        ]
        // 四种颜色排布，按 seed 选一种；索引对应调色板里从亮到暗的颜色
        let layouts: [[Int]] = [
            [0, 0, 1, 1, 2, 2, 2, 3, 3], // 左上亮 → 右下暗
            [1, 0, 0, 2, 1, 1, 3, 3, 2], // 右上亮
            [0, 1, 0, 1, 2, 1, 3, 2, 3], // 上亮、中间一团
            [2, 1, 2, 1, 0, 1, 3, 2, 3], // 中心亮、四周暗：像往花心里看
        ]
        let layout = layouts[Int(h % 4)]
        let palette = colors.isEmpty ? [Color.gray] : colors
        return MeshGradient(width: 3, height: 3, points: points,
                            colors: layout.map { palette[$0 % palette.count] },
                            smoothsColors: true)
    }

    /// djb2：每次启动都得到同一个值（String.hashValue 每次启动会变）
    private static func hash(_ s: String) -> UInt64 {
        s.utf8.reduce(5381) { ($0 &* 33) &+ UInt64($1) }
    }
}

struct SongRow: View {
    let song: Song
    var showsPlay = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Group {
                    if song.mosaic.isEmpty { Cover(song: song, radius: 9) }
                    else { MosaicCover(tracks: song.mosaic, radius: 9, gap: 1) }
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text("\(song.artist) · \(song.duration)").font(.system(size: 13)).foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
                if showsPlay {
                    PlayButton(key: song.name)
                        .padding(.trailing, -6) // 让圆的右边和页面边距对齐，热区多出来的部分不占位置
                }
            }
            .frame(minHeight: 44)
            .padding(.vertical, 8)
            RowSeparator()
        }
        .contentShape(Rectangle())
    }
}

/// 雾背后的 App 页面
struct MusicBackdrop: View {
    /// AI 刚存下的歌单，雾散开后出现在 Recently Played 第一行
    var extra: Song? = nil
    private let songs = Song.samples

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Listen Now").font(.system(size: 32, weight: .semibold)).tracking(-0.6)
            HStack(spacing: 12) {
                ForEach(songs.prefix(2)) { album in
                    VStack(alignment: .leading, spacing: 2) {
                        Cover(song: album).aspectRatio(1, contentMode: .fit)
                            .overlay(alignment: .bottomTrailing) {
                                PlayButton(key: album.name, look: .onArt, size: 34).padding(6)
                            }
                            .padding(.bottom, 6)
                        Text(album.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(album.artist).font(.system(size: 13)).foregroundStyle(Color.inkMuted).lineLimit(1)
                    }
                }
            }
            .padding(.top, 16)
            Text("Recently Played").font(.system(size: 20, weight: .semibold)).padding(.top, 20).padding(.bottom, 4)
            ForEach((extra.map { [$0] } ?? []) + Array(songs.dropFirst(2))) { song in
                SongRow(song: song, showsPlay: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paper.ignoresSafeArea())
    }
}
