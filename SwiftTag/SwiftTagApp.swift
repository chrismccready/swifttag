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
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Show TOML...") {
                TOMLPresentationState.shared.isPresented = true
            }
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
