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
    private var screenObserver: NSObjectProtocol?
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var screen: NSScreen?
    private var cameraWidth: CGFloat = 180
    private var visible = false
    private var hovering = false
    init(model: MailboxModel) {
        self.model = model
        panel = MailPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
        panel.level = .statusBar; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.contentView = NSHostingView(rootView: NotchView(state: state, model: model,
            hover: { [weak self] in self?.hover($0) }, expand: { [weak self] in self?.expand() },
            dismiss: { [weak self] in self?.hide() }).preferredColorScheme(.dark))
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.geometry(); self?.resize(animated: false) }
        }
        geometry()
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
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            cameraWidth = max(0, right.minX - left.maxX)
        }
    }
    func notify(_ messages: [MailMessage], preview: Bool = false, userInitiated: Bool = false) {
        guard !messages.isEmpty, let model else { return }
        if !preview && !userInitiated {
            guard model.cache.preferences.permitsAlert(at: .now), INFocusStatusCenter.default.focusStatus.isFocused != true else { return }
        }
        let combined = visible && !state.preview && !preview ? state.messages + messages : messages
        var ids: Set<UUID> = []
        state.messages = combined.filter { ids.insert($0.id).inserted }.sorted { $0.score > $1.score }
        state.preview = preview; state.expanded = false
        geometry()
        if !visible, let screen {
            let width = state.hardware ? cameraWidth : 200
            panel.setFrame(NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - max(1, state.topInset), width: width, height: max(1, state.topInset)), display: false)
        }
        visible = true; panel.ignoresMouseEvents = false
        panel.orderFrontRegardless(); resize(animated: true); scheduleHide()
    }
    func remove(_ id: UUID) {
        state.messages.removeAll { $0.id == id }
        if state.messages.isEmpty { hide() }
    }
    func hide() {
        timer?.cancel(); visible = false; hovering = false
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
        else if let model {
            let messages = model.messages.filter { $0.tier >= model.cache.preferences.minimumTier }
            notify(Array(messages.prefix(4)), preview: model.demo, userInitiated: true); expand()
        }
    }
    private func scheduleHide() {
        timer?.cancel()
        guard !hovering else { return }
        let duration = max(3, min(30, model?.cache.preferences.alertDuration ?? 8))
        timer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(duration)) } catch { return }
            self?.hide()
        }
    }
    private func resize(animated: Bool) {
        guard visible, let screen else { return }
        let width = min(max(state.expanded ? 560 : 460, cameraWidth + 100), screen.frame.width - 32)
        let height = state.topInset + (state.expanded ? 322.0 : 142.0)
        let y = state.hardware ? screen.frame.maxY - height : screen.visibleFrame.maxY - height - 8
        let frame = NSRect(x: screen.frame.midX - width / 2, y: y, width: width, height: height)
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28; context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.85, 0.25, 1)
                panel.animator().setFrame(frame, display: true)
            }
        } else { panel.setFrame(frame, display: true) }
    }
    isolated deinit {
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
                            Button { model.archive(message) } label: { Image(systemName: "archivebox") }.help("Arşivle")
                            Button { model.reply(message) } label: { Image(systemName: "arrowshape.turn.up.left") }.help("Yanıtla")
                            Button { model.snooze(message) } label: { Image(systemName: "clock") }.help("1 saat ertele")
                            Button { model.prefer(message, mute: true) } label: { Image(systemName: "bell.slash") }.help("Göndereni sessize al")
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
