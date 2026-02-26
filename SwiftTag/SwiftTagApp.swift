//
//  SwiftTagApp.swift
//  SwiftTag
//
//  Created by Christopher McCready on 2/24/26.
//

import SwiftUI
import AppKit

private enum WindowID {
    static let tomlUtility = "toml-utility"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private struct TomlCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Show TOML...") {
                openWindow(id: WindowID.tomlUtility)
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

        UtilityWindow("TOML", id: WindowID.tomlUtility) {
            TOMLUtilityView()
        }
    }
}
