global utils

using terms from application "SwiftTag"
    property defaultTrackToTrackDiffColor : {red: 1.0, green: 0.573, blue: 0.188, alpha: 1.0} -- system orange
    property defaultTrackToFileDiffColor : {red: 0.137, green: 0.999, blue: 0.268, alpha: 0.85} -- bright green
    property defaultExternallyModifiedDiffColor : {red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0} -- bright red
    property defaultTrackAndDiscTotalMismatchColor : {red: 1.0, green: 0.259, blue: 0.270, alpha: 1.0} -- system red
    property defaultPictureStatusOverlayColor : {red: 1.0, green: 0.573, blue: 0.188, alpha: 1.0} -- system orange
    property defaultPowderBlueColor : {red: 0.0, green: 0.718, blue: 1.0, alpha: 1.0} -- powder blue
end using terms from

on run
    set parentFolder to POSIX path of ((path to me as text) & "::")
    set testUtilsPath to parentFolder & "test-utils.scpt"
    log "Loading SwiftTag test utils from: " & testUtilsPath
    set utils to load script (testUtilsPath as POSIX file)

     -- Run tests --
    runTests given testUtils:utils, logging:true 
end run

on runTests given testUtils:testUtils, logging:logging
    set utils to testUtils

    -- General Settings --
    setGeneralSettingsTest given logging:logging
    utils's logLine about "PASSED: General settings test." given logging:logging

    -- Tag Settings --
    setTagSettingsTest given logging:logging
    utils's logLine about "PASSED: Tag settings test." given logging:logging

    -- Feedback Settings --
    setFeedbackSettingsTest given logging:logging
    utils's logLine about "PASSED: Feedback settings test." given logging:logging

    -- Diff Tools --
    setDiffToolsSettingsTest given logging:logging
    utils's logLine about "PASSED: Diff Tools settings test." given logging:logging

    -- Reset to defaults --
    setGeneralSettingsDefaults given logging:logging
    utils's logLine about "PASSED: Reset to defaults test." given logging:logging

    setTagSettingsDefaults given logging:logging
    utils's logLine about "PASSED: Tag settings reset to defaults." given logging:logging

    setFeedbackSettingsDefaults given logging:logging
    utils's logLine about "PASSED: Feedback settings reset to defaults." given logging:logging

    setDiffToolsSettingsDefaults given logging:logging
    utils's logLine about "PASSED: Diff Tools settings reset to defaults." given logging:logging

    return "PASS"
end runTests

on setGeneralSettingsTest given logging:logging
    tell application "SwiftTag"
        -- FLAC File Save Settings --
        set track save payload to tags only
        if track save payload is not tags only then
            error "ERROR: track save payload is NOT set to tags only"
        end if
        set track save scope to selected
        if track save scope is not selected then
            error "ERROR: track save scope is NOT set to selected"
        end if

        -- SwiftTag Document Save Settings --
        set save referenced document to true
        if save referenced document is not true then
            error "ERROR: save referenced document is NOT set to true"
        end if
        set ask to save new document to true
        if ask to save new document is not true then
            error "ERROR: ask to save new document is NOT set to true"
        end if
    end tell
end setGeneralSettingsTest

on setGeneralSettingsDefaults given logging:logging
    tell application "SwiftTag"
        set track save payload to tags and pictures
        if track save payload is not tags and pictures then
            error "ERROR: track save payload is NOT set to tags and pictures"
        end if
        set track save scope to all
        if track save scope is not all then
            error "ERROR: track save scope is NOT set to all"
        end if
        set save referenced document to false
        if save referenced document is not false then
            error "ERROR: save referenced document is NOT set to false"
        end if
        set ask to save new document to false
        if ask to save new document is not false then
            error "ERROR: ask to save new document is NOT set to false"
        end if
    end tell
end setGeneralSettingsDefaults

on setTagSettingsTest given logging:logging
    tell application "SwiftTag"
        -- Value preferences --
        set zero pad track numbers to false
        if zero pad track numbers is not false then
            error "ERROR: zero pad track numbers is NOT set to false"
        end if
        set zero pad disc numbers to false
        if zero pad disc numbers is not false then
            error "ERROR: zero pad disc numbers is NOT set to false"
        end if

        -- Key preferences --
        set track total key to TOTALTRACKS
        if track total key is not TOTALTRACKS then
            error "ERROR: track total key is NOT set to TOTALTRACKS"
        end if
        set disc total key to DISCTOTAL
        if disc total key is not DISCTOTAL then
            error "ERROR: disc total key is NOT set to DISCTOTAL"
        end if

        -- Track Total/Compilation Management --
        set auto update track total to true
        if auto update track total is not true then
            error "ERROR: auto update track total is NOT set to true"
        end if
        set apply compilation to all tracks to true
        if apply compilation to all tracks is not true then
            error "ERROR: apply compilation to all tracks is NOT set to true"
        end if

        -- Picture Management --
        set save front cover to all tracks to true
        if save front cover to all tracks is not true then
            error "ERROR: save front cover to all tracks is NOT set to true"
        end if
        set save all pictures to all tracks to true
        if save all pictures to all tracks is not true then
            error "ERROR: save all pictures to all tracks is NOT set to true"
        end if
    end tell
end setTagSettingsTest

on setTagSettingsDefaults given logging:logging
    tell application "SwiftTag"
        -- Value preferences --
        set zero pad track numbers to true
        if zero pad track numbers is not true then
            error "ERROR: zero pad track numbers is NOT set to true"
        end if
        set zero pad disc numbers to true
        if zero pad disc numbers is not true then
            error "ERROR: zero pad disc numbers is NOT set to true"
        end if

        -- Key preferences --
        set track total key to TOTALTRACKS and TRACKTOTAL
        if track total key is not (TOTALTRACKS and TRACKTOTAL) then
            error "ERROR: track total key is NOT set to TOTALTRACKS and TRACKTOTAL"
        end if
        set disc total key to TOTALDISCS
        if disc total key is not TOTALDISCS then
            error "ERROR: disc total key is NOT set to TOTALDISCS"
        end if

        -- Track Total/Compilation Management --
        set auto update track total to false
        if auto update track total is not false then
            error "ERROR: auto update track total is NOT set to false"
        end if
        set apply compilation to all tracks to false
        if apply compilation to all tracks is not false then
            error "ERROR: apply compilation to all tracks is NOT set to false"
        end if

        -- Picture Management --
        set save front cover to all tracks to false
        if save front cover to all tracks is not false then
            error "ERROR: save front cover to all tracks is NOT set to false"
        end if
        set save all pictures to all tracks to false
        if save all pictures to all tracks is not false then
            error "ERROR: save all pictures to all tracks is NOT set to false"
        end if
    end tell
end setTagSettingsDefaults

on setFeedBackSettingsTest given logging:logging
    tell application "SwiftTag"
        -- Send Save Notifications --
        set send save notifications to always
        if send save notifications is not always then
            error "ERROR: send save notifications is NOT set to always"
        end if

        -- Theme --
        set theme to system
        if theme is not system then
            error "ERROR: theme is NOT set to system"
        end if

        -- Quit App on Last Window Close --
        set quit app on last window close to true
        if quit app on last window close is not true then
            error "ERROR: quit app on last window close is NOT set to true"
        end if

        -- Tag Value Difference Colors --
        set track to track diff color to defaultPowderBlueColor
        set appTrackToTrackDiffColor to track to track diff color
        if appTrackToTrackDiffColor is not defaultPowderBlueColor then
            error "ERROR: track to track diff color is NOT set to powder blue"
        end if
        set track to file diff color to defaultPowderBlueColor
        set appTrackToFileDiffColor to track to file diff color
        if appTrackToFileDiffColor is not defaultPowderBlueColor then
            error "ERROR: track to file diff color is NOT set to powder blue"
        end if
        set externally modified diff color to defaultPowderBlueColor
        set appExternallyModifiedDiffColor to externally modified diff color
        if appExternallyModifiedDiffColor is not defaultPowderBlueColor then
            error "ERROR: externally modified diff color is NOT set to powder blue"
        end if
        set track and disc total mismatch color to defaultPowderBlueColor
        set appTrackAndDiscTotalMismatchColor to track and disc total mismatch color
        if appTrackAndDiscTotalMismatchColor is not defaultPowderBlueColor then
            error "ERROR: track and disc total mismatch color is NOT set to powder blue"
        end if
        if appTrackAndDiscTotalMismatchColor is not defaultPowderBlueColor then
            log "ERROR: track and disc total mismatch color is NOT set to powder blue"
        end if
        set picture status overlay color to defaultPowderBlueColor
        set appPictureStatusOverlayColor to picture status overlay color
        if appPictureStatusOverlayColor is not defaultPowderBlueColor then
            error "ERROR: picture status overlay color is NOT set to powder blue"
        end if
    end tell
end setFeedBackSettingsTest

on setFeedbackSettingsDefaults given logging:logging
    tell application "SwiftTag"
        set send save notifications to when not frontmost
        if send save notifications is not when not frontmost then
            error "ERROR: send save notifications is NOT set to when not frontmost"
        end if
        set theme to dark
        if theme is not dark then
            error "ERROR: theme is NOT set to dark"
        end if
        set quit app on last window close to false
        if quit app on last window close is not false then
            error "ERROR: quit app on last window close is NOT set to false"
        end if
        set track to track diff color to defaultTrackToTrackDiffColor
        if track to track diff color is not defaultTrackToTrackDiffColor then
            error "ERROR: track to track diff color is NOT set to defaultTrackToTrackDiffColor"
        end if
        set track to file diff color to defaultTrackToFileDiffColor
        if track to file diff color is not defaultTrackToFileDiffColor then
            error "ERROR: track to file diff color is NOT set to defaultTrackToFileDiffColor"
        end if
        set externally modified diff color to defaultExternallyModifiedDiffColor
        if externally modified diff color is not defaultExternallyModifiedDiffColor then
            error "ERROR: externally modified diff color is NOT set to defaultExternallyModifiedDiffColor"
        end if
        set track and disc total mismatch color to defaultTrackAndDiscTotalMismatchColor
        if track and disc total mismatch color is not defaultTrackAndDiscTotalMismatchColor then
            error "ERROR: track and disc total mismatch color is NOT set to defaultTrackAndDiscTotalMismatchColor"
        end if
        set picture status overlay color to defaultPictureStatusOverlayColor
        if picture status overlay color is not defaultPictureStatusOverlayColor then
            error "ERROR: picture status overlay color is NOT set to defaultPictureStatusOverlayColor"
        end if
    end tell
end setFeedbackSettingsDefaults

on setDiffToolsSettingsTest given logging:logging
    tell application "SwiftTag"
        set format on track to file diff to false
        if format on track to file diff is not false then
            error "ERROR: format on track to file diff is NOT set to false"
        end if
        set format on track to track diff to false
        if format on track to track diff is not false then
            error "ERROR: format on track to track diff is NOT set to false"
        end if
        set format on externally modified diff to false
        if format on externally modified diff is not false then
            error "ERROR: format on externally modified diff is NOT set to false"
        end if
        set format on track total mismatch to false
        if format on track total mismatch is not false then
            error "ERROR: format on track total mismatch is NOT set to false"
        end if
        set format on disc total mismatch to false
        if format on disc total mismatch is not false then
            error "ERROR: format on disc total mismatch is NOT set to false"
        end if
        set format on duplicate picture to false
        if format on duplicate picture is not false then
            error "ERROR: format on duplicate picture is NOT set to false"
        end if
    end tell
end setDiffToolsSettingsTest

on setDiffToolsSettingsDefaults given logging:logging
    tell application "SwiftTag"
        set format on track to file diff to true
        if format on track to file diff is not true then
            error "ERROR: format on track to file diff is NOT set to true"
        end if
        set format on track to track diff to true
        if format on track to track diff is not true then
            error "ERROR: format on track to track diff is NOT set to true"
        end if
        set format on externally modified diff to true
        if format on externally modified diff is not true then
            error "ERROR: format on externally modified diff is NOT set to true"
        end if
        set format on track total mismatch to true
        if format on track total mismatch is not true then
            error "ERROR: format on track total mismatch is NOT set to true"
        end if
        set format on disc total mismatch to true
        if format on disc total mismatch is not true then
            error "ERROR: format on disc total mismatch is NOT set to true"
        end if
        set format on duplicate picture to true
        if format on duplicate picture is not true then
            error "ERROR: format on duplicate picture is NOT set to true"
        end if
    end tell
end setDiffToolsSettingsDefaults