//
//  RegisterView.swift
//  PandaCoin
//
//  Created by kevin on 2025/11/20.
//

import SwiftUI
import Combine

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.large) {
                        // 头部
                        VStack(spacing: Spacing.small) {
                            Text("🐼")
                                .font(.system(size: 60))
                            
                            Text("创建账户")
                                .font(AppFont.title(size: 28))
                                .foregroundColor(Theme.text)
                        }
                        .padding(.top, Spacing.large)
                        
                        // 表单
                        VStack(spacing: Spacing.large) {
                            // 昵称
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("昵称(可选)")
                                    .font(AppFont.body(size: 14, weight: .medium))
                                    .foregroundColor(Theme.text)
                                
                                TextField("请输入昵称", text: $name)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // 邮箱
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("邮箱")
                                    .font(AppFont.body(size: 14, weight: .medium))
                                    .foregroundColor(Theme.text)
                                
                                TextField("请输入邮箱", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }
                            
                            // 密码
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("密码")
                                    .font(AppFont.body(size: 14, weight: .medium))
                                    .foregroundColor(Theme.text)
                                
                                SecureField("至少6位密码", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.newPassword)
                            }
                            
                            // 确认密码
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("确认密码")
                                    .font(AppFont.body(size: 14, weight: .medium))
                                    .foregroundColor(Theme.text)
                                
                                SecureField("再次输入密码", text: $confirmPassword)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .textContentType(.newPassword)
                            }
                            
                            // 密码验证提示
                            if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                                Text("两次密码输入不一致")
                                    .font(AppFont.body(size: 12))
                                    .foregroundColor(Theme.expense)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // 错误提示
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .font(AppFont.body(size: 12))
                                    .foregroundColor(Theme.expense)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // 注册按钮
                            Button(action: handleRegister) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("注册")
                                        .font(AppFont.body(size: 18, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.bambooGreen)
                            .foregroundColor(.white)
                            .cornerRadius(CornerRadius.medium)
                            .disabled(isLoading || !isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.5)
                        }
                        .padding(.horizontal, Spacing.large)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    // MARK: - Actions
    private func handleRegister() {
        errorMessage = nil
        isLoading = true
        
        var cancellable: AnyCancellable?
        cancellable = authService.register(
            email: email,
            password: password,
            name: name.isEmpty ? nil : name
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [self] completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
                cancellable?.cancel()
            },
            receiveValue: { _ in
                // 注册成功,自动关闭
                dismiss()
            }
        )
    }
}

#Preview {
    RegisterView()
}
