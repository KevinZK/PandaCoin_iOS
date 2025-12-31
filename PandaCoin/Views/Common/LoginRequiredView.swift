//
//  LoginRequiredView.swift
//  PandaCoin
//
//  Created by AI Assistant on 2025/12/31.
//

import SwiftUI
import AuthenticationServices
import Combine

struct LoginRequiredView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    let featureName: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(Theme.bambooGreen.opacity(0.1))
                    .frame(width: 100, height: 100)
                Text("🔒")
                    .font(.system(size: 48))
            }

            // 标题
            Text("需要登录")
                .font(AppFont.title(size: 24))
                .foregroundColor(Theme.text)

            // 描述
            Text("登录后即可使用「\(featureName)」功能")
                .font(AppFont.body(size: 16))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Apple Sign In 按钮
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: handleAppleSignIn
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            .padding(.horizontal, 32)

            // Debug 一键登录
            #if DEBUG
            Button(action: debugAutoLogin) {
                HStack {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 14))
                    Text("[DEBUG] 一键登录")
                        .font(AppFont.body(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)
            .padding(.horizontal, 32)
            #endif

            if isLoading {
                ProgressView()
                    .padding()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // 取消按钮
            Button(action: { dismiss() }) {
                Text("稍后再说")
                    .font(AppFont.body(size: 16))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.bottom, 32)
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    // MARK: - Apple Sign In Handler
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "无法获取 Apple 登录凭证"
                return
            }

            let appleUserId = appleIDCredential.user
            let email = appleIDCredential.email
            var fullName: String? = nil
            if let nameComponents = appleIDCredential.fullName {
                let parts = [nameComponents.familyName, nameComponents.givenName].compactMap { $0 }
                if !parts.isEmpty {
                    fullName = parts.joined(separator: "")
                }
            }

            isLoading = true
            errorMessage = nil

            authService.appleLogin(
                identityToken: identityToken,
                appleUserId: appleUserId,
                email: email,
                fullName: fullName
            )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    // 登录成功，AuthService 会自动更新状态
                }
            )
            .store(in: &cancellables)

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple 登录失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Debug Auto Login
    #if DEBUG
    private func debugAutoLogin() {
        isLoading = true
        errorMessage = nil

        authService.login(
            email: DebugConfig.TestAccount.email,
            password: DebugConfig.TestAccount.password
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            },
            receiveValue: { _ in
                // 登录成功
            }
        )
        .store(in: &cancellables)
    }
    #endif
}

#Preview {
    LoginRequiredView(featureName: "资产管理")
}
