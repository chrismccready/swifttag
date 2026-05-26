global utils

using terms from application "SwiftTag"
    property defaultMonitor2Position : {x: 2745, y: 768}
    property defaultMonitor2Bounds : {x: 2745, y: 768, width: 900, height: 610}
    property biggerMonitor2Position : {x: 2692, y: 1056}
    property biggerMonitor2Bounds : {x: 2692, y: 1056, width: 1174, height: 1364}
    property settingsWindowPosition : {x: (x of defaultMonitor2Position + (width of defaultMonitor2Bounds)), y: 768}
    property resetToDefaults : true
end using terms from

on run
    set parentFolder to POSIX path of ((path to me as text) & "::")
    set testUtilsPath to parentFolder & "test-utils.scpt"
    set testFLACPath to parentFolder & "../SwiftTagTestFiles/test.flac"
    set testDocumentPath to parentFolder & "../SwiftTagTestFiles/test.swifttag"
    log "Loading SwiftTag test utils from: " & testUtilsPath
    set utils to load script (testUtilsPath as POSIX file)

     -- Run tests --
    runTests given testUtils:utils, testFLACPath:testFLACPath, testDocumentPath:testDocumentPath, logging:true 
end run

on runTests given testUtils:testUtils, testFLACPath:testFLACPath, testDocumentPath:testDocumentPath, logging:logging
    -- Run window tests --
    testReadEditorAndSettingsWindow given logging:logging
    utils's logLine about "PASSED: Read Editor and Settings Window test." given logging:logging

    testEditorWindowPositionAndBounds at {defaultMonitor2Position, biggerMonitor2Position, defaultMonitor2Bounds, biggerMonitor2Bounds} given resetToDefaults:true, logging:logging
    utils's logLine about "PASSED: Editor Window Position and Bounds test." given logging:logging

    testSettingsWindowPosition at settingsWindowPosition given resetToFirstPosition:true, withClose:true, logging:logging
    utils's logLine about "PASSED: Settings Window Position test." given logging:logging

    toggleCollapseFrontEditorWindow given logging:logging
    toggleCollapseFrontEditorWindow given logging:logging
    utils's logLine about "PASSED: Toggle Collapse Front Editor Window test." given logging:logging

    toggleZoomFrontEditorWindow given logging:logging
    toggleZoomFrontEditorWindow given logging:logging
    utils's logLine about "PASSED: Toggle Zoom Front Editor Window test." given logging:logging

    toggleFullScreenFrontEditorWindow given logging:logging
    activate me
    toggleFullScreenFrontEditorWindow given logging:logging
    utils's logLine about "PASSED: Toggle Full Screen Front Editor Window test." given logging:logging

    testWindowCounts given logging:logging
    utils's logLine about "PASSED: Window Counts test." given logging:logging

    -- Run file and document tests --
    testOpenFLACFile for testFLACPath given logging:logging
    utils's logLine about "PASSED: Open FLAC File test." given logging:logging

    testSaveDocument for testDocumentPath given logging:logging
    utils's logLine about "PASSED: Save Document test." given logging:logging
    
    testOpenDocument for testDocumentPath given logging:logging
    utils's logLine about "PASSED: Open Document test." given logging:logging

    return "PASS"
end runTests

on testReadEditorAndSettingsWindow given logging:logging
    tell application "SwiftTag"
        -- activate
        if count of editor windows is 0 then
            try
                make new editor window
            on error errorMessage number errorNumber
                error "ERROR: Failed to create new editor window. " & errorMessage & " (" & errorNumber & ")"
            end try
        end if
        utils's logLine about "Type of front window: " & (class of front editor window as text) given logging:logging

        -- Base window class properties --
        -- `collapsable`, `collapsed`, `full screen`, `position`, and `bounds` properties are not currently 
        -- available in base window class.
        repeat with thisWindow in windows
            utils's logLine about "window `index`: " & index of thisWindow given logging:logging
            utils's logLine about "window `id`: " & id of thisWindow given logging:logging
            utils's logLine about "window `name`: " & name of thisWindow given logging:logging
            utils's logLine about "window `class`: " & class of thisWindow given logging:logging
            utils's logLine about "window `closeable`: " & closeable of thisWindow given logging:logging
            utils's logLine about "window `resizable`: " & resizable of thisWindow given logging:logging
            utils's logLine about "window `visible`: " & visible of thisWindow given logging:logging
            utils's logLine about "window `zoomable`: " & zoomable of thisWindow given logging:logging
            utils's logLine about "window `zoomed`: " & zoomed of thisWindow given logging:logging
        end repeat

        --  Editor window properties --
        tell front editor window
            utils's logLine about "Editor window `index`: " & index given logging:logging
            utils's logLine about "Editor window `id`: " & id given logging:logging
            utils's logLine about "Editor window `window id`: " & window id given logging:logging
            utils's logLine about "Editor winsow `name`: " & name given logging:logging
            utils's logLine about "Editor window `closeable`: " & closeable given logging:logging
            utils's logLine about "Editor window `collapseable`: " & collapseable given logging:logging
            utils's logLine about "Editor window `collapsed`: " & collapsed given logging:logging
            utils's logLine about "Editor window `full screen`: " & full screen given logging:logging
            utils's logLine about "Editor window `resizable`: " & resizable given logging:logging
            utils's logLine about "Editor window `visible`: " & visible given logging:logging
            utils's logLine about "Editor window `zoomable`: " & zoomable given logging:logging
            utils's logLine about "Editor window `zoomed`: " & zoomed given logging:logging
            set windowPosition to position
            utils's logLine about "Editor window `position`: " & x of windowPosition & ", " & y of windowPosition given logging:logging
            set windowBounds to bounds
            utils's logLine about "Editor window `bounds`: " & x of windowBounds & ", " & y of windowBounds & ", " & width of windowBounds & ", " & height of windowBounds given logging:logging
        end tell

        -- Settings window properties --
        open settings window
        tell front settings window
            utils's logLine about "Settings winsow `name`: " & name given logging:logging
            utils's logLine about "Settings window `id`: " & id given logging:logging
            utils's logLine about "Settings window `index`: " & index given logging:logging
            utils's logLine about "Settings window `closeable`: " & closeable given logging:logging
            utils's logLine about "Settings window `collapseable`: " & collapseable given logging:logging
            utils's logLine about "Settings window `collapsed`: " & collapsed given logging:logging
            utils's logLine about "Settings window `full screen`: " & full screen given logging:logging
            utils's logLine about "Settings window `resizable`: " & resizable given logging:logging
            utils's logLine about "Settings window `visible`: " & visible given logging:logging
            utils's logLine about "Settings window `zoomable`: " & zoomable given logging:logging
            utils's logLine about "Settings window `zoomed`: " & zoomed given logging:logging
            set settingsWindowPosition to position
            utils's logLine about "Settings window `position`: " & x of settingsWindowPosition & ", " & y of settingsWindowPosition given logging:logging
            set settingsWindowBounds to bounds
            utils's logLine about "Settings window `bounds`: " & x of settingsWindowBounds & ", " & y of settingsWindowBounds & ", " & width of settingsWindowBounds & ", " & height of settingsWindowBounds given logging:logging
            close
        end tell
    end tell
end testReadEditorAndSettingsWindow

on testEditorWindowPositionAndBounds at {defaultPosition, biggerPosition, defaultBounds, biggerBounds} given resetToDefaults:resetToDefaults, logging:logging
    tell application "SwiftTag"
        if resizable of front editor window is false then
            error "ERROR: front editor window is not resizable"
        end if

        tell front editor window
            set currentPosition to position
            utils's logLine about "Current front editor window position: " & x of currentPosition & ", " & y of currentPosition given logging:logging
            set currentBounds to bounds
            utils's logLine about "Current front editor window bounds: " & x of currentBounds & ", " & y of currentBounds & ", " & width of currentBounds & ", " & height of currentBounds given logging:logging
        
            -- Set editor window location to bigger --
            set position to biggerPosition
            if position is not biggerPosition then
                error "ERROR: Failed to set front editor window position to biggerPosition!"
            end if
            set newPosition to position
            utils's logLine about "Set front editor window position to biggerPosition: " & (x of newPosition) & ", " & (y of newPosition) given logging:logging

            set bounds to biggerBounds
             if bounds is not biggerBounds then
                error "ERROR: Failed to set front editor window bounds to biggerBounds!"
            end if
            set newBounds to bounds
            utils's logLine about "Set front editor window bounds to biggerBounds: " & x of newBounds & ", " & y of newBounds & ", " & width of newBounds & ", " & height of newBounds given logging:logging

            -- Set front editor window location to defaults? --
            if resetToDefaults then
                set position to defaultPosition
                if position is not defaultPosition then
                    error "ERROR: Failed to set front editor window position to defaultPosition!"
                end if
                set newPosition to position
                utils's logLine about "Set front editor window position to defaultPosition: " & x of newPosition & ", " & y of newPosition given logging:logging
                
                set bounds to defaultBounds
                if bounds is not defaultBounds then
                    error "ERROR: Failed to set front editor window bounds to defaultBounds!"
                end if
                set newBounds to bounds
                utils's logLine about "Set front editor window bounds to defaultBounds: " & x of newBounds & ", " & y of newBounds & ", " & width of newBounds & ", " & height of newBounds given logging:logging
            end if
        end tell
    end tell
end testEditorWindowPositionAndBounds

on testSettingsWindowPosition at secondPosition given resetToFirstPosition:resetToFirstPosition, withClose:withClose, logging:logging
    tell application "SwiftTag"
        -- Open settings window --
        set settingsWindow to open settings window

        tell settingsWindow
            -- Get settings window location --
            copy position to origPosition
            utils's logLine about "Current settings window position: " & x of origPosition & ", " & y of origPosition given logging:logging
            set origBounds to bounds
            utils's logLine about "Current settings window bounds: " & x of origBounds & ", " & y of origBounds & ", " & width of origBounds & ", " & height of origBounds given logging:logging

            -- Set settings window location to secondPosition --
            set position to secondPosition
            if position is not secondPosition then
                error "ERROR: Failed to set settings window position to secondPosition!"
            end if
            set newPosition to position
            utils's logLine about "Set settings window position to secondPosition: " & (x of newPosition) & ", " & (y of newPosition) given logging:logging

            -- Set settings window location to defaults? --
            if resetToFirstPosition then
                 set position to origPosition
                if position is not origPosition then
                    error "ERROR: Failed to reset settings window position to original position!"
                end if
                set newPosition to position
                utils's logLine about "Reset settings window position to original position: " & x of newPosition & ", " & y of newPosition given logging:logging
            end if

            -- Close settings window? --
            if withClose then
                close
                utils's logLine about "Closed settings window." given logging:logging
            end if
        end tell
    end tell
end testSettingsWindowPosition

on toggleCollapseFrontEditorWindow given logging:logging
     tell application "SwiftTag"
        if collapseable of front editor window is false then
            error "ERROR: front editor window is not collapsible"
        end if

        set isCollapsed to collapsed of front editor window
        if isCollapsed then
            set collapsed of front editor window to false
            utils's logLine about "Collapsed front editor window: " & (collapsed of front editor window) given logging:logging
        else
            set collapsed of front editor window to true
            utils's logLine about "Collapsed front editor window: " & (collapsed of front editor window) given logging:logging
        end if
    end tell
end toggleCollapseFrontEditorWindow

on toggleZoomFrontEditorWindow given logging:logging
     tell application "SwiftTag"
        if zoomable of front editor window is false then
            error "ERROR: front editor window is not zoomable"
        end if
        set isZoomed to zoomed of front editor window
        if isZoomed then
            set zoomed of front editor window to false
            utils's logLine about "Set front editor window zoomed to false: " & (zoomed of front editor window) given logging:logging
        else
            set zoomed of front editor window to true
            utils's logLine about "Set front editor window zoomed to true: " & (zoomed of front editor window) given logging:logging
        end if
    end tell
end toggleZoomFrontEditorWindow

on toggleFullScreenFrontEditorWindow given logging:logging
    tell application "SwiftTag"
        set isFullScreen to full screen of front editor window
        if isFullScreen then
            set full screen of front editor window to false
            utils's logLine about "Set front editor window full screen to false: " & (full screen of front editor window) given logging:logging
        else
            set full screen of front editor window to true
            utils's logLine about "Set front editor window full screen to true: " & (full screen of front editor window) given logging:logging
        end if
    end tell
end toggleFullScreenFrontEditorWindow

on testWindowCounts given logging:logging
    tell application "SwiftTag"
        set windowCount to count of windows
        utils's logLine about "Current window count: " & windowCount given logging:logging
        make new editor window
        set newWindowCount to count of windows
        if newWindowCount is not (windowCount + 1) then
            error "ERROR: Failed to create new editor window! Window count did not increase by 1 after creating new editor window. Current window count: " & newWindowCount
        end if
        utils's logLine about "Created new editor window. New window count: " & newWindowCount given logging:logging
        close front editor window
        set finalWindowCount to count of windows
        if finalWindowCount is not windowCount then
            error "ERROR: Failed to close front editor window! Window count did not decrease by 1 after closing front editor window. Current window count: " & finalWindowCount
        end if
        utils's logLine about "Closed front editor window. Final window count: " & finalWindowCount given logging:logging
    end tell
end testWindowCounts

on testOpenFLACFile for filePath given logging:logging
    tell application "SwiftTag"
        open filePath
        try
            set firstTrack to (first track of front editor window whose its file is POSIX file filePath)
        on error errorMessage number errorNumber
            if errorNumber is -1719 then
                error "ERROR: Failed to open track for FLAC path: " & filePath & ". Check file/app sandbox permissions."
            else
                error "ERROR: Failed to open track for FLAC path: " & filePath & ". " & errorMessage & " (" & errorNumber & ")"
            end if
        end try
        utils's logLine about "Opened FLAC file at path: " & filePath given logging:logging
    end tell
end testOpenFLACFile

on testSaveDocument for filePath given logging:logging
    tell application "SwiftTag"
        save document 1 in filePath
        utils's logLine about "Saved document at path: " & filePath given logging:logging
    end tell
end testSaveDocument

on testOpenDocument for filePath given logging:logging
    tell application "SwiftTag"
        open filePath
        try
            set openedDocument to document of front editor window
        on error errorMessage number errorNumber
            error "ERROR: Failed to open document for path: " & filePath & ". Check file/app sandbox permissions. " & errorMessage & " (" & errorNumber & ")"
        end try
        set documentName to name of openedDocument
        if documentName is missing value or documentName is "Untitled" then
            error "ERROR: Failed to open document for path: " & filePath & ". Check file/app sandbox permissions."
        end if 
        utils's logLine about "Opened document from path: " & filePath given logging:logging
    end tell
end testOpenDocument