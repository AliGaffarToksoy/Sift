import AppKit
import SwiftUI
import Observation
import QuartzCore
import Intents
import Carbon
import SiftCore

private final class MailPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // AppKit otherwise pushes borderless windows below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@Observable @MainActor
final class NotchPresentation {
    var messages: [MailMessage] = []
    var expanded = false
    var topInset: CGFloat = 0
    var hardware = false
    var preview = false
}

@MainActor final class NotchController {
    private let panel: MailPanel
    private let state = NotchPresentation()
    private weak var model: MailboxModel?
    private var timer: Task<Void, Never>?
    private var pointerTask: Task<Void, Never>?
    private var hoverOpened = false
    private var suppressHoverUntilExit = false
    private var screenObserver: NSObjectProtocol?
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var screen: NSScreen?
    private var camera: CGRect?
    private var visible = false
    private var hovering = false
    init(model: MailboxModel) {
        self.model = model
        panel = MailPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Sift · Çentik"
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
        panel.level = .statusBar; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        let hosting = NSHostingView(rootView: NotchView(state: state, model: model,
            hover: { [weak self] in self?.hover($0) }, expand: { [weak self] in self?.expand() },
            dismiss: { [weak self] in self?.hide() }).preferredColorScheme(.dark).ignoresSafeArea())
        hosting.sizingOptions = []
        panel.contentView = hosting
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.geometry(); self?.resize(animated: false) }
        }
        geometry()
        // A hidden SwiftUI view cannot receive onHover. Sample only the pointer
        // position (no event interception or Accessibility permission required).
        pointerTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                self?.checkPointer()
            }
        }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<NotchController>.fromOpaque(pointer).takeUnretainedValue()
            Task { @MainActor in controller.toggle() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: OSType(0x53494654), id: 1)
        if RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotkey) != noErr {
            model.status = "Çentik kısayolu başka bir uygulama tarafından kullanılıyor"
        }
    }
    private func geometry() {
        screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        state.topInset = screen.safeAreaInsets.top; state.hardware = state.topInset > 0
        camera = nil
        if state.hardware, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, right.minX > left.maxX {
            camera = CGRect(x: left.maxX, y: screen.frame.maxY - state.topInset,
                            width: right.minX - left.maxX, height: state.topInset)
        }
    }
    private func checkPointer() {
        guard let screen else { return }
        let point = NSEvent.mouseLocation
        let activation = NotchLayout.activationFrame(screen: screen.frame, visible: screen.visibleFrame,
                                                     topInset: state.topInset, camera: camera)
        let inside = activation.contains(point) || (visible && panel.frame.contains(point))
        if !inside { suppressHoverUntilExit = false }
        guard !suppressHoverUntilExit else { return }
        if inside && !visible && model?.cache.preferences.expandOnHover == true {
            showInbox()
            hoverOpened = true
        }
        if hovering != inside { hover(inside) }
    }
    private func showInbox() {
        guard let model else { return }
        geometry()
        state.messages = Array(model.messages.filter { $0.tier >= model.cache.preferences.minimumTier }
            .sorted { $0.score > $1.score }.prefix(4))
        state.preview = model.demo
        state.expanded = true
        visible = true
        panel.ignoresMouseEvents = false
        // Set the frame before ordering the panel to avoid a flash at its old position.
        if let screen {
            let collapsed = NotchLayout.activationFrame(screen: screen.frame, visible: screen.visibleFrame,
                                                       topInset: state.topInset, camera: camera)
            panel.setFrame(collapsed, display: false)
        }
        panel.orderFrontRegardless()
        resize(animated: true)
    }
    func notify(_ messages: [MailMessage], preview: Bool = false, userInitiated: Bool = false) {
        guard !messages.isEmpty, let model else { return }
        if !preview && !userInitiated {
            guard model.cache.preferences.permitsAlert(at: .now), INFocusStatusCenter.default.focusStatus.isFocused != true else { return }
        }
        let combined = visible && !state.preview && !preview ? state.messages + messages : messages
        var ids: Set<UUID> = []
        state.messages = combined.filter { ids.insert($0.id).inserted }.sorted { $0.score > $1.score }
        let keepExpanded = visible && hovering && state.expanded && !preview
        state.preview = preview; state.expanded = keepExpanded
        geometry()
        if !visible, let screen {
            let width = state.hardware ? (camera?.width ?? 180) : 200
            panel.setFrame(NSRect(x: (camera?.midX ?? screen.frame.midX) - width / 2, y: screen.frame.maxY - max(1, state.topInset), width: width, height: max(1, state.topInset)), display: false)
        }
        hoverOpened = false
        visible = true; panel.ignoresMouseEvents = false
        panel.orderFrontRegardless(); resize(animated: true); scheduleHide()
    }
    func remove(_ id: UUID) {
        state.messages.removeAll { $0.id == id }
        if state.messages.isEmpty { hide() } else { resize(animated: true) }
    }
    func hide() {
        suppressHoverUntilExit = hovering
        timer?.cancel(); visible = false; hovering = false; hoverOpened = false
        panel.ignoresMouseEvents = true; panel.orderOut(nil)
        state.messages = []; state.expanded = false
    }
    private func expand() { state.expanded = true; resize(animated: true); scheduleHide() }
    private func hover(_ inside: Bool) {
        hovering = inside
        if inside { timer?.cancel(); if model?.cache.preferences.expandOnHover == true { expand() } }
        else { scheduleHide() }
    }
    private func toggle() {
        if visible { hide() }
        else { showInbox(); scheduleHide() }
    }
    private func scheduleHide() {
        timer?.cancel()
        guard !hovering else { return }
        let duration = hoverOpened ? 0.45 : max(3, min(30, model?.cache.preferences.alertDuration ?? 8))
        timer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(duration)) } catch { return }
            self?.hide()
        }
    }
    private func resize(animated: Bool) {
        guard visible, let screen else { return }
        let frame = NotchLayout.frame(screen: screen.frame, visible: screen.visibleFrame,
                                      topInset: state.topInset, camera: camera,
                                      expanded: state.expanded, additionalMessages: state.messages.count - 1,
                                      preview: state.preview)
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28; context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.25, 1)
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
    }
    isolated deinit {
        pointerTask?.cancel()
        timer?.cancel()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

private struct NotchSilhouette: Shape {
    var hardware: Bool
    func path(in rect: CGRect) -> Path {
        guard hardware else { return RoundedRectangle(cornerRadius: 24).path(in: rect) }
        let shoulder: CGFloat = 12, bottom: CGFloat = 24
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder, y: shoulder), control: CGPoint(x: rect.maxX - shoulder, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX - shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: shoulder + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: shoulder, y: rect.maxY - bottom), control: CGPoint(x: shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: shoulder, y: shoulder))
        path.addQuadCurve(to: .zero, control: CGPoint(x: shoulder, y: 0))
        path.closeSubpath(); return path
    }
}

private struct NotchView: View {
    var state: NotchPresentation
    var model: MailboxModel
    let hover: (Bool) -> Void
    let expand: () -> Void
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear.frame(height: state.topInset)
            HStack(spacing: 8) {
                Image(systemName: "tray.fill").foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && !state.expanded)
                Text(state.preview ? "SIFT · ÖNİZLEME" : "SIFT · ÖNEMLİ POSTA").font(.caption2.weight(.semibold)).tracking(1.4)
                Spacer()
                if state.messages.count > 1 { Text("+\(state.messages.count - 1)").font(.caption.monospacedDigit()).foregroundStyle(.orange) }
                Button(action: dismiss) { Image(systemName: "xmark").font(.caption) }.buttonStyle(.plain).accessibilityLabel("Bildirimi kapat")
            }
            if let message = state.messages.first {
                Button(action: expand) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(message.sender.prefix(1))).font(.title3.weight(.semibold))
                            .frame(width: 40, height: 40).background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.cache.preferences.hidePreview ? "Yeni önemli e-posta" : message.sender).font(.headline).lineLimit(1)
                            Text(model.cache.preferences.hidePreview ? "Ayrıntıları Sift’te aç" : message.subject).font(.subheadline).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                            if state.expanded && !model.cache.preferences.hidePreview {
                                Text(message.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                if state.expanded {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            Button { model.archive(message) } label: { Image(systemName: "archivebox") }.help("Arşivle").accessibilityLabel("Arşivle")
                            Button { model.reply(message) } label: { Image(systemName: "arrowshape.turn.up.left") }.help("Yanıtla").accessibilityLabel("Yanıtla")
                            Button { model.snooze(message) } label: { Image(systemName: "clock") }.help("1 saat ertele").accessibilityLabel("1 saat ertele")
                            Button { model.prefer(message, mute: true) } label: { Image(systemName: "bell.slash") }.help("Göndereni sessize al").accessibilityLabel("Göndereni sessize al")
                            Spacer()
                            Button("Sift’te aç") { model.openMessage(message) }
                        }.buttonStyle(.glass).disabled(state.preview || model.syncing || model.busy.contains(message.id))
                    }
                    Divider().overlay(.white.opacity(0.08))
                    ForEach(Array(state.messages.dropFirst().prefix(3))) { next in
                        HStack { Text(model.cache.preferences.hidePreview ? "Önemli posta" : next.sender).font(.caption.weight(.semibold)); Spacer(); Text(model.cache.preferences.hidePreview ? "" : next.subject).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    }
                    if state.preview { Text("Örnek bildirim · Hesabındaki hiçbir postayı değiştirmez").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            if state.messages.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Her şey sakin.").font(.title3.weight(.semibold))
                    Text(model.cache.accounts.isEmpty ? "Hesabını bağla; önemli postaların burada görünsün." : "Şu anda dikkatini bekleyen önemli bir posta yok.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Sift’i aç") {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first(where: { $0.title == "Sift" })?.makeKeyAndOrderFront(nil)
                        dismiss()
                    }.buttonStyle(.glass)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30).padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            if reduceTransparency { Color.black }
            else { Rectangle().fill(.ultraThinMaterial).overlay(.black.opacity(0.92)) }
        }
        .clipShape(NotchSilhouette(hardware: state.hardware))
        .overlay(alignment: .bottom) { Capsule().fill(.orange.opacity(0.65)).frame(width: 36, height: 3).padding(.bottom, 7) }
        .foregroundStyle(.white)
        .onHover(perform: hover)
    }
}
