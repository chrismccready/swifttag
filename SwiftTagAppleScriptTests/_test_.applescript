on run
    set parentFolder to POSIX path of ((path to me as text) & "::")
    set testFLACPath_1 to parentFolder & "../SwiftTagTestFiles/test.flac"
    set testFLACPath_2 to parentFolder & "../SwiftTagTestFiles/test-with_padding.flac"
    set testDocumentPath to parentFolder & "../SwiftTagTestFiles/test.swifttag"

    -- Load test utils --
    set utils to getScript for "test-utils" at parentFolder without recompile
    log "Loading SwiftTag test utils from: " & parentFolder & "test-utils.scpt"

    -- Check if test FLAC files exist --
    utils's assertFileExists for testFLACPath_1
    utils's assertFileExists for testFLACPath_2

    -- Verbose logging? --
    set verboseLogging to false

    -- Run tracks test script --
    set testTracksScript to getScript for "test-tracks" at parentFolder without recompile
    log "Running Tracks test: " & parentFolder & "test-tracks.scpt"
    set result to testTracksScript's runTests given testUtils:utils, testFLACPath:testFLACPath_1, logging:verboseLogging
    log "Test Tracks: " & result

    -- Run tags test script --
    set testTagsScript to getScript for "test-tags" at parentFolder without recompile
    log "Running Tags test: " & parentFolder & "test-tags.scpt"
    set result to testTagsScript's runTests given testUtils:utils, testFLACPath_1:testFLACPath_1, testFLACPath_2:testFLACPath_2, logging:verboseLogging
    log "Test Tags: " & result

    -- Run pictures test script --
    set testPicturesScript to getScript for "test-pictures" at parentFolder without recompile
    log "Running Pictures test: " & parentFolder & "test-pictures.scpt"
    set result to testPicturesScript's runTests given testUtils:utils, testFLACPath:testFLACPath_1, logging:verboseLogging
    log "Test Pictures: " & result

    -- Run settings test script --
    set testSettingsScript to getScript for "test-settings" at parentFolder without recompile
    log "Running Settings test: " & parentFolder & "test-settings.scpt"
    set result to testSettingsScript's runTests given testUtils:utils, logging:verboseLogging
    log "Test Settings: " & result

    -- Run windows test script --
    set testWindowsScript to getScript for "test-windows" at parentFolder without recompile
    log "Running Windows test: " & parentFolder & "test-windows.scpt"
    set result to testWindowsScript's runTests given testUtils:utils, testFLACPath:testFLACPath_1, testDocumentPath:testDocumentPath, logging:verboseLogging
    log "Test Windows: " & result

    log "All tests completed."
end run

on getScript for baseName at parentPath given recompile:recompile
    try
        set scriptPath to (parentPath & baseName & ".scpt")
        if recompile or not (fileExists for scriptPath) then
            set scriptTextPath to (parentPath & baseName & ".applescript")
            do shell script "osacompile -o " & quoted form of scriptPath & " " & quoted form of scriptTextPath
            return load script (POSIX file scriptPath)
        else
            return load script (POSIX file scriptPath)
        end if
    on error errorMessage number errorNumber
        error "ERROR: Failed to load script. " & errorMessage & " (Error " & errorNumber & ")"
    end try
end getScript

on fileExists for posixPath
    try
        POSIX file posixPath as alias
        return true
    on error
        return false
    end try
end fileExists