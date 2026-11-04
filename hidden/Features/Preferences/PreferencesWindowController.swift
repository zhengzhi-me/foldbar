//
//  PreferencesWindowController.swift
//  Hidden Bar
//
//  Created by Phuc Le Dien on 2/22/19.
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    static let shared: PreferencesWindowController = {
        let controller = NSHostingController(rootView: FoldBarSettings())
        let window = NSWindow(contentViewController: controller)
        window.title = "FoldBar"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 475))
        window.isReleasedWhenClosed = false
        window.center()
        return PreferencesWindowController(window: window)
    }()

    // Legacy storyboard action; the settings window is now created in code.
    @IBAction func switchSegment(_ sender: NSSegmentedControl) {}
}

private struct FoldBarSettings: View {
    @AppStorage(UserDefaults.Key.isAutoStart) private var launchAtLogin = false
    @AppStorage(UserDefaults.Key.alwaysHideDockIcon) private var hideDock = false
    @AppStorage(UserDefaults.Key.isAutoHide) private var autoHide = true
    @AppStorage(UserDefaults.Key.numberOfSecondForAutoHide) private var seconds = 10.0
    @State private var shortcut = Preferences.globalKey
    @State private var monitor: Any?
    @State private var status = ""
    @State private var checking = false
    @State private var newer = false
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    private let repo = URL(string: "https://github.com/zhengzhi-me/foldbar")!

    var body: some View {
        Form {
            Section("操作说明") {
                Label("按住 ⌘ 拖动菜单栏图标，调整图标分区。", systemImage: "command")
                Label("左键点按 < 展开隐藏图标；点按 > 收起。", systemImage: "chevron.left")
                Label("折叠时右键点按 <，打开设置与退出菜单。", systemImage: "gearshape")
                Label("展开时右键点按 >，切换持续隐藏区。", systemImage: "eye.slash")
            }
            Section("偏好设置") {
                Toggle("在登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { Util.setUpAutoStart(isAutoStart: $0) }
                Toggle("始终隐藏 Dock 图标", isOn: $hideDock)
                    .onChange(of: hideDock) { if $0 { NSApp.setActivationPolicy(.accessory) } }
                LabeledContent {
                    Picker("等待时间", selection: $seconds) {
                        ForEach([5.0, 10, 15, 30, 60], id: \.self) { Text("\(Int($0)) 秒").tag($0) }
                    }.labelsHidden().disabled(!autoHide)
                } label: { Toggle("自动隐藏图标", isOn: $autoHide) }
                LabeledContent("全局快捷键") {
                    Button(monitor != nil ? "请按快捷键…" : shortcut?.description ?? "录制快捷键", action: recordShortcut)
                    if shortcut != nil {
                        Button("清除") {
                            stopRecording()
                            shortcut = nil
                            Preferences.globalKey = nil
                            (NSApp.delegate as? AppDelegate)?.setupHotKey()
                        }
                    }
                }
            }
            Section("项目信息") {
                LabeledContent("当前版本", value: version)
                Link(destination: repo) { Label("GitHub · zhengzhi-me/foldbar", systemImage: "chevron.left.forwardslash.chevron.right") }
                LabeledContent {
                    Button("检查更新") { Task { await checkUpdates() } }.disabled(checking)
                } label: { Text(status.isEmpty ? "软件更新" : status) }
                if newer { Link("查看发行版本", destination: repo.appendingPathComponent("releases/latest")) }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 510, minHeight: 445)
        .onChange(of: autoHide) { _ in notifyPreferences() }
        .onChange(of: seconds) { _ in notifyPreferences() }
        .onDisappear { stopRecording() }
    }

    private func notifyPreferences() {
        NotificationCenter.default.post(name: .prefsChanged, object: nil)
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func recordShortcut() {
        stopRecording()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === PreferencesWindowController.shared.window else { return event }
            if event.keyCode == 53 { stopRecording(); return nil }
            let flags = event.modifierFlags
            guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
            let key = GlobalKeybindPreferences(
                function: flags.contains(.function), control: flags.contains(.control),
                command: flags.contains(.command), shift: flags.contains(.shift),
                option: flags.contains(.option), capsLock: flags.contains(.capsLock),
                carbonFlags: flags.carbonFlags, characters: event.charactersIgnoringModifiers,
                keyCode: UInt32(event.keyCode))
            shortcut = key
            Preferences.globalKey = key
            (NSApp.delegate as? AppDelegate)?.setupHotKey()
            stopRecording()
            return nil
        }
    }

    @MainActor private func checkUpdates() async {
        struct Release: Decodable { let tag_name: String }
        checking = true
        newer = false
        status = "正在检查…"
        defer { checking = false }
        do {
            let url = URL(string: "https://api.github.com/repos/zhengzhi-me/foldbar/releases/latest")!
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 12))
            if (response as? HTTPURLResponse)?.statusCode == 404 { status = "暂未发布更新"; return }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { status = "暂时无法检查更新"; return }
            let tag = try JSONDecoder().decode(Release.self, from: data).tag_name
            let value = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard value.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil else {
                status = "暂未发布正式版本"; return
            }
            newer = value.compare(version, options: .numeric) == .orderedDescending
            status = newer ? "发现新版 \(tag)" : "已是最新版本"
        } catch { status = "暂时无法检查更新" }
    }
}
