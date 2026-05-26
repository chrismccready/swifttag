global utils

on run input
    set parentFolder to POSIX path of ((path to me as text) & "::")
    set testFLACPath to parentFolder & "../SwiftTagTestFiles/test.flac"
    set testUtilsPath to parentFolder & "test-utils.scpt"
    log "Loading SwiftTag test utils from: " & testUtilsPath
    set utils to load script (testUtilsPath as POSIX file)

     -- Run tests --
    runTests given testUtils:utils, testFLACPath:testFLACPath, logging:true
end run

on runTests given testUtils:testUtils, testFLACPath:testFLACPath, logging:logging
    set utils to testUtils
    set testFLACPath to testFLACPath

    -- Test adding a track (to front editor window) --
    testTrackAddAndDelete for testFLACPath given logging:logging, locking:false
    testTrackAddAndDelete for testFLACPath given logging:logging, locking:true
    utils's logLine about "PASSED: Add track test." given logging:logging

    -- Test locking and unlocking tracks --
    testTrackLockAndUnlock for testFLACPath given logging:logging
    utils's logLine about "PASSED: Lock and unlock track test." given logging:logging

    -- Test selecting tracks --
    testTrackSelectAndEdit for testFLACPath given logging:logging
    utils's logLine about "PASSED: Select and edit track test." given logging:logging

    return "PASS"
end runTests

on testTrackAddAndDelete for testFLACPath given logging:logging, locking:locking
    tell application "SwiftTag"
        -- Check if track already exists and delete it before test --
        set frontWindow to front editor window
        set existingTrack to utils's getTrack for testFLACPath at frontWindow
        if existingTrack is not missing value then
            utils's assertDeleteTrack for existingTrack at frontWindow
            utils's logLine about "Deleted existing track with file path: " & testFLACPath given logging:logging
        end if

        -- Add a track --
        try
            set addedTrack to add POSIX file testFLACPath with lock locking to front editor window
            utils's assertTrackExists for testFLACPath at frontWindow
        on error errorMessage number errorNumber
            if errorNumber is 8 then
                error "ERROR: Failed to add track. " & errorMessage & "(8) Permissions (sandbox) issue."
            else
                error "ERROR: Failed to add track. " & errorMessage
            end if
        end try

         -- Verify the track's locked state if locking was requested --
        if locking then
            if not (locked of addedTrack) then
                error "ERROR: Failed to add track with lock."
            end if
        end if
        
         -- Verify the track's file path and locked state --
        if logging then
            if (locked of addedTrack) then
                set lockedText to "locked"
            else
                set lockedText to "unlocked"
            end if
            log "Added Track (" & lockedText & "): " & (file of addedTrack)
            -- log "Count of tracks in front window after adding: " & (count tracks of frontWindow)
        end if

        -- Test delete (may not have been done above) and clean up by deleting added track --
        utils's assertDeleteTrack for addedTrack at frontWindow
        utils's logLine about "Deleted added track with file path: " & testFLACPath given logging:logging
    end tell
end testTrackAddAndDelete

on testTrackLockAndUnlock for testFLACPath given logging:logging
    tell application "SwiftTag"
        -- Add a track --
        set frontWindow to front editor window
        if utils's deleteTrack for testFLACPath at frontWindow then
            utils's logLine about "Deleted existing track with file path: " & testFLACPath given logging:logging
        end if
        set testTrack to utils's addTrack for testFLACPath at frontWindow without locking

        -- Test locking the track --
        set locked of testTrack to true
        if not (locked of testTrack) then
            error "ERROR: Failed to lock track."
        end if
        utils's logLine about "Locked Track: " & (file of testTrack) given logging:logging

        -- Now unlock the track and verify it's unlocked
        set locked of testTrack to false
        if locked of testTrack then
            error "ERROR: Failed to unlock track."
        end if
        utils's logLine about "Unlocked Track: " & (file of testTrack) given logging:logging
    end tell
end testTrackLockAndUnlock

on testTrackSelectAndEdit for testFLACPath given logging:logging
    tell application "SwiftTag"
        -- Get/Add a track --
        set frontWindow to front editor window
        set testTrack to utils's getTrack for testFLACPath at frontWindow
        if testTrack is missing value then
            set testTrack to utils's addTrack for testFLACPath at frontWindow without locking
            utils's logLine about "Added Track: " & testFLACPath given logging:logging
        end if

        -- Select the track and verify it's selected --
        set selected tracks of frontWindow to testTrack
        if (count selected tracks of frontWindow) is not 1 then
            error "ERROR: Expected 1 selected track, but got " & (count selected tracks of frontWindow)
        end if
        set selectedTracks to selected tracks of frontWindow
        set selectedTrackFile to file of item 1 of selectedTracks
        if (selectedTrackFile as alias) is not ((utils's hfsFilePath for testFLACPath) as alias) then
            error "ERROR: Expected selected track file to be " & (utils's hfsFilePath for testFLACPath) & ", but got " & selectedTrackFile
        end if
        utils's logLine about "Selected Track: " & testFLACPath given logging:logging

        -- Save original title to restore later --
        set selectedTrack to item 1 of ((selected tracks of frontWindow) as List)
        set locked of selectedTrack to false
        set origTrackTitle to title of selectedTrack
        utils's logLine about "Selected track title: " & origTrackTitle given logging:logging

        -- Edit the unlocked track's title and verify the change --
        set title of selectedTrack to "New Title from AppleScript"
        set trackTitle to title of selectedTrack
        if trackTitle is not "New Title from AppleScript" then
            error "ERROR: Failed to change track title. Expected: 'New Title from AppleScript', but got: " & trackTitle
        end if
        if modified of frontWindow is false then
            error "ERROR: Expected front window to be marked as modified after changing track title, but it was not."
        end if
        if modified of selectedTrack is false then
            error "ERROR: Expected track to be marked as modified after changing title, but it was not."
        end if
        utils's logLine about "Selected track title after change: " & trackTitle given logging:logging

        -- Now lock the track and verify that it cannot be edited --
        set locked of selectedTrack to true
        utils's logLine about "Locked state of selected track: " & locked of selectedTrack given logging:logging
        utils's logLine about "Attempting to change title after locking..." given logging:logging
        try
            set title of selectedTrack to "Attempt Title Change While Locked"
            set trackTitle to title of selectedTrack
            utils's logLine about "Selected track title after attempted change while locked: " & trackTitle given logging:logging
            error "ERROR: Was able to change title while track was locked, which should not be possible." number 999
        on error errorMessage number errorNumber
            if errorNumber is not 4 then
                error "ERROR: Unexpected error when trying to change title while track is locked: " & errorMessage & " (Error number: " & errorNumber & ")" given logging:logging
            end if
            utils's logLine about "Expected error when trying to change title while track is locked: " & errorMessage & " (Error number: " & errorNumber & ")" given logging:logging
        end try

        -- Unlock the track again to restore original title --
        set locked of selectedTrack to false
        utils's logLine about "Locked state of selected track after unlocking: " & locked of selectedTrack given logging:logging
        utils's logLine about "Attempting to change/restore title after unlocking..." given logging:logging
        set title of selectedTrack to origTrackTitle
        set trackTitle to title of selectedTrack
        if trackTitle is not origTrackTitle then
            error "ERROR: Failed to restore original track title after unlocking. Expected: " & origTrackTitle & ", but got: " & trackTitle
        end if
        if modified of frontWindow is true then
            error "ERROR: Expected front window to not be marked as modified after restoring track title, but it was."
        end if
        if modified of selectedTrack is true then
            error "ERROR: Expected track to not be marked as modified after restoring title, but it was."
        end if
        utils's logLine about "Restored original track title: " & origTrackTitle given logging:logging
    end tell
end testTrackSelectAndEdit
