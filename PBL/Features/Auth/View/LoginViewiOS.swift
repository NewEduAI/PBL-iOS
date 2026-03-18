//
//  LoginViewiOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/1/21.
//

import SwiftUI

struct LoginViewiOS: View {
    @Environment(AppState.self) private var appState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showRegister: Bool = false

    var emailDomain: String {
        email.components(separatedBy: "@").last ?? ""
    }

    var body: some View {
        VStack(spacing: 20) {
            BrandingText(fontSize: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text("子曰：知而不行，与不知同。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 60)
                Text("——《论语·阳货》")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 60)
            }
            .padding(.horizontal, 40)

            TextField("邮箱", text: $email)
                .font(.system(size: 14))
                .textInputAutocapitalization(.none)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .disabled(isLoading)

            SecureField("密码", text: $password)
                .font(.system(size: 14))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .disabled(isLoading)

            Button(action: handleLogin) {
                Text(isLoading ? "登录中..." : "登录")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLoading ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .padding(.horizontal, 40)

            HStack(spacing: 4) {
                Text("还没有账号？")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Button("立即注册") { showRegister = true }
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .alert("错误", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showRegister) {
            RegisterViewiOS()
                .environment(appState)
        }
    }

    func handleLogin() {
        isLoading = true
        Task {
            do {
                let success = try await tryLogin(
                    appState: appState,
                    email: email,
                    password: password,
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
                alertMessage = "登录失败: \(error.localizedDescription)"
                showAlert = true
            }
            isLoading = false
        }
    }
}
