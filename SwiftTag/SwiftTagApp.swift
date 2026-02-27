//
//  SwiftTagApp.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private struct TomlCommands: Commands {
    @FocusedValue(\.showTomlSheet) private var showTomlSheet

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Show TOML...") {
                showTomlSheet?()
            }
            .disabled(showTomlSheet == nil)
        }
    }
}

@main
struct SwiftTagApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            TomlCommands()
        }
    }
}
