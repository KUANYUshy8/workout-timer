import SwiftUI

// MARK: - Shapes

/// Soft corner blob for the top-right of each screen (same curve as the web version).
struct TopBlob: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 200, sy = r.height / 150
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        var path = Path()
        path.move(to: p(0, 0))
        path.addCurve(to: p(98, 66), control1: p(46, 0), control2: p(74, 26))
        path.addCurve(to: p(200, 150), control1: p(120, 104), control2: p(146, 142))
        path.addLine(to: p(200, 0))
        path.closeSubpath()
        return path
    }
}

/// Blob for the bottom-left corner of the workout screen.
struct BottomBlob: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 200, sy = r.height / 150
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        var path = Path()
        path.move(to: p(0, 0))
        path.addCurve(to: p(112, 74), control1: p(52, 2), control2: p(86, 34))
        path.addCurve(to: p(200, 150), control1: p(134, 110), control2: p(158, 138))
        path.addLine(to: p(0, 150))
        path.closeSubpath()
        return path
    }
}

/// Half-round arch that sits at the bottom of a setting card and holds its icon.
struct ArchShape: Shape {
    func path(in r: CGRect) -> Path {
        let rad = min(r.width / 2, r.height)
        let k: CGFloat = 0.5523
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.minY + rad - rad * k),
                   control2: CGPoint(x: r.midX - rad * k, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + rad),
                   control1: CGPoint(x: r.midX + rad * k, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY + rad - rad * k))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

/// Top edge of the tab bar, dipping around the start button.
struct NotchLine: Shape {
    func path(in r: CGRect) -> Path {
        let cx = r.midX
        let y0: CGFloat = 0.75
        let top = y0 + 7
        let rad: CGFloat = 36
        let k: CGFloat = 0.5523
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: y0))
        p.addLine(to: CGPoint(x: cx - 46, y: y0))
        p.addCurve(to: CGPoint(x: cx - rad, y: top),
                   control1: CGPoint(x: cx - 40, y: y0),
                   control2: CGPoint(x: cx - 38, y: y0 + 2.5))
        p.addCurve(to: CGPoint(x: cx, y: top + rad),
                   control1: CGPoint(x: cx - rad, y: top + rad * k),
                   control2: CGPoint(x: cx - rad * k, y: top + rad))
        p.addCurve(to: CGPoint(x: cx + rad, y: top),
                   control1: CGPoint(x: cx + rad * k, y: top + rad),
                   control2: CGPoint(x: cx + rad, y: top + rad * k))
        p.addCurve(to: CGPoint(x: cx + 46, y: y0),
                   control1: CGPoint(x: cx + 38, y: y0 + 2.5),
                   control2: CGPoint(x: cx + 40, y: y0))
        p.addLine(to: CGPoint(x: r.maxX, y: y0))
        return p
    }
}

struct HLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

// MARK: - Page scaffolding

struct PageBackground: View {
    var blob: Color = Palette.blobBlue

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.bg
            TopBlob().fill(blob).frame(width: 200, height: 190)
        }
        .ignoresSafeArea()
    }
}

struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.display(30)).foregroundStyle(Palette.fg)
            Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
        }
        .padding(.top, 24)
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.fg)
            Spacer()
            trailing
        }
        .padding(.top, 30)
        .padding(.bottom, 14)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

struct PageContent: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func pageContent() -> some View { modifier(PageContent()) }
}

struct NoteView: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.blueInk)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.blueSoft))
    }
}

struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.fg)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line, lineWidth: 1.5))
    }
}

struct ToastView: View {
    let text: String?

    var body: some View {
        ZStack {
            if let text = text {
                Text(text)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.inkFg)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Palette.ink))
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: text)
        .allowsHitTesting(false)
    }
}

// MARK: - Rings

struct ProgressRing: View {
    var fraction: Double
    var color: Color
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: lineWidth)
            if fraction > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
    }
}

struct RingSegment: Identifiable {
    let id: Int
    let value: Double
    let color: Color
}

/// The total-time ring on the home screen, split into work / rest / between-round rest.
struct SegmentRing: View {
    let segments: [RingSegment]
    var lineWidth: CGFloat = 12

    private struct Arc: Identifiable {
        let id: Int
        let from: CGFloat
        let to: CGFloat
        let color: Color
    }

    private var arcs: [Arc] {
        let total = segments.reduce(0) { $0 + $1.value }
        guard total > 0 else { return [] }
        let active = segments.filter { $0.value > 0 }
        let gap: CGFloat = active.count > 1 ? 0.008 : 0
        var start: CGFloat = 0
        var out: [Arc] = []
        for s in active {
            let span = CGFloat(s.value / total)
            out.append(Arc(id: s.id, from: start, to: start + max(0.004, span - gap), color: s.color))
            start += span
        }
        return out
    }

    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: lineWidth)
            ForEach(arcs) { a in
                Circle()
                    .trim(from: a.from, to: a.to)
                    .stroke(a.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
    }
}

struct LegendRow: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(color))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.num(18, .bold)).foregroundStyle(Palette.fg)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.muted)
            }
        }
    }
}

// MARK: - Buttons

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PillStyle: ButtonStyle {
    enum Kind { case ink, line, warn }
    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(background))
            .overlay(Capsule().strokeBorder(kind == .line ? Palette.line : Color.clear, lineWidth: 1.5))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .ink: return Palette.inkFg
        case .line: return Palette.fg
        case .warn: return Palette.orange
        }
    }

    private var background: Color {
        switch kind {
        case .ink: return Palette.ink
        case .line: return Palette.bg
        case .warn: return Palette.orangeSoft
        }
    }
}

struct CircleIconButton: View {
    let system: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.fg)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Palette.bg))
                .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1.5))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

struct ChipButton: View {
    let title: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(selected ? Color.white : tint)
                .padding(.horizontal, 18)
                .frame(height: 36)
                .background(Capsule().fill(selected ? Palette.orange : Color.clear))
                .overlay(Capsule().strokeBorder(selected ? Palette.orange : tint, lineWidth: 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension PresetTint {
    var color: Color {
        switch self {
        case .green: return Palette.greenInk
        case .mustard: return Palette.mustardInk
        case .blue: return Palette.blueInk
        }
    }
}
