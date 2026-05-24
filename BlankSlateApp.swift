import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .blankSlateWipe, object: nil)
    }
}

extension Notification.Name {
    static let blankSlateWipe = Notification.Name("BlankSlateWipe")
    static let blankSlateEscape = Notification.Name("BlankSlateEscape")
}

@main
struct BlankSlateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 500)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            if let w = v.window {
                w.isRestorable = false
                w.sharingType = .none
            }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum Theme {
    case light, dark
    var bg: Color {
        switch self {
        case .light: return Color(red: 0.973, green: 0.965, blue: 0.945)
        case .dark:  return Color(red: 0.10,  green: 0.10,  blue: 0.11)
        }
    }
    var ink: Color {
        switch self {
        case .light: return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .dark:  return Color(red: 0.92, green: 0.91, blue: 0.88)
        }
    }
}

struct TypeSettings: Equatable, Codable {
    var fontSize: CGFloat = 17
    var kerning: CGFloat = -0.5
    var leading: CGFloat = 0
    var lineHeight: CGFloat = 1.2
}

enum Persisted {
    static let settingsKey = "blankslate.settings"
    static let themeKey = "blankslate.theme"

    static func loadSettings() -> TypeSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let s = try? JSONDecoder().decode(TypeSettings.self, from: data) else {
            return TypeSettings()
        }
        return s
    }

    static func saveSettings(_ s: TypeSettings) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    static func loadTheme() -> Theme {
        UserDefaults.standard.string(forKey: themeKey) == "dark" ? .dark : .light
    }

    static func saveTheme(_ t: Theme) {
        UserDefaults.standard.set(t == .dark ? "dark" : "light", forKey: themeKey)
    }
}

struct ContentView: View {
    @State private var text: String = ""
    @State private var hasStarted: Bool = false
    @State private var paused: Bool = false
    @State private var secondsRemaining: Int = 20 * 60
    @State private var timer: Timer?
    @State private var hovering: Bool = false
    @State private var theme: Theme = Persisted.loadTheme()
    @State private var showSettings: Bool = false
    @State private var showHelp: Bool = false
    @State private var showAbout: Bool = false
    @State private var settings: TypeSettings = Persisted.loadSettings()
    @State private var skipNextResume: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.bg.ignoresSafeArea()

            writingView

            if hasStarted {
                timerChip
            }

            if showSettings {
                SettingsPanel(settings: $settings, theme: theme)
                    .frame(width: 280)
                    .padding(.top, 56)
                    .padding(.trailing, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showHelp {
                HelpPanel(theme: theme)
                    .frame(width: 280)
                    .padding(.top, 56)
                    .padding(.trailing, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if showAbout {
                AboutPanel(theme: theme)
                    .frame(width: 360)
                    .padding(.top, 56)
                    .padding(.trailing, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if !hasStarted && text.isEmpty && !showSettings && !showHelp && !showAbout {
                helpHint
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showSettings)
        .animation(.easeInOut(duration: 0.18), value: showHelp)
        .animation(.easeInOut(duration: 0.18), value: showAbout)
        .animation(.easeInOut(duration: 0.2), value: theme)
        .onChange(of: text) { _, newValue in
            if handleSlashCommands(newValue) { return }
            if skipNextResume {
                skipNextResume = false
                return
            }
            if !newValue.isEmpty {
                if !hasStarted {
                    startTimer(reset: true)
                } else if paused {
                    startTimer(reset: false)
                }
            }
        }
        .onChange(of: settings) { _, newValue in
            Persisted.saveSettings(newValue)
        }
        .onChange(of: theme) { _, newValue in
            Persisted.saveTheme(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .blankSlateWipe)) { _ in
            end()
        }
        .onReceive(NotificationCenter.default.publisher(for: .blankSlateEscape)) { _ in
            showSettings = false
            showHelp = false
            showAbout = false
        }
    }

    private var helpHint: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("/help")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.ink.opacity(0.35))
            }
        }
        .padding(.bottom, 16)
        .padding(.trailing, 20)
        .allowsHitTesting(false)
    }

    private var fastBlink: Bool { hasStarted && secondsRemaining <= 10 && !paused }

    private var maxLineWidth: CGFloat {
        let f = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: f, .kern: settings.kerning]
        let sample = String(repeating: "M", count: 80)
        return ceil((sample as NSString).size(withAttributes: attrs).width) + 4
    }

    private var writingView: some View {
        ZStack(alignment: .topLeading) {
            BlankSlateTextView(
                text: $text,
                ink: NSColor(theme.ink),
                settings: settings,
                fastBlink: fastBlink
            )
            if text.isEmpty {
                Text("start writing")
                    .font(.system(size: settings.fontSize, design: .monospaced))
                    .kerning(settings.kerning)
                    .foregroundColor(theme.ink.opacity(0.3))
                    .allowsHitTesting(false)
                    .padding(.leading, 12)
            }
        }
        .frame(maxWidth: maxLineWidth, alignment: .topLeading)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 80)
        .padding(.bottom, 120)
    }

    private var timerChip: some View {
        let revealed = hovering || secondsRemaining <= 10
        let urgent = secondsRemaining <= 10
        return HStack(spacing: 6) {
            if revealed {
                Text(timeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.ink.opacity(urgent ? 0.75 : 0.45))
                    .transition(.opacity)
            }
            Image(systemName: paused ? "pause.fill" : "clock")
                .font(.system(size: 12))
                .foregroundColor(theme.ink.opacity(urgent ? 0.75 : 0.35))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .padding(.top, 16)
        .padding(.trailing, 20)
        .animation(.easeInOut(duration: 0.15), value: revealed)
    }

    private var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer(reset: Bool) {
        if reset { secondsRemaining = 20 * 60 }
        hasStarted = true
        paused = false
        hovering = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                end()
            }
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        paused = true
        skipNextResume = true
    }

    private func end() {
        timer?.invalidate()
        timer = nil
        text = ""
        hasStarted = false
        paused = false
        secondsRemaining = 20 * 60
        skipNextResume = true
    }

    private func handleSlashCommands(_ s: String) -> Bool {
        let commands: [(String, () -> Void)] = [
            ("/type",  { showHelp = false; showAbout = false; showSettings.toggle() }),
            ("/help",  { showSettings = false; showAbout = false; showHelp.toggle() }),
            ("/about", { showSettings = false; showHelp = false; showAbout.toggle() }),
            ("/dark",  { theme = .dark }),
            ("/light", { theme = .light }),
            ("/reset", { end() }),
            ("/pause", { pauseTimer() }),
        ]
        for (cmd, action) in commands {
            let pattern = "\(cmd)\n"
            if s.hasSuffix(pattern) {
                let trimmed = String(s.dropLast(pattern.count))
                skipNextResume = true
                text = trimmed
                action()
                return true
            }
        }
        return false
    }
}

// MARK: - Settings Panel (Dialkit-style)

struct SettingsPanel: View {
    @Binding var settings: TypeSettings
    let theme: Theme

    private var panelBG: Color {
        theme == .dark
            ? Color(red: 0.13, green: 0.13, blue: 0.14)
            : Color(red: 0.16, green: 0.16, blue: 0.17)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("type")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("esc to close")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            DialRow(label: "Font Size", value: $settings.fontSize, range: 13...28, format: "%.0f")
            DialRow(label: "Kerning",   value: $settings.kerning,  range: -2...2,  format: "%.1f")
            DialRow(label: "Leading",   value: $settings.leading,  range: 0...16,  format: "%.0f")
            DialRow(label: "Line Height", value: $settings.lineHeight, range: 0.9...2.0, format: "%.2f")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(panelBG)
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
        )
    }
}

struct HelpPanel: View {
    let theme: Theme

    private var panelBG: Color {
        theme == .dark
            ? Color(red: 0.13, green: 0.13, blue: 0.14)
            : Color(red: 0.16, green: 0.16, blue: 0.17)
    }

    private let rows: [(String, String)] = [
        ("/type",  "typography panel"),
        ("/dark",  "dark mode"),
        ("/light", "light mode"),
        ("/pause", "pause the timer"),
        ("/reset", "wipe and restart"),
        ("/about", "what this is"),
        ("/help",  "this list"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("help")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("esc to close")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.0) { cmd, desc in
                    HStack {
                        Text(cmd)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 64, alignment: .leading)
                        Text(desc)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(panelBG)
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
        )
    }
}

struct AboutPanel: View {
    let theme: Theme

    private var panelBG: Color {
        theme == .dark
            ? Color(red: 0.13, green: 0.13, blue: 0.14)
            : Color(red: 0.16, green: 0.16, blue: 0.17)
    }

    private let aboutText = """
    This is a simple expressive journaling app.

    Write for 20 minutes per day, at the end of the 20 minutes everything is wiped. Your writing is not saved, not to disk, not to the cloud, not to your clipboard, not even screenshots.

    This writing is meant to disappear.

    Built by Diego, released under MIT license.
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("about")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("esc to close")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)

            Text(aboutText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(panelBG)
                .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
        )
    }
}

struct DialRow: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let format: String

    var body: some View {
        GeometryReader { geo in
            let f = max(0, min(1, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: max(0, geo.size.width * f))
                HStack {
                    Text(label)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(String(format: format, Double(value)))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let pct = max(0, min(1, g.location.x / geo.size.width))
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * pct
                    }
            )
        }
        .frame(height: 32)
    }
}

// MARK: - Freewrite Text View

final class FreewriteTextView: NSTextView {
    private let caretLayer = CALayer()
    private var caretAnimKey = "blank.caret.blink"
    var fastBlink: Bool = false {
        didSet { if oldValue != fastBlink { startBlinkAnimation() } }
    }

    override var shouldDrawInsertionPoint: Bool { false }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // suppressed -- we draw our own caret via caretLayer
    }

    override func updateInsertionPointStateAndRestartTimer(_ restartFlag: Bool) {
        // suppressed -- prevents AppKit from running its blink timer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        if caretLayer.superlayer == nil {
            wantsLayer = true
            caretLayer.actions = ["position": NSNull(), "bounds": NSNull(), "opacity": NSNull(), "backgroundColor": NSNull()]
            caretLayer.anchorPoint = CGPoint(x: 0, y: 0)
            layer?.addSublayer(caretLayer)
            updateCaretColor()
            startBlinkAnimation()
        }
        DispatchQueue.main.async { [weak self] in
            self?.updateCaretFrame()
        }
    }

    override func didChangeText() {
        super.didChangeText()
        updateCaretFrame()
    }

    override func layout() {
        super.layout()
        updateCaretFrame()
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        let end = (self.string as NSString).length
        super.setSelectedRanges(
            [NSValue(range: NSRange(location: end, length: 0))],
            affinity: affinity,
            stillSelecting: false
        )
        DispatchQueue.main.async { [weak self] in
            self?.updateCaretFrame()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let end = (self.string as NSString).length
        self.setSelectedRange(NSRange(location: end, length: 0))
        self.window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func menu(for event: NSEvent) -> NSMenu? { nil }

    override func selectAll(_ sender: Any?) {}
    override func copy(_ sender: Any?) {}
    override func cut(_ sender: Any?) {}
    override func paste(_ sender: Any?) {}
    override func pasteAsPlainText(_ sender: Any?) {}
    override func pasteAsRichText(_ sender: Any?) {}

    override func doCommand(by selector: Selector) {
        let name = NSStringFromSelector(selector)
        if name == "cancelOperation:" {
            NotificationCenter.default.post(name: .blankSlateEscape, object: nil)
            return
        }
        let allowed: Set<String> = [
            "insertText:",
            "insertNewline:",
            "insertParagraphSeparator:",
            "insertLineBreak:",
            "insertTab:",
            "deleteBackward:",
        ]
        if allowed.contains(name) {
            super.doCommand(by: selector)
        }
    }

    func updateCaretColor() {
        let c = (textColor ?? .black).withAlphaComponent(0.85)
        caretLayer.backgroundColor = c.cgColor
    }

    func updateCaretFrame() {
        guard let lm = layoutManager, let tc = textContainer, let f = font else { return }
        lm.ensureLayout(for: tc)
        let nsLength = (string as NSString).length
        let lineH = lm.defaultLineHeight(for: f)
        var rect: NSRect

        if nsLength == 0 {
            rect = NSRect(x: 0, y: 0, width: 2, height: lineH)
        } else {
            let lastChar = (string as NSString).character(at: nsLength - 1)
            if lastChar == 0x0A {
                let extra = lm.extraLineFragmentRect
                if extra.height > 0 {
                    rect = NSRect(x: extra.minX, y: extra.minY, width: 2, height: extra.height)
                } else {
                    let lastGlyph = lm.glyphIndexForCharacter(at: nsLength - 1)
                    let lineFrag = lm.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: nil)
                    rect = NSRect(x: 0, y: lineFrag.maxY, width: 2, height: lineH)
                }
            } else {
                let lastGlyph = lm.glyphIndexForCharacter(at: nsLength - 1)
                let lineFrag = lm.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: nil)
                let glyphRect = lm.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: tc)
                rect = NSRect(x: glyphRect.maxX, y: lineFrag.minY, width: 2, height: lineFrag.height)
            }
        }
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        caretLayer.frame = rect
    }

    func startBlinkAnimation() {
        caretLayer.removeAnimation(forKey: caretAnimKey)
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1.0
        anim.toValue = 0.0
        anim.duration = fastBlink ? 0.28 : 0.55
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        caretLayer.add(anim, forKey: caretAnimKey)
    }
}

struct BlankSlateTextView: NSViewRepresentable {
    @Binding var text: String
    var ink: NSColor
    var settings: TypeSettings
    var fastBlink: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let contentSize = scroll.contentSize
        let tv = FreewriteTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        tv.minSize = NSSize(width: 0, height: contentSize.height)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = .width
        if let container = tv.textContainer {
            container.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }

        tv.delegate = context.coordinator
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.isRichText = false
        tv.allowsUndo = false
        tv.isSelectable = true
        tv.isEditable = true
        tv.font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        tv.textColor = ink
        tv.textContainerInset = NSSize(width: 0, height: 0)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.usesFindBar = false
        tv.usesFontPanel = false

        applyAttributes(to: tv)
        tv.fastBlink = fastBlink

        scroll.documentView = tv
        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
        }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? FreewriteTextView else { return }
        if tv.string != text {
            tv.string = text
        }
        tv.textColor = ink
        applyAttributes(to: tv)
        tv.updateCaretColor()
        tv.fastBlink = fastBlink
        tv.updateCaretFrame()
    }

    private func applyAttributes(to tv: FreewriteTextView) {
        let font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        tv.font = font

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = settings.leading
        paragraph.lineHeightMultiple = settings.lineHeight
        paragraph.hyphenationFactor = 1.0

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ink,
            .kern: settings.kerning,
            .paragraphStyle: paragraph,
        ]
        tv.typingAttributes = attrs

        if !tv.string.isEmpty, let ts = tv.textStorage {
            ts.beginEditing()
            ts.setAttributes(attrs, range: NSRange(location: 0, length: ts.length))
            ts.endEditing()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlankSlateTextView
        init(_ parent: BlankSlateTextView) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? FreewriteTextView else { return }
            parent.text = tv.string
            tv.updateCaretFrame()
        }
    }
}
