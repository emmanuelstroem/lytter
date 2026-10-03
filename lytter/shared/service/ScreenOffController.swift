//
//  ScreenOffController.swift
//  lytter
//

#if os(iOS) || os(tvOS)
import Combine
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Blacks the screen out while playing, after a spell without interaction (F43).
///
/// For a radio left playing on a TV, or a phone on a stand. The sound carries on; the first
/// touch or press afterwards only brings the screen back, and does not reach whatever it
/// landed on — nobody waking a black screen means to press the button under their thumb.
///
/// The black is a window of its own above the app's, not an overlay in the view tree. An
/// overlay sits under any sheet, and the full player — the screen most likely to be left
/// up — is a sheet. A window covers everything, and while it is the key window it is also
/// what receives the next touch or press, which is how that first one is kept from the app.
///
/// `preventScreenSleep` in `AudioPlayerService` is a different thing: it stops the system
/// sleeping, and is left alone. This only decides what the screen shows while it is awake.
@MainActor
final class ScreenOffController {
    private weak var window: UIWindow?
    private var curtain: CurtainWindow?
    private let preferences: UserPreferencesService

    private var lastActivity = Date()
    private var isPlaying = false
    private var delay: ScreenOffDelay
    private var countdown: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(serviceManager: DRServiceManager) {
        preferences = serviceManager.userPreferences
        delay = preferences.screenOffDelay

        serviceManager.$isPlaying
            .removeDuplicates()
            .sink { [weak self] playing in
                self?.isPlaying = playing
                self?.noteActivity()
            }
            .store(in: &cancellables)

        preferences.$screenOffDelay
            .removeDuplicates()
            .sink { [weak self] delay in
                self?.delay = delay
                self?.noteActivity()
            }
            .store(in: &cancellables)
    }

    /// Starts watching `window` for interaction. Called again for the same window, it does
    /// nothing.
    func attach(to window: UIWindow) {
        guard self.window !== window else { return }
        self.window = window
        window.addGestureRecognizer(ActivityRecogniser { [weak self] in self?.noteActivity() })
    }

    private var isBlackedOut: Bool { curtain.map { !$0.isHidden } ?? false }

    /// Restarts the countdown from now.
    private func noteActivity() {
        lastActivity = Date()
        countdown?.cancel()

        guard !isBlackedOut,
              let blackout = delay.blackoutTime(after: lastActivity, isPlaying: isPlaying)
        else { return }

        countdown = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, blackout.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.blackOut()
        }
    }

    private func blackOut() {
        guard let scene = window?.windowScene else { return }
        let curtain = self.curtain ?? CurtainWindow(windowScene: scene) { [weak self] in
            self?.wake()
        }
        self.curtain = curtain
        curtain.makeKeyAndVisible()
        UIAccessibility.post(notification: .screenChanged, argument: curtain.rootViewController?.view)
    }

    private func wake() {
        curtain?.isHidden = true
        window?.makeKey()
        UIAccessibility.post(notification: .screenChanged, argument: nil)
        noteActivity()
    }
}

/// Notices every touch and press in the window it is attached to, and recognises none.
///
/// It fails as soon as anything begins, so it never holds up, cancels or competes with the
/// gestures and buttons that the touch or press was meant for.
private final class ActivityRecogniser: UIGestureRecognizer {
    private let onActivity: () -> Void

    init(onActivity: @escaping () -> Void) {
        self.onActivity = onActivity
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onActivity()
        state = .failed
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
        onActivity()
        state = .failed
    }
}

/// The black, in a window above the app's.
///
/// It handles every touch and press it is sent and passes none on: the first one wakes
/// the screen and is otherwise swallowed. On tvOS that includes Menu, which would
/// otherwise leave the app from a screen the viewer cannot see.
private final class CurtainWindow: UIWindow {
    private let onWake: () -> Void

    init(windowScene: UIWindowScene, onWake: @escaping () -> Void) {
        self.onWake = onWake
        super.init(windowScene: windowScene)
        windowLevel = .alert + 1
        backgroundColor = .black
        rootViewController = CurtainViewController(onWake: onWake)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { onWake() }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) { onWake() }
}

private final class CurtainViewController: UIViewController {
    private let onWake: () -> Void

    init(onWake: @escaping () -> Void) {
        self.onWake = onWake
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        let view = CurtainView(onWake: onWake)
        view.backgroundColor = .black
        self.view = view
    }

    #if os(iOS)
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    #endif
}

/// One element for VoiceOver, which a double-tap activates. The black is otherwise
/// invisible to it, and a VoiceOver user would be left on a screen with nothing to find.
private final class CurtainView: UIView {
    private let onWake: () -> Void

    init(onWake: @escaping () -> Void) {
        self.onWake = onWake
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityIdentifier = "screenOff.curtain"
        accessibilityLabel = String(localized: "Screen off")
        accessibilityHint = String(localized: "Turns the screen back on.")
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func accessibilityActivate() -> Bool {
        onWake()
        return true
    }
}

/// Hands `ScreenOffController` the window the app is in.
///
/// SwiftUI does not say which window it is drawing into; a UIKit view placed in the
/// hierarchy finds out when it is added to one. The controller is this view's coordinator,
/// so it lives exactly as long as the screen it watches.
struct ScreenOffInstaller: UIViewRepresentable {
    let serviceManager: DRServiceManager

    func makeCoordinator() -> ScreenOffController {
        ScreenOffController(serviceManager: serviceManager)
    }

    func makeUIView(context: Context) -> WindowProbe {
        let probe = WindowProbe()
        probe.isUserInteractionEnabled = false
        let controller = context.coordinator
        probe.onWindow = { controller.attach(to: $0) }
        return probe
    }

    func updateUIView(_ uiView: WindowProbe, context: Context) {}

    final class WindowProbe: UIView {
        var onWindow: (UIWindow) -> Void = { _ in }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { onWindow(window) }
        }
    }
}
#endif
