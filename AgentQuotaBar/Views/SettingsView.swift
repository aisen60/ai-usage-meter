import SwiftUI

/// 设置面板
struct SettingsView: View {
    @ObservedObject var controller: QuotaController
    @Environment(\.dismiss) private var dismiss

    @State private var tokenInput = ""
    @State private var showToken = false
    @State private var tokenSaveMessage: String?
    @State private var refreshIntervalIndex = 0

    // 刷新间隔选项
    private let refreshIntervals: [(String, TimeInterval)] = [
        ("5 分钟", 5 * 60),
        ("15 分钟", 15 * 60),
        ("30 分钟", 30 * 60),
        ("60 分钟", 60 * 60)
    ]

    var body: some View {
        NavigationView {
            Form {
                // === Cursor Token 设置 ===
                Section("Cursor") {
                    HStack {
                        if showToken {
                            TextField("粘贴 WorkosCursorSessionToken", text: $tokenInput)
                        } else {
                            SecureField("粘贴 WorkosCursorSessionToken", text: $tokenInput)
                        }

                        Button(showToken ? "隐藏" : "显示") {
                            showToken.toggle()
                        }
                        .controlSize(.small)
                    }

                    HStack {
                        Button("保存 Token") {
                            controller.saveManualToken(tokenInput)
                            tokenSaveMessage = "已保存"
                            tokenInput = ""
                        }
                        .disabled(tokenInput.isEmpty)

                        if let msg = tokenSaveMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    Text("在 cursor.com 的 DevTools → Application → Cookies 中获取 WorkosCursorSessionToken")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // === Codex 手动录入 ===
                Section("Codex") {
                    CodexManualInput(controller: controller)

                    Button("打开 Codex 用量页面") {
                        CodexIntegration.openUsagePage()
                    }
                }

                // === 刷新设置 ===
                Section("刷新设置") {
                    Picker("刷新间隔", selection: $refreshIntervalIndex) {
                        ForEach(0..<refreshIntervals.count, id: \.self) { i in
                            Text(refreshIntervals[i].0).tag(i)
                        }
                    }
                    .onChange(of: refreshIntervalIndex) { newIndex in
                        controller.refreshInterval = refreshIntervals[newIndex].1
                    }
                }

                // === 关于 ===
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    Link("GitHub 仓库", destination: URL(
                        string: "https://github.com/aisen60/agent-quota-bar"
                    )!)
                }
            }
            .navigationTitle("Agent Quota Bar 设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .frame(width: 420, height: 480)
        .onAppear {
            // 设置当前刷新间隔的选中状态
            if let idx = refreshIntervals.firstIndex(
                where: { abs($0.1 - controller.refreshInterval) < 1 }
            ) {
                refreshIntervalIndex = idx
            }
        }
    }
}

/// Codex 手动录入子视图
struct CodexManualInput: View {
    @ObservedObject var controller: QuotaController
    @State private var planName = "Codex Pro"
    @State private var percentRemaining: Double = 100
    @State private var hasCycleEnd = false
    @State private var cycleEndDate = Date()
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("套餐名称", text: $planName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 2) {
                Text("剩余额度: \(Int(percentRemaining))%")
                    .font(.caption)
                Slider(value: $percentRemaining, in: 0...100, step: 1)
            }

            Toggle("设置账期截止日期", isOn: $hasCycleEnd)

            if hasCycleEnd {
                DatePicker(
                    "截止日期",
                    selection: $cycleEndDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }

            TextField("备注 (可选)", text: $note)
                .textFieldStyle(.roundedBorder)

            Button("保存") {
                controller.saveManualCodexUsage(
                    planName: planName,
                    percentRemaining: percentRemaining,
                    cycleEndDate: hasCycleEnd ? cycleEndDate : nil,
                    note: note.isEmpty ? nil : note
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}
