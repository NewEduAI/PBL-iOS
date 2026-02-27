//
//  LoginViewMacOS.swift
//  PBL
//
//  Created by Daniel Zhang-Li on 2026/2/25.
//

import SwiftUI

struct LoginViewMacOS: View {
    @Environment(AppState.self) private var appState

    @AppStorage("lastLoginEmail") private var savedEmail: String = ""
    #if DEBUG
    @AppStorage("lastLoginPassword") private var savedPassword: String = ""
    #endif

    @State private var showRegister: Bool = false

    // Login fields
    @State private var email: String = ""
    @State private var password: String = ""

    // Register fields
    @State private var regName: String = ""
    @State private var regEmail: String = ""
    @State private var regPassword: String = ""
    @State private var regConfirmPassword: String = ""
    @State private var regIsTeacher: Bool = false

    // Shared
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    @FocusState private var loginFocus: LoginField?
    @FocusState private var registerFocus: RegisterField?

    enum LoginField: Hashable { case email, password }
    enum RegisterField: Hashable { case name, email, password, confirmPassword }

    var emailDomain: String {
        let src = showRegister ? regEmail : email
        return src.components(separatedBy: "@").last ?? ""
    }

    var body: some View {
        HStack(spacing: 0) {

                // Left panel — branding with background image
                VStack(spacing: 16) {
                    Text("MAIC-PBL")
                        .italic()
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(LinearGradient(
                            colors: [
                                Color(red: 98/255, green: 83/255, blue: 225/255),
                                Color(red: 4/255, green: 190/255, blue: 254/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Text("子曰：知而不行，与不知同。")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(red: 55/255, green: 65/255, blue: 81/255))
                    Text("《论语·阳货》")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 75/255, green: 85/255, blue: 99/255))
                }
                .padding(48)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Image("AuthBackground")
                        .resizable()
                        .scaledToFill()
                        .clipped()
                )

                // Right panel — frosted glass, swaps between login and register in place
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 32) {

                            // Header
                            VStack(spacing: 8) {
                                Text(showRegister ? "加入我们" : "欢迎回来")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(Color(red: 17/255, green: 24/255, blue: 39/255))
                                Text(showRegister ? "创建账号以开始使用" : "请登录以继续")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(red: 107/255, green: 114/255, blue: 128/255))
                            }
                            .frame(maxWidth: .infinity)

                            // Form card
                            VStack(alignment: .leading, spacing: 24) {

                                if let error = errorMessage {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "xmark.circle.fill")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .foregroundStyle(Color(red: 248/255, green: 113/255, blue: 113/255))
                                        Text(error)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color(red: 153/255, green: 27/255, blue: 27/255))
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(red: 254/255, green: 242/255, blue: 242/255))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                if showRegister {
                                    registerFields
                                } else {
                                    loginFields
                                }

                                // Submit button
                                Button(action: showRegister ? handleRegister : handleLogin) {
                                    Group {
                                        if isLoading {
                                            Text(showRegister ? "注册中..." : "登录中...")
                                        } else {
                                            Text(showRegister ? "创建账号" : "登录")
                                        }
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(red: 37/255, green: 99/255, blue: 235/255))
                                            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(submitDisabled)
                                .opacity(isLoading ? 0.5 : 1)

                                // Footer link
                                HStack(spacing: 4) {
                                    Text(showRegister ? "已有账号？" : "还没有账号？")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(red: 107/255, green: 114/255, blue: 128/255))
                                    Button(showRegister ? "立即登录" : "立即注册") {
                                        errorMessage = nil
                                        showRegister.toggle()
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(red: 37/255, green: 99/255, blue: 235/255))
                                    .buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(32)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                            .animation(.easeInOut(duration: 0.2), value: showRegister)
                        }
                        .padding(32)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
                    }
                }
                .frame(width: 380)
                .background(Color(red: 248/255, green: 249/255, blue: 250/255))
                .layoutPriority(1)
        }
        .ignoresSafeArea()
        .onAppear {
            if email.isEmpty { email = savedEmail }
            #if DEBUG
            if password.isEmpty { password = savedPassword }
            #endif
        }
    }

    // MARK: - Login fields

    @ViewBuilder
    var loginFields: some View {
        loginFieldView(label: "邮箱", placeholder: "your-email@tsinghua.edu.cn", text: $email, field: .email, secure: false)
        loginFieldView(label: "密码", placeholder: "输入你的密码", text: $password, field: .password, secure: true)
    }

    // MARK: - Register fields

    @ViewBuilder
    var registerFields: some View {
        registerFieldView(label: "姓名", placeholder: "输入你的姓名", text: $regName, field: .name, secure: false)
        registerFieldView(label: "邮箱", placeholder: "your-email@tsinghua.edu.cn", text: $regEmail, field: .email, secure: false)
        registerFieldView(label: "密码", placeholder: "至少6位字符", text: $regPassword, field: .password, secure: true)
        registerFieldView(label: "确认密码", placeholder: "再次输入密码", text: $regConfirmPassword, field: .confirmPassword, secure: true)
        HStack(spacing: 8) {
            Toggle("", isOn: $regIsTeacher)
                .toggleStyle(.checkbox)
                .labelsHidden()
            Text("我是教师")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 55/255, green: 65/255, blue: 81/255))
        }
    }

    // MARK: - Disabled state

    var submitDisabled: Bool {
        if isLoading { return true }
        if showRegister {
            return regName.isEmpty || regEmail.isEmpty || regPassword.isEmpty || regConfirmPassword.isEmpty
        }
        return email.isEmpty || password.isEmpty
    }

    // MARK: - Field views

    @ViewBuilder
    func loginFieldView(label: String, placeholder: String, text: Binding<String>, field: LoginField, secure: Bool) -> some View {
        fieldView(label: label, placeholder: placeholder, text: text, isFocused: loginFocus == field, secure: secure) {
            loginFocus = field
        }
        .focused($loginFocus, equals: field)
        .onChange(of: text.wrappedValue) { errorMessage = nil }
        .textContentType(field == .email ? .username : .password)
    }

    @ViewBuilder
    func registerFieldView(label: String, placeholder: String, text: Binding<String>, field: RegisterField, secure: Bool) -> some View {
        fieldView(label: label, placeholder: placeholder, text: text, isFocused: registerFocus == field, secure: secure) {
            registerFocus = field
        }
        .focused($registerFocus, equals: field)
        .onChange(of: text.wrappedValue) { errorMessage = nil }
        .textContentType({
            switch field {
            case .name:            return nil
            case .email:           return .username
            case .password:        return .newPassword
            case .confirmPassword: return .newPassword
            }
        }())
    }

    @ViewBuilder
    func fieldView(label: String, placeholder: String, text: Binding<String>, isFocused: Bool, secure: Bool, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 55/255, green: 65/255, blue: 81/255))
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(Color(red: 17/255, green: 24/255, blue: 39/255))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isFocused
                            ? Color(red: 37/255, green: 99/255, blue: 235/255)
                            : Color(red: 209/255, green: 213/255, blue: 219/255),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .disabled(isLoading)
        }
    }

    // MARK: - Actions

    func handleLogin() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let success = try await tryLogin(
                    appState: appState,
                    email: email,
                    password: password,
                    emailDomain: emailDomain
                )
                if success {
                    savedEmail = email
                    #if DEBUG
                    savedPassword = password
                    #endif
                } else { errorMessage = "不支持的教育机构域名" }
            } catch let error as APIError {
                errorMessage = error.message
            } catch {
                errorMessage = "登录失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func handleRegister() {
        guard regPassword == regConfirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        guard regPassword.count >= 6 else {
            errorMessage = "密码至少需要6位字符"
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let success = try await tryRegister(
                    appState: appState,
                    name: regName,
                    email: regEmail,
                    password: regPassword,
                    isTeacher: regIsTeacher,
                    emailDomain: regEmail.components(separatedBy: "@").last ?? ""
                )
                if !success { errorMessage = "不支持的教育机构域名" }
            } catch let error as APIError {
                errorMessage = error.message
            } catch {
                errorMessage = "注册失败: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
