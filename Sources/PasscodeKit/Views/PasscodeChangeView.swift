//
//  PasscodeChangeView.swift
//  PasscodeKit
//
//  Created by David Walter on 19.10.23.
//

import SwiftUI
import PasscodeCore
import LocalAuthentication

public struct PasscodeChangeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.passcode.manager) private var passcodeManager
    
    enum Step: String, Identifiable {
        case current
        case new
        case reEnter
        
        var id: String { rawValue }
    }
    
    var type: PasscodeType
    var allowBiometrics: Bool
    var onCompletion: (Passcode) -> Void
    
    @State private var code = ""
    @State private var currentStep: Step = .current
    @State private var showBiometrics = false
    
    @State private var numberOfAttempts = 0
    
    @State private var task: Task<Void, Never>?
    
    public init(
        type: PasscodeType,
        allowBiometrics: Bool = true,
        onCompletion: @escaping (Passcode) -> Void
    ) {
        self.type = type
        self.allowBiometrics = allowBiometrics
        self.onCompletion = onCompletion
    }
    
    public var body: some View {
        ZStack {
            switch currentStep {
            case .current:
                if let passcode = passcodeManager.passcode {
                    currentView(passcode: passcode)
                        .zIndex(0)
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .move(edge: .leading)
                            )
                        )
                } else {
                    inputView
                        .zIndex(0)
                        .transition(.move(edge: .leading))
                }
            case .new:
                inputView
                    .zIndex(0)
                    .transition(
                        .asymmetric(
                            insertion: numberOfAttempts == 0 ? .move(edge: .trailing) : .move(edge: .leading),
                            removal: .move(edge: .leading)
                        )
                    )
            case .reEnter:
                reEnterInputView
                    .zIndex(1)
                    .transition(.move(edge: .trailing))
            }
        }
        .confirmationDialog(localizedBiometrics ?? "", isPresented: $showBiometrics, titleVisibility: localizedBiometrics != nil ? .visible : .hidden) {
            Button {
                self.task = Task { @MainActor in
                    let context = LAContext()
                    do {
                        let reason = "passcode.biometrics.reason".localized()
                        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                        if success {
                            onCompletion(Passcode(code, type: type, allowBiometrics: true))
                        } else {
                            showBiometrics = true
                        }
                    } catch {
                        showBiometrics = true
                    }
                }
            } label: {
                Text(verbatim: "passcode.biometrics.setup.button".localized())
            }
            
            Button(role: .cancel) {
                onCompletion(Passcode(code, type: type, allowBiometrics: false))
            } label: {
                Text(verbatim: "passcode.biometrics.setup.cancel".localized())
            }
        } message: {
            if let localizedBiometrics {
                Text(verbatim: String(format: "passcode.biometrics.setup.message".localized(), localizedBiometrics))
            }
        }
        .animation(.default, value: currentStep)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("cancel".localized())
                }
            }
        }
    }
    
    var navigationTitle: String {
        if passcodeManager.isSetup {
            return "passcode.change.title".localized()
        } else {
            return "passcode.create.title".localized()
        }
    }
    
    func currentView(passcode: Passcode) -> some View {
        InternalPasscodeInputView(type: passcode.type, canCancel: false) { code in
            if code == passcode.code {
                return true
            } else {
                return fail(next: .current)
            }
        } onCompletion: { success in
            guard success else { return }
            currentStep = .new
        } hint: {
            Text("passcode.enter.current.hint".localized())
        }
    }
    
    var inputView: some View {
        InternalPasscodeInputView(type: type, canCancel: false) { code in
            self.code = code
            return true
        } onCompletion: { _ in
            currentStep = .reEnter
        } hint: {
            if numberOfAttempts > 0 {
                Text("passcode.enter.failed.hint".localized())
            } else {
                Text("passcode.enter.hint".localized())
            }
        }
    }
    
    var reEnterInputView: some View {
        InternalPasscodeInputView(type: type, canCancel: false) { code in
            if self.code == code {
                return true
            } else {
                return fail(next: .new)
            }
        } onCompletion: { success in
            if allowBiometrics, canUseBiometrics {
                showBiometrics = true
            } else {
                onCompletion(Passcode(code, type: type, allowBiometrics: false))
            }
        } hint: {
            Text("passcode.enter.again.hint".localized())
        }
        .onDisappear {
            task?.cancel()
        }
    }
    
    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    var localizedBiometrics: String? {
        switch LAContext().biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return nil
        }
    }
    
    func fail(next: Step) -> Bool {
        withAnimation(.default) {
            if currentStep == .reEnter {
                numberOfAttempts += 1
            }
            currentStep = next
            
            self.task = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                    withAnimation(.default) {
                        reset(to: next)
                    }
                } catch {
                    reset(to: next)
                }
            }
        }
        
        return false
    }
    
    func reset(to step: Step) {
        code = ""
        currentStep = step
    }
}

struct PasscodeChangeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PasscodeChangeView(type: .numeric(4)) { code in
                print(code)
            }
        }
    }
}
