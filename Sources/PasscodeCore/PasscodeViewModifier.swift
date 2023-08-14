//
//  PasscodeViewModifier.swift
//  PasscodeCore
//
//  Created by David Walter on 12.08.23.
//

import SwiftUI
import WindowSceneReader

struct PasscodeViewModifierHelper<I, B>: ViewModifier where I: View, B: View {
    var mode: PasscodeMode
    @ViewBuilder var input: (_ dismiss: DismissPasscodeAction) -> I
    @ViewBuilder var background: () -> B
    
    func body(content: Content) -> some View {
        content
            .background {
                WindowSceneReader { windowScene in
                    Color.clear
                        .modifier(PasscodeViewModifier(windowScene: windowScene, mode: mode, input: input, background: background))
                }
            }
    }
}

struct PasscodeViewModifier<I, B>: ViewModifier where I: View, B: View {
    var windowScene: UIWindowScene
    var mode: PasscodeMode
    @ViewBuilder var input: (_ dismiss: DismissPasscodeAction) -> I
    @ViewBuilder var background: () -> B
    
    @State private var isShowingPasscode = false
    @State private var window: UIWindow?
    
    init(windowScene: UIWindowScene, mode: PasscodeMode, input: @escaping (DismissPasscodeAction) -> I, background: @escaping () -> B) {
        self.windowScene = windowScene
        self.mode = mode
        self.input = input
        self.background = background
    }
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                switch mode {
                case .alwaysVisible, .hideInAppSwitcher:
                    showWindow()
                    isShowingPasscode = true
                case .autohide, .disabled:
                    isShowingPasscode = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                switch mode {
                case .alwaysVisible:
                    isShowingPasscode = true
                case .hideInAppSwitcher, .autohide, .disabled:
                    isShowingPasscode = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                switch mode {
                case .disabled:
                    return
                default:
                   showWindow()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                switch mode {
                case .hideInAppSwitcher, .alwaysVisible:
                    isShowingPasscode = true
                case .disabled:
                    isShowingPasscode = false
                case .autohide:
                    hideWindow(animated: false)
                }
            }
    }
    
    private func showWindow() {
        guard window == nil else { return }
        
        let rootView = PasscodeRootView(
            isShowingPasscode: $isShowingPasscode,
            view: input,
            background: background
        )
        .onDismissPasscode { animated in
            hideWindow(animated: animated)
        }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = PasscodeBlurViewController(rootView: rootView)
        window.makeKeyAndVisible()
        
        self.window = window
    }
    
    private func hideWindow(animated: Bool) {
        guard let window = window else { return }
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                window.alpha = 0
            } completion: { _ in
                window.resignKey()
                self.window = nil
            }
        } else {
            window.resignKey()
            self.window = nil
        }
    }
}
