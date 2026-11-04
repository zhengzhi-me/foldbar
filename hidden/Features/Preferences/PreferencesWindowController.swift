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
    @AppStorage("foldbarLanguage") private var language = "system"
    @AppStorage(UserDefaults.Key.isAutoStart) private var launchAtLogin = false
    @AppStorage(UserDefaults.Key.alwaysHideDockIcon) private var hideDock = false
    @AppStorage(UserDefaults.Key.isAutoHide) private var autoHide = true
    @AppStorage(UserDefaults.Key.numberOfSecondForAutoHide) private var seconds = 10.0
    @State private var shortcut = Preferences.globalKey
    @State private var monitor: Any?
    @State private var status = ""
    @State private var checking = false
    @State private var releaseURL: URL?
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    private let repo = URL(string: "https://github.com/zhengzhi-me/foldbar")!

    var body: some View {
        if #available(macOS 14.0, *) {
            settingsForm.focusEffectDisabled()
        } else {
            settingsForm
        }
    }

    private var settingsForm: some View {
        Form {
            Section("How to use".localized) {
                guideRow("command") { Text("Hold ⌘ and drag menu bar icons to arrange them.".localized) }
                guideRow("chevron.left") {
                    Text("Click".localized)
                    arrowBadge("chevron.left", label: "<")
                    Text("to reveal; click".localized)
                    arrowBadge("chevron.right", label: ">")
                    Text("to collapse.".localized)
                }
                guideRow("gearshape") {
                    Text("When collapsed, right-click".localized)
                    arrowBadge("chevron.left", label: "<")
                    Text("for Settings and Quit.".localized)
                }
                guideRow("eye.slash") {
                    Text("When expanded, right-click".localized)
                    arrowBadge("chevron.right", label: ">")
                    Text("to toggle the always-hidden section.".localized)
                }
            }
            Section("Preferences".localized) {
                Picker("Language".localized, selection: $language) {
                    Text("System default".localized).tag("system")
                    Text("简体中文").tag("zh-Hans")
                    Text("English").tag("en")
                }.pickerStyle(.menu)
                Toggle("Launch at login".localized, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { Util.setUpAutoStart(isAutoStart: $0) }
                Toggle("Always hide Dock icon".localized, isOn: $hideDock)
                    .onChange(of: hideDock) { if $0 { NSApp.setActivationPolicy(.accessory) } }
                LabeledContent {
                    Picker("Delay".localized, selection: $seconds) {
                        ForEach([5.0, 10, 15, 30, 60], id: \.self) { Text(String(format: "%d seconds".localized, Int($0))).tag($0) }
                    }.labelsHidden().disabled(!autoHide)
                } label: { Toggle("Auto collapse".localized, isOn: $autoHide) }
                LabeledContent("Global shortcut".localized) {
                    Button(monitor != nil ? "Press a shortcut…".localized : shortcut?.description ?? "Record shortcut".localized, action: recordShortcut)
                    if shortcut != nil {
                        Button("Clear".localized) {
                            stopRecording()
                            shortcut = nil
                            Preferences.globalKey = nil
                            (NSApp.delegate as? AppDelegate)?.setupHotKey()
                        }
                    }
                }
            }
            Section("Project information".localized) {
                LabeledContent("Current version".localized, value: version)
                Link(destination: repo) { Label("GitHub · zhengzhi-me/foldbar", systemImage: "chevron.left.forwardslash.chevron.right") }
                LabeledContent {
                    Button("Check for updates".localized) { Task { await checkUpdates() } }.disabled(checking)
                } label: { Text(status.isEmpty ? "Software updates".localized : status) }
                if let releaseURL { Link("View release".localized, destination: releaseURL) }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 510, minHeight: 445)
        .onChange(of: language) { _ in status = ""; releaseURL = nil; notifyPreferences() }
        .onChange(of: autoHide) { _ in notifyPreferences() }
        .onChange(of: seconds) { _ in notifyPreferences() }
        .onDisappear { stopRecording() }
    }

    private func guideRow<Content: View>(_ symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)
                .padding(.trailing, 6)
                .accessibilityHidden(true)
            content()
        }
    }

    private func arrowBadge(_ symbol: String, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 19, height: 19)
            .background(.secondary.opacity(0.13), in: RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel(Text(label))
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
        struct Release: Decodable { let tag_name: String; let draft: Bool }
        checking = true
        releaseURL = nil
        status = "Checking…".localized
        defer { checking = false }
        do {
            let url = URL(string: "https://api.github.com/repos/zhengzhi-me/foldbar/releases?per_page=30")!
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { status = "Could not check for updates".localized; return }
            let versions = try JSONDecoder().decode([Release].self, from: data)
                .filter { !$0.draft }
                .compactMap { release -> (tag: String, number: String)? in
                    let number = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
                    guard number.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil else { return nil }
                    return (release.tag_name, number)
                }
            guard let latest = versions.max(by: { $0.number.compare($1.number, options: .numeric) == .orderedAscending }) else {
                status = "No updates published yet".localized; return
            }
            if latest.number.compare(version, options: .numeric) == .orderedDescending {
                releaseURL = repo.appendingPathComponent("releases/tag/").appendingPathComponent(latest.tag)
                status = String(format: "Update available: %@".localized, latest.tag)
            } else {
                status = "Up to date".localized
            }
        } catch { status = "Could not check for updates".localized }
    }
}
