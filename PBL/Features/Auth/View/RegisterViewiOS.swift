//
//  RegisterViewiOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

struct RegisterViewiOS: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isTeacher: Bool = false
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    var emailDomain: String {
        email.components(separatedBy: "@").last ?? ""
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                TextField("姓名", text: $name)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .disabled(isLoading)

                TextField("邮箱", text: $email)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .disabled(isLoading)

                SecureField("密码（至少6位）", text: $password)
                    .font(.system(size: 14))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .disabled(isLoading)

                SecureField("确认密码", text: $confirmPassword)
                    .font(.system(size: 14))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .disabled(isLoading)

                Toggle("我是教师", isOn: $isTeacher)
                    .font(.system(size: 14))
                    .padding(.horizontal, 40)
                    .disabled(isLoading)

                Button(action: handleRegister) {
                    Text(isLoading ? "注册中..." : "创建账号")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(isLoading || name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
                .padding(.horizontal, 40)

                Button("已有账号？返回登录") { dismiss() }
                    .font(.system(size: 14))
            }
            .padding(.vertical, 20)
            .navigationTitle("创建账号")
            .navigationBarTitleDisplayMode(.inline)
            .alert("错误", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    func handleRegister() {
        guard password == confirmPassword else {
            alertMessage = "两次输入的密码不一致"
            showAlert = true
            return
        }
        guard password.count >= 6 else {
            alertMessage = "密码至少需要6位字符"
            showAlert = true
            return
        }

        isLoading = true
        Task {
            do {
                let success = try await tryRegister(
                    appState: appState,
                    name: name,
                    email: email,
                    password: password,
                    isTeacher: isTeacher,
                    emailDomain: emailDomain
                )
                if !success {
                    alertMessage = "不支持的教育机构域名"
                    showAlert = true
                }
            } catch let error as APIError {
                alertMessage = error.message
                showAlert = true
            } catch {
                alertMessage = "注册失败: \(error.localizedDescription)"
                showAlert = true
            }
            isLoading = false
        }
    }
}
