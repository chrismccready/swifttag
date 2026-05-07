//
//  SwiftTagUITestSuites.swift
//  SwiftTagUITests
//
//  Created by Codex on 3/18/26.
//

import XCTest

final class SwiftTagCoreUITests: SwiftTagUITestCase {
    @MainActor
    func testExample() throws {
        try scenarioExample()
    }

    @MainActor
    func testLaunchPerformance() throws {
        try scenarioLaunchPerformance()
    }

    @MainActor
    func testFileMenuContainsReadOnlyLoadCommand() throws {
        try scenarioFileMenuContainsReadOnlyLoadCommand()
    }

    @MainActor
    func testFileMenuContainsSwiftTagDocumentCommandAndStartsDisabled() throws {
        try scenarioFileMenuContainsSwiftTagDocumentCommandAndStartsDisabled()
    }

    @MainActor
    func testFileMenuContainsOpenSwiftTagDocumentCommand() throws {
        try scenarioFileMenuContainsOpenSwiftTagDocumentCommand()
    }

    @MainActor
    func testDefaultWindowShowsSwiftTagTitleAndNoDocumentURL() throws {
        try scenarioDefaultWindowShowsSwiftTagTitleAndNoDocumentURL()
    }

    @MainActor
    func testNewWindowShowsSwiftTagTitleAndNoDocumentURL() throws {
        try scenarioNewWindowShowsSwiftTagTitleAndNoDocumentURL()
    }

    @MainActor
    func testImportedFlacWithAlbumShowsAlbumTitleAndNoDocumentURL() throws {
        try scenarioImportedFlacWithAlbumShowsAlbumTitleAndNoDocumentURL()
    }

    @MainActor
    func testImportedFlacWithoutAlbumShowsUntitledAndNoDocumentURL() throws {
        try scenarioImportedFlacWithoutAlbumShowsUntitledAndNoDocumentURL()
    }

    @MainActor
    func testTrackTitleEditingKeepsFocusAfterFirstTextChange() throws {
        try scenarioTrackTitleEditingKeepsFocusAfterFirstTextChange()
    }

    @MainActor
    func testMiscTagValueUsesPlaceholderWhenNoTrackIsSelected() throws {
        try scenarioMiscTagValueUsesPlaceholderWhenNoTrackIsSelected()
    }

    @MainActor
    func testMiscTagReloadSelectedTrackRestoresEditedAndDeletedRows() throws {
        try scenarioMiscTagReloadSelectedTrackRestoresEditedAndDeletedRows()
    }

    @MainActor
    func testMixedAlbumSelectionUpdatesWindowTitleBetweenAlbumAndUntitled() throws {
        try scenarioMixedAlbumSelectionUpdatesWindowTitleBetweenAlbumAndUntitled()
    }

    @MainActor
    func testFileMenuEnablesSwiftTagDocumentCommandWhenTracksAreLoaded() throws {
        try scenarioFileMenuEnablesSwiftTagDocumentCommandWhenTracksAreLoaded()
    }

    @MainActor
    func testLaunchDocumentOpenImportsFlacFixture() throws {
        try scenarioLaunchDocumentOpenImportsFlacFixture()
    }
}

final class SwiftTagAppleScriptUITests: SwiftTagUITestCase {
    @MainActor
    func testAppleScriptHarnessSelectsMatchingTracksInTableOrder() throws {
        try scenarioAppleScriptHarnessSelectsMatchingTracksInTableOrder()
    }

    @MainActor
    func testAppleScriptHarnessFindsTracksWhoseFileMatchesFileValue() throws {
        try scenarioAppleScriptHarnessFindsTracksWhoseFileMatchesFileValue()
    }

    @MainActor
    func testAppleScriptHarnessSetsTitleOfFirstTrack() throws {
        try scenarioAppleScriptHarnessSetsTitleOfFirstTrack()
    }

    @MainActor
    func testAppleScriptHarnessReadsFirstTagWhoseKey() throws {
        try scenarioAppleScriptHarnessReadsFirstTagWhoseKey()
    }

    @MainActor
    func testAppleScriptHarnessReadsEmptyAlbumTagWhoseKeyAfterUIClear() throws {
        try scenarioAppleScriptHarnessReadsEmptyAlbumTagWhoseKeyAfterUIClear()
    }

    @MainActor
    func testAppleScriptHarnessMakesTagInTellTrackContext() throws {
        try scenarioAppleScriptHarnessMakesTagInTellTrackContext()
    }

    @MainActor
    func testAppleScriptHarnessDeletesTagAndAlbumProperty() throws {
        try scenarioAppleScriptHarnessDeletesTagAndAlbumProperty()
    }

    @MainActor
    func testAppleScriptHarnessDeletesTracks() throws {
        try scenarioAppleScriptHarnessDeletesTracks()
    }

    @MainActor
    func testAppleScriptHarnessSavesWithScopeAndPayloadEnumerations() throws {
        try scenarioAppleScriptHarnessSavesWithScopeAndPayloadEnumerations()
    }

    @MainActor
    func testAppleScriptHarnessAddsLockedTrackWithOptionalParameter() throws {
        try scenarioAppleScriptHarnessAddsLockedTrackWithOptionalParameter()
    }

    @MainActor
    func testAppleScriptHarnessReadsAndWritesTrackLockedProperty() throws {
        try scenarioAppleScriptHarnessReadsAndWritesTrackLockedProperty()
    }

    @MainActor
    func testAppleScriptHarnessReadsTrackPicturesByType() throws {
        try scenarioAppleScriptHarnessReadsTrackPicturesByType()
    }

    @MainActor
    func testAppleScriptHarnessFiltersTrackPicturesByIdentity() throws {
        try scenarioAppleScriptHarnessFiltersTrackPicturesByIdentity()
    }

    @MainActor
    func testAppleScriptHarnessImportsTrackPictureFromExistingData() throws {
        try scenarioAppleScriptHarnessImportsTrackPictureFromExistingData()
    }

    @MainActor
    func testAppleScriptHarnessDeletesTrackPictures() throws {
        try scenarioAppleScriptHarnessDeletesTrackPictures()
    }

    @MainActor
    func testAppleScriptHarnessImportsTrackPictureFromFoundationBase64Data() throws {
        try scenarioAppleScriptHarnessImportsTrackPictureFromFoundationBase64Data()
    }

    @MainActor
    func testAppleScriptHarnessClosesEditorWindowSavingNo() throws {
        try scenarioAppleScriptHarnessClosesEditorWindowSavingNo()
    }

    @MainActor
    func testAppleScriptHarnessEnumeratesApplicationWindows() throws {
        try scenarioAppleScriptHarnessEnumeratesApplicationWindows()
    }

    @MainActor
    func testAppleScriptHarnessOpensSingletonSettingsWindow() throws {
        try scenarioAppleScriptHarnessOpensSingletonSettingsWindow()
    }

    @MainActor
    func testAppleScriptHarnessReadsEditorWindowWindowProperties() throws {
        try scenarioAppleScriptHarnessReadsEditorWindowWindowProperties()
    }

    @MainActor
    func testAppleScriptHarnessReadsAndWritesApplicationSettings() throws {
        try scenarioAppleScriptHarnessReadsAndWritesApplicationSettings()
    }
}

final class SwiftTagDocumentUITests: SwiftTagUITestCase {
    @MainActor
    func testFinderLaunchOpenShowsVisibleImportedFlacWindow() throws {
        try scenarioFinderLaunchOpenShowsVisibleImportedFlacWindow()
    }

    @MainActor
    func testReopeningClosedSwiftTagDocumentReloadsDocumentContents() throws {
        try scenarioReopeningClosedSwiftTagDocumentReloadsDocumentContents()
    }

    @MainActor
    func testOpeningSwiftTagDocumentShowsDocumentTitleAndDocumentURL() throws {
        try scenarioOpeningSwiftTagDocumentShowsDocumentTitleAndDocumentURL()
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsZeroDifferenceSubtitleWhenLiveFileMatches() throws {
        try scenarioReopeningSavedSwiftTagDocumentShowsZeroDifferenceSubtitleWhenLiveFileMatches()
    }

    @MainActor
    func testSavingSwiftTagDocumentUpdatesTrackFilenameAfterReferencedFlacRename() throws {
        try scenarioSavingSwiftTagDocumentUpdatesTrackFilenameAfterReferencedFlacRename()
    }

    @MainActor
    func testAddingExternalFlacFileUpdatesTrackFilenameAfterRename() throws {
        try scenarioAddingExternalFlacFileUpdatesTrackFilenameAfterRename()
    }

    @MainActor
    func testAddingExternalFlacFileKeepsRenamedFilenameWhenDeleted() throws {
        try scenarioAddingExternalFlacFileKeepsRenamedFilenameWhenDeleted()
    }

    @MainActor
    func testSavingSwiftTagDocumentKeepsRenamedFilenameWhenReferencedFlacIsDeleted() throws {
        try scenarioSavingSwiftTagDocumentKeepsRenamedFilenameWhenReferencedFlacIsDeleted()
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsRenamedReferencedFilenameAndZeroDifferenceSubtitle() throws {
        try scenarioReopeningSavedSwiftTagDocumentShowsRenamedReferencedFilenameAndZeroDifferenceSubtitle()
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsExternalTagDifferenceCounts() throws {
        try scenarioReopeningSavedSwiftTagDocumentShowsExternalTagDifferenceCounts()
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentIgnoresEquivalentMultiPictureOrderingAfterExternalTagSave() throws {
        try scenarioReopeningSavedSwiftTagDocumentIgnoresEquivalentMultiPictureOrderingAfterExternalTagSave()
    }

    @MainActor
    func testSavingSwiftTagDocumentKeepsTracksLoadedAndShowsDocumentTitleAndURL() throws {
        try scenarioSavingSwiftTagDocumentKeepsTracksLoadedAndShowsDocumentTitleAndURL()
    }
}

final class SwiftTagSaveFlowUITests: SwiftTagUITestCase {
    @MainActor
    func testFileMenuSaveAutoSavesReferencedSwiftTagDocumentWhenSettingEnabled() throws {
        try scenarioFileMenuSaveAutoSavesReferencedSwiftTagDocumentWhenSettingEnabled()
    }

    @MainActor
    func testControlSSavesReferencedSwiftTagDocumentWithoutSavingFlacFiles() throws {
        try scenarioControlSSavesReferencedSwiftTagDocumentWithoutSavingFlacFiles()
    }

    @MainActor
    func testControlSSavesMovedReferencedSwiftTagDocumentAfterExternalMove() throws {
        try scenarioControlSSavesMovedReferencedSwiftTagDocumentAfterExternalMove()
    }

    @MainActor
    func testFileMenuSavePromptsToCreateSwiftTagDocumentWhenSettingsEnabled() throws {
        try scenarioFileMenuSavePromptsToCreateSwiftTagDocumentWhenSettingsEnabled()
    }

    @MainActor
    func testFileMenuSaveDoNotSaveSuppressesPromptInSameWindow() throws {
        try scenarioFileMenuSaveDoNotSaveSuppressesPromptInSameWindow()
    }

    @MainActor
    func testFileMenuSavePromptsAgainAfterCancelingNewSwiftTagDocumentSavePanel() throws {
        try scenarioFileMenuSavePromptsAgainAfterCancelingNewSwiftTagDocumentSavePanel()
    }

    @MainActor
    func testCloseWindowWithUnsavedChangesShowsExpandedNewDocumentChoices() throws {
        try scenarioCloseWindowWithUnsavedChangesShowsExpandedNewDocumentChoices()
    }

    @MainActor
    func testCloseWindowSaveNewSwiftTagDocumentCancelKeepsWindowOpen() throws {
        try scenarioCloseWindowSaveNewSwiftTagDocumentCancelKeepsWindowOpen()
    }

    @MainActor
    func testFileMenuSaveShowsSwiftTagSaveErrorWhileKeepingFlacSaveResult() throws {
        try scenarioFileMenuSaveShowsSwiftTagSaveErrorWhileKeepingFlacSaveResult()
    }

    @MainActor
    func testSimulatedSaveReEnablesEditorAfterCompletion() throws {
        try scenarioSimulatedSaveReEnablesEditorAfterCompletion()
    }
}

final class SwiftTagEditingStateUITests: SwiftTagUITestCase {
    @MainActor
    func testAddFlacFilesPreservesDirtyTrackStatusIcon() throws {
        try scenarioAddFlacFilesPreservesDirtyTrackStatusIcon()
    }

    @MainActor
    func testCompilationCheckboxRetainsOnStateWhenSelectedTrackIsLocked() throws {
        try scenarioCompilationCheckboxRetainsOnStateWhenSelectedTrackIsLocked()
    }

    @MainActor
    func testNewWindowsCanBeSelectedAndEditedDeterministicallyWithOpenPanel() throws {
        try scenarioNewWindowsCanBeSelectedAndEditedDeterministicallyWithOpenPanel()
    }

    @MainActor
    func testRepeatedExternalSavesAcrossWindowsContinueUpdatingObservedAlbumDifference() throws {
        try scenarioRepeatedExternalSavesAcrossWindowsContinueUpdatingObservedAlbumDifference()
    }

    @MainActor
    func testConflictingSaveInSecondWindowUpdatesFirstWindowObservedAlbumDifference() throws {
        try scenarioConflictingSaveInSecondWindowUpdatesFirstWindowObservedAlbumDifference()
    }
}

final class SwiftTagAlbumArtUITests: SwiftTagUITestCase {
    @MainActor
    func testPictureDescriptionEditKeepsInternalTrackStatusIcon() throws {
        try scenarioPictureDescriptionEditKeepsInternalTrackStatusIcon()
    }

    @MainActor
    func testPictureDescriptionSaveInSecondWindowShowsExternalPictureDifferenceInFirstWindow() throws {
        try scenarioPictureDescriptionSaveInSecondWindowShowsExternalPictureDifferenceInFirstWindow()
    }

    @MainActor
    func testPictureBrowserShowsExternalOverlayOnlyForDifferingSlot() throws {
        try scenarioPictureBrowserShowsExternalOverlayOnlyForDifferingSlot()
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsExternalPictureDescriptionDifferenceInPictureBrowser() throws {
        try scenarioReopeningSavedSwiftTagDocumentShowsExternalPictureDescriptionDifferenceInPictureBrowser()
    }

    @MainActor
    func testReopeningSavedSwiftTagDocumentShowsExternalAddedPictureSlotInPictureBrowser() throws {
        try scenarioReopeningSavedSwiftTagDocumentShowsExternalAddedPictureSlotInPictureBrowser()
    }
}

final class SwiftTagSettingsUITests: SwiftTagUITestCase {
    @MainActor
    func testSettingsWindowPersistsSavePreferencesAcrossRelaunch() throws {
        try scenarioSettingsWindowPersistsSavePreferencesAcrossRelaunch()
    }

    @MainActor
    func testFileMenuSavePicturesDoesNotPersistTagOnlyEditsAcrossRelaunch() throws {
        try scenarioFileMenuSavePicturesDoesNotPersistTagOnlyEditsAcrossRelaunch()
    }

    @MainActor
    func testFileMenuSaveUsesPersistedDefaultPayloadAcrossRelaunch() throws {
        try scenarioFileMenuSaveUsesPersistedDefaultPayloadAcrossRelaunch()
    }
}
