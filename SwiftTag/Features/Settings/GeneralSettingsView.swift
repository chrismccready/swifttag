import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(SaveSettingsKey.defaultSavePayload) private var defaultSavePayloadRawValue: String = SaveSettingsDefaults.defaultSavePayload.rawValue
    @AppStorage(SaveSettingsKey.defaultSaveScope) private var defaultSaveScopeRawValue: String = SaveSettingsDefaults.defaultSaveScope.rawValue
    @AppStorage(SaveSettingsKey.saveReferencedSwiftTagDocument) private var saveReferencedSwiftTagDocument: Bool = SaveSettingsDefaults.saveReferencedSwiftTagDocument
    @AppStorage(SaveSettingsKey.askToSaveNewSwiftTagDocument) private var askToSaveNewSwiftTagDocument: Bool = SaveSettingsDefaults.askToSaveNewSwiftTagDocument
    @State private var sandboxPathRecords: [SandboxPathBookmarkRecord] = SandboxPathSettingsStore.records()
    @State private var selectedSandboxPathIDs: Set<SandboxPathBookmarkRecord.ID> = []
    @State private var sandboxPathSortMode: SandboxPathSortMode = SandboxPathSettingsStore.sortMode()

    private let plusMinusButtonSize = CGSize(width: 20, height: 20)
    
    private var defaultSavePayload: Binding<SavePayloadOption> {
        Binding(
            get: { SavePayloadOption(rawValue: defaultSavePayloadRawValue) ?? SaveSettingsDefaults.defaultSavePayload },
            set: { defaultSavePayloadRawValue = $0.rawValue }
        )
    }
    
    private var defaultSaveScope: Binding<SaveScopeOption> {
        Binding(
            get: { SaveScopeOption(rawValue: defaultSaveScopeRawValue) ?? SaveSettingsDefaults.defaultSaveScope },
            set: { defaultSaveScopeRawValue = $0.rawValue }
        )
    }

    private var sortedSandboxPathRecords: [SandboxPathBookmarkRecord] {
        SandboxPathSettingsStore.sortedRecords(sandboxPathRecords, by: sandboxPathSortMode)
    }
    
    var body: some View {
        Form {
            GroupBox("FLAC File Save (⌘S)") {
                HStack {
                    Text("Write:")
                        .padding(.leading, 2)
                    Picker("", selection: defaultSavePayload) {
                        ForEach(SavePayloadOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .padding(.trailing, 2)
                    .accessibilityIdentifier("settings.general.defaultSavePayload")
                }
                .padding(.top, 4)
                HStack {
                    Text("To:")
                        .padding(.leading, 14)
                    Picker("", selection: defaultSaveScope) {
                        ForEach(SaveScopeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .accessibilityIdentifier("settings.general.defaultSaveScope")
                }
                .padding(.top, 1)
                .padding(.bottom, 4)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.regular)

            Section {
                GroupBox("SwiftTag Document Save (⌘S)") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Save referenced document", isOn: $saveReferencedSwiftTagDocument)
                            .padding(.horizontal, 2)
                            .accessibilityIdentifier("settings.general.saveReferencedSwiftTagDocument")
                            .accessibilityValue(saveReferencedSwiftTagDocument ? "On" : "Off")
                        
                        Toggle("Ask to save new document", isOn: $askToSaveNewSwiftTagDocument)
                            .padding(.horizontal, 2)
                            .accessibilityIdentifier("settings.general.askToSaveNewSwiftTagDocument")
                            .accessibilityValue(askToSaveNewSwiftTagDocument ? "On" : "Off")
                    }
                    .padding(.vertical, 4)
                }
                .controlSize(.mini)
            }

            Section {
                GroupBox("SwiftTag Sandbox Paths") {
                    VStack(alignment: .leading, spacing: 4) {
                        SandboxPathListView(
                            records: sortedSandboxPathRecords,
                            selectedRecordIDs: $selectedSandboxPathIDs
                        )
                        .frame(height: 154)
                        .contextMenu {
                            Button("Sort by Name") {
                                setSandboxPathSortMode(.name)
                            }
                            Button("Sort by Date Added") {
                                setSandboxPathSortMode(.dateAdded)
                            }
                            Divider()
                            Button("Add Path…") {
                                addSandboxPaths()
                            }
                            Button(selectedSandboxPathIDs.count > 1 ? "Remove Paths" : "Remove Path") {
                                removeSelectedSandboxPaths()
                            }
                            .disabled(selectedSandboxPathIDs.isEmpty)
                        }
                        .accessibilityIdentifier("settings.general.sandboxPaths.table")

                        HStack(spacing: 2) {
                            Button {
                                addSandboxPaths()
                            } label: {
                                Image(systemName: "plus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(
                                width: plusMinusButtonSize.width,
                                height: plusMinusButtonSize.height,
                                alignment: .bottom
                            )
                            .buttonStyle(.bordered)
                            .help("Add Sandbox Path")
                            .accessibilityIdentifier("settings.general.sandboxPaths.addButton")

                            Button {
                                removeSelectedSandboxPaths()
                            } label: {
                                Image(systemName: "minus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(
                                width: plusMinusButtonSize.width,
                                height: plusMinusButtonSize.height,
                                alignment: .bottom
                            )
                            .buttonStyle(.bordered)
                            .help("Remove Selected Sandbox Paths")
                            .disabled(selectedSandboxPathIDs.isEmpty)
                            .accessibilityIdentifier("settings.general.sandboxPaths.deleteButton")
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 2)
                }
                .help("Add/remove specific folders that SwiftTag has read/write access to.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            reloadSandboxPathSettings()
        }
    }

    private func reloadSandboxPathSettings() {
        sandboxPathRecords = SandboxPathSettingsStore.records()
        sandboxPathSortMode = SandboxPathSettingsStore.sortMode()
        pruneSandboxPathSelection()
    }

    private func addSandboxPaths() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.prompt = "Add"

        guard panel.runModal() == .OK else {
            return
        }

        addSandboxPathURLs(panel.urls)
    }

    private func addSandboxPathURLs(_ folderURLs: [URL]) {
        do {
            let updatedRecords = try SandboxPathSettingsStore.records(
                afterAddingFolderURLs: folderURLs,
                to: sandboxPathRecords
            ) { folderURL in
                let didAccess = folderURL.startAccessingSecurityScopedResource()
                guard didAccess else {
                    throw SandboxPathSettingsError.failedToAccessFolder(path: folderURL.path)
                }
                defer {
                    folderURL.stopAccessingSecurityScopedResource()
                }

                try SandboxPathSettingsStore.validateFolderURL(folderURL)
                return try folderURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }

            guard updatedRecords != sandboxPathRecords else {
                return
            }

            sandboxPathRecords = updatedRecords
            SandboxPathSettingsStore.saveRecords(updatedRecords)
        } catch {
            NSApp.presentError(error)
        }
    }

    private func removeSelectedSandboxPaths() {
        guard !selectedSandboxPathIDs.isEmpty else {
            return
        }

        sandboxPathRecords = SandboxPathSettingsStore.records(
            afterRemovingIDs: selectedSandboxPathIDs,
            from: sandboxPathRecords
        )
        pruneSandboxPathSelection()
        SandboxPathSettingsStore.saveRecords(sandboxPathRecords)
    }

    private func setSandboxPathSortMode(_ mode: SandboxPathSortMode) {
        sandboxPathSortMode = mode
        SandboxPathSettingsStore.saveSortMode(mode)
    }

    private func pruneSandboxPathSelection() {
        let recordIDs = Set(sandboxPathRecords.map(\.id))
        selectedSandboxPathIDs = selectedSandboxPathIDs.intersection(recordIDs)
    }
}

private struct SandboxPathListView: View {
    let records: [SandboxPathBookmarkRecord]
    @Binding var selectedRecordIDs: Set<SandboxPathBookmarkRecord.ID>

    @State private var activeEventModifiers: EventModifiers = []
    @State private var selectionAnchorID: SandboxPathBookmarkRecord.ID?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(records) { record in
                    SandboxPathRowView(
                        path: record.path,
                        isSelected: selectedRecordIDs.contains(record.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        select(record)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.vertical, 0)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onModifierKeysChanged(mask: [.command, .shift], initial: true) { _, newModifiers in
            activeEventModifiers = newModifiers
        }
        .onChange(of: records.map(\.id)) { _, recordIDs in
            selectedRecordIDs = selectedRecordIDs.intersection(recordIDs)
            if let selectionAnchorID, !recordIDs.contains(selectionAnchorID) {
                self.selectionAnchorID = selectedRecordIDs.first
            }
        }
    }

    private func select(_ record: SandboxPathBookmarkRecord) {
        guard let recordIndex = records.firstIndex(where: { $0.id == record.id }) else {
            return
        }

        if activeEventModifiers.contains(.shift),
           let anchorIndex = anchorIndex() {
            let selectedRange = min(anchorIndex, recordIndex)...max(anchorIndex, recordIndex)
            let rangeIDs = Set(selectedRange.map { records[$0].id })
            if activeEventModifiers.contains(.command) {
                selectedRecordIDs.formUnion(rangeIDs)
            } else {
                selectedRecordIDs = rangeIDs
            }
            return
        }

        selectionAnchorID = record.id
        if activeEventModifiers.contains(.command) {
            if selectedRecordIDs.contains(record.id) {
                selectedRecordIDs.remove(record.id)
            } else {
                selectedRecordIDs.insert(record.id)
            }
        } else {
            selectedRecordIDs = [record.id]
        }
    }

    private func anchorIndex() -> Array<SandboxPathBookmarkRecord>.Index? {
        guard let selectionAnchorID else {
            return nil
        }
        return records.firstIndex { $0.id == selectionAnchorID }
    }
}

private struct SandboxPathRowView: View {
    let path: String
    let isSelected: Bool

    var body: some View {
        Text(path)
            .font(.system(size: 12))
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
            .padding(.horizontal, 3)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor)
                }
            }
            .padding(.horizontal, 2)
    }
}
