global utils

on run
    set parentFolder to POSIX path of ((path to me as text) & "::")
    set testFLACPath_1 to parentFolder & "../SwiftTagTestFiles/test.flac"
    set testFLACPath_2 to parentFolder & "../SwiftTagTestFiles/test-with_padding.flac"
    set testUtilsPath to parentFolder & "test-utils.scpt"
    log "Loading SwiftTag test utils from: " & testUtilsPath
    set utils to load script (testUtilsPath as POSIX file)
    
    -- Run tests --
    runTests given testUtils:utils, testFLACPath_1:testFLACPath_1, testFLACPath_2:testFLACPath_2, logging:true
end run

on runTests given testUtils:testUtils, testFLACPath_1:testFLACPath_1, testFLACPath_2:testFLACPath_2, logging:logging
    set utils to testUtils
    set testFLACPath_1 to testFLACPath_1
    set testFLACPath_2 to testFLACPath_2

    -- Run tests --
    set frontWindow to getFrontEditorWindow()
    set testTrack to getTrack for testFLACPath_1 at frontWindow given logging:logging
    testDefinedCoreTag for testTrack given logging:logging
    utils's logLine about "PASSED: Defined Core Tag test." given logging:logging

    testDefinedMiscTag for testTrack given logging:logging
    utils's logLine about "PASSED: Defined Misc Tag test." given logging:logging

    testNewTag for testTrack given logging:logging
    utils's logLine about "PASSED: New Tag test." given logging:logging

    testDefinedAppleScriptReadOnlyTags for testTrack apart from testFLACPath_2 given logging:logging
    utils's logLine about "PASSED: Defined AppleScript Read-Only Tag test." given logging:logging

    testDefinedAppleScriptReadWriteTags for testTrack given logging:logging
    utils's logLine about "PASSED: Defined AppleScript Read-Write Tag test." given logging:logging

    testCountTags for testTrack at frontWindow given logging:logging
    utils's logLine about "PASSED: Count Tag test." given logging:logging

    return "PASS"
end runTests

on getTrack for posixPath at editorWindow given logging:logging
    tell application "SwiftTag"
        set existingTrack to utils's getTrack for posixPath at editorWindow
        if existingTrack is not missing value then
            utils's logLine about "Existing track for test FLAC path: " & (file of existingTrack) given logging:logging
        end if
        if utils's deleteTrack for posixPath at editorWindow then
            utils's logLine about "Deleted existing track with FLAC path: " & (utils's hfsFilePath for posixPath) given logging:logging
        end if
        set addedTrack to utils's addTrack for posixPath at editorWindow without locking
        utils's logLine about "Added track for test FLAC path: " & (file of addedTrack) given logging:logging
        return addedTrack
    end tell
end getTrack

on getFrontEditorWindow()
    tell application "SwiftTag"
        return front editor window
    end tell
end getFrontEditorWindow

on testDefinedCoreTag for testTrack given logging:logging
    tell application "SwiftTag"
        tell testTrack
            set tagAlbum to (first tag whose key is "ALBUM")
            utils's logLine about "Track album tag key: " & (key of tagAlbum) & ", value: " & (value of tagAlbum) given logging:logging
            set origTagAlbumValue to (value of tagAlbum)

            set tagValueIsMissing to ((value of tagAlbum) is missing value)
            utils's logLine about "Track album tag value is missing: " & tagValueIsMissing given logging:logging
            if tagValueIsMissing then
                error "ERROR: Track album tag value is missing (@ tagValueIsMissing)"
            end if

            set albumIsMissing to (album is missing value)
            utils's logLine about "Track album property is missing: " & albumIsMissing given logging:logging
            if albumIsMissing then
                error "ERROR: Track album property is missing (@ albumIsMissing)"
            end if

            set album to "AppleScript Property Album"
            utils's logLine about "Track album after setting album property: " & album given logging:logging
            if album is not "AppleScript Property Album" then
                error "ERROR: Failed to set track album property to 'AppleScript Property Album'"
            end if

            set album to ""
            utils's logLine about "Track album after setting album property: " & album  given logging:logging
            if album is not missing value then
                error "ERROR: Failed to set track album property to empty string"
            end if

            set album to origTagAlbumValue
            utils's logLine about "Track album after setting album property: " & album given logging:logging
            if album is not origTagAlbumValue then
                error "ERROR: Failed to reset track album property to original value"
            end if

            delete tagAlbum
            set albumIsMissingAfterTagDelete to (album is missing value)
            utils's logLine about "Track album property is missing after tag delete: " & albumIsMissingAfterTagDelete given logging:logging
            if not albumIsMissingAfterTagDelete then
                error "ERROR: Track album property is not missing after album tag delete (@ albumIsMissingAfterTagDelete)"
            end if

            try
                set tagAlbumDeleted to (first tag whose key is "ALBUM")
                error "ERROR: Album tag still exists after delete. Expected error when trying to access deleted tag, but got tag with key: " & (key of tagAlbumDeleted) & ", value: " & (value of tagAlbumDeleted)
            on error errorMessage number errorNumber
                if errorNumber is -1719 then
                    utils's logLine about "Track album tag is missing after tag delete, as expected" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to access album tag after delete: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try
            
            set album to origTagAlbumValue
            utils's logLine about "Track album after setting album property: " & album given logging:logging
            if album is not (value of tagAlbum) then
                error "ERROR: Failed to reset track album property to original value"
            end if

            delete album
            set albumIsMissingAfterPropertyDelete to (album is missing value)
            utils's logLine about "Track album property is missing after property delete: " & albumIsMissingAfterPropertyDelete given logging:logging
            if not albumIsMissingAfterPropertyDelete then
                error "ERROR: Track album property is not missing after album property delete (@ albumIsMissingAfterPropertyDelete)"
            end if
            
            set album to origTagAlbumValue
            utils's logLine about "Track album after setting album property: " & album given logging:logging
            if album is not (value of tagAlbum) then
                error "ERROR: Failed to reset track album property to original value"
            end if
        end tell
    end tell
end testDefinedCoreTag

on testDefinedMiscTag for testTrack given logging:logging
    tell application "SwiftTag"
        tell testTrack
            set tagEncodedBy to (first tag whose key is "ENCODED_BY")
            utils's logLine about "Track Encoded By tag key: " & (key of tagEncodedBy) & ", value: " & (value of tagEncodedBy) given logging:logging
            set origTagEncodedByValue to (value of tagEncodedBy)

            set tagValueIsMissing to ((value of tagEncodedBy) is missing value)
            utils's logLine about "Track Encoded By tag value is missing: " & tagValueIsMissing given logging:logging
            if tagValueIsMissing then
                error "ERROR: Track Encoded By tag value is missing (@ tagValueIsMissing)"
            end if

            set encodedByIsMissing to (encoded by is missing value)
            utils's logLine about "Track Encoded By property is missing: " & encodedByIsMissing given logging:logging
            if encodedByIsMissing then
                error "ERROR: Track Encoded By property is missing (@ encodedByIsMissing)"
            end if

            set encoded by to "Test Encoded By from AppleScript"
            utils's logLine about "Track Encoded By after setting encoded by property: " & encoded by given logging:logging
            if encoded by is not "Test Encoded By from AppleScript" then
                error "ERROR: Failed to set track Encoded By property to 'Test Encoded By from AppleScript'"
            end if

            set encoded by to ""
            utils's logLine about "Track Encoded By after setting encoded by property: " & encoded by  given logging:logging
            if encoded by is not missing value then
                error "ERROR: Failed to set track Encoded By property to empty string"
            end if

            set encoded by to origTagEncodedByValue
            utils's logLine about "Track Encoded By after setting encoded by property: " & encoded by given logging:logging
            if encoded by is not (value of tagEncodedBy) then
                error "ERROR: Failed to reset track Encoded By property to original value"
            end if
        end tell
    end tell
end testDefinedMiscTag

on testNewTag for testTrack given logging:logging
    tell application "SwiftTag"
        tell testTrack
            try
                set tagTest to (first tag whose key is "TEST")
                if tagTest is not missing value then
                    utils's logLine about "Test tag already exists. Deleting existing test tag before running test." given logging:logging
                    delete tagTest
                end if
            end try
            
            -- make new TEST tag --
            set newTag to make new tag with properties {key:"TEST", value:"This is a test"}
            utils's logLine about "Created new tag with key: " & (key of newTag) & ", value: " & (value of newTag) given logging:logging
            set newTagFoundByKey to (first tag whose key is "TEST")
            if newTagFoundByKey is missing value then
                error "ERROR: Failed to find newly created TEST tag by key."
            else if (key of newTagFoundByKey) is not "TEST" then
                error "ERROR: Found tag by key 'TEST', but tag key is not 'TEST'. Found tag key: " & (key of newTagFoundByKey)
            else if (value of newTagFoundByKey) is not "This is a test" then
                error "ERROR: Found tag by key 'TEST', but tag value is not 'This is a test'. Found tag value: " & (value of newTagFoundByKey)
            else
                utils's logLine about "Successfully found newly created TEST tag by key with correct key and value." given logging:logging
            end if

            -- update TEST tag value --
            set value of newTag to "This is an updated test value"
            utils's logLine about "Updated TEST tag value to: " & (value of newTag) given logging:logging
            set updatedTagFoundByKey to (first tag whose key is "TEST")
            if updatedTagFoundByKey is missing value then
                error "ERROR: Failed to find updated TEST tag by key."
            else if (key of updatedTagFoundByKey) is not "TEST" then
                error "ERROR: Found tag by key 'TEST', but tag key is not 'TEST' after update. Found tag key: " & (key of updatedTagFoundByKey)
            else if (value of updatedTagFoundByKey) is not "This is an updated test value" then
                error "ERROR: Found tag by key 'TEST', but tag value is not 'This is an updated test value' after update. Found tag value: " & (value of updatedTagFoundByKey)
            else
                utils's logLine about "Successfully found updated TEST tag by key with correct key and updated value." given logging:logging
            end if

            -- delete TEST tag
            delete newTag
            utils's logLine about "Deleted TEST tag." given logging:logging
            try
                set testTagAfterDelete to (first tag whose key is "TEST")
                if testTagAfterDelete is not missing value then
                    error "ERROR: TEST tag still exists after deletion."
                end if
            end try
        end tell
    end tell
end testNewTag

on testDefinedAppleScriptReadOnlyTags for testTrack apart from anotherTestFLACPath given logging:logging
    tell application "SwiftTag"
        tell testTrack
            set trackBitsPerSample to bits per sample
            utils's logLine about "Track bits per sample: " & trackBitsPerSample given logging:logging
            try
                set bits per sample to 4
                error "ERROR: Was able to modify read-only bits per sample property. Original bits per sample: " & trackBitsPerSample & ", bits per sample after modification attempt: " & (bits per sample)
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only bits per sample property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only bits per sample property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try

            set trackChannels to channels
            utils's logLine about "Track channels: " & trackChannels given logging:logging
            try
                set channels to 5
                error "ERROR: Was able to modify read-only channels property. Original channels: " & trackChannels & ", channels after modification attempt: " & channels
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only channels property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only channels property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try

            set trackDuration to duration
            utils's logLine about "Track duration: " & trackDuration given logging:logging
            try
                set duration to 123456
                error "ERROR: Was able to modify read-only duration property. Original duration: " & trackDuration & ", duration after modification attempt: " & duration
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only duration property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only duration property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try

            set trackFile to file
            utils's logLine about "Track file: " & trackFile given logging:logging
            try                
                set its file to (POSIX file anotherTestFLACPath)
                error "ERROR: Was able to modify read-only file property. Original file: " & trackFile & ", file after modification attempt: " & (file)
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only file property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only file property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try

            set trackFingerprint to fingerprint
            utils's logLine about "Track fingerprint: " & trackFingerprint given logging:logging
            try
                set fingerprint to "1234567890"
                error "ERROR: Was able to modify read-only fingerprint property. Original fingerprint: " & trackFingerprint & ", fingerprint after modification attempt: " & fingerprint
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only fingerprint property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only fingerprint property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try

            set trackFLACFingerprint to FLAC fingerprint
            utils's logLine about "Track FLAC fingerprint: " & trackFLACFingerprint given logging:logging
            try
                set FLAC fingerprint to "1234567890"
                error "ERROR: Was able to modify read-only FLAC fingerprint property. Original FLAC fingerprint: " & trackFLACFingerprint & ", FLAC fingerprint after modification attempt: " & (FLAC fingerprint)
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only FLAC fingerprint property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only FLAC fingerprint property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try

            set trackSampleRate to sample rate
            utils's logLine about "Track sample rate: " & trackSampleRate given logging:logging
            try
                set sample rate to 12345
                error "ERROR: Was able to modify read-only sample rate property. Original sample rate: " & trackSampleRate & ", sample rate after modification attempt: " & (sample rate)
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only sample rate property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only sample rate property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try

            set  trackTotalSamples to total samples
            utils's logLine about "Track total samples: " & trackTotalSamples given logging:logging
            try
                set total samples to 123456789
                error "ERROR: Was able to modify read-only total samples property. Original total samples: " & trackTotalSamples & ", total samples after modification attempt: " & (total samples)
            on error errorMessage number errorNumber
                if errorNumber is -10006 then
                    utils's logLine about "Successfully prevented modification of read-only total samples property" given logging:logging
                else
                    error "ERROR: Unexpected error when trying to modify read-only total samples property: " & errorMessage & " (" & errorNumber & ")"
                end if
            end try
        end tell
    end tell
end testDefinedAppleScriptReadOnlyTags

on testDefinedAppleScriptReadWriteTags for testTrack given logging:logging
    tell application "SwiftTag"
        tell testTrack
            -- album --
            copy album to originalValue
            set album to originalValue & " (Modified)"
            utils's assertTag for testTrack given tagKey:"ALBUM", hasValue:originalValue & " (Modified)", logging:logging
            set album to originalValue
            utils's logLine about "album: " & album given logging:logging

            -- album artist --
            copy album artist to originalValue
            set album artist to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"ALBUMARTIST", hasValue:originalValue & "(Modified)", logging:logging
            set album artist to originalValue
            utils's logLine about "album artist: " & album artist given logging:logging

            -- artist --
            copy artist to originalValue
            set artist to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"ARTIST", hasValue:originalValue & "(Modified)", logging:logging
            set artist to originalValue
            utils's logLine about "artist: " & artist given logging:logging

            -- comment --
            set comment to "(Modified)"
            utils's assertTag for testTrack given tagKey:"COMMENT", hasValue:"(Modified)", logging:logging
            set comment to missing value
            utils's logLine about "comment: " & comment given logging:logging

            -- compilation --
            set compilation to true
            utils's assertTag for testTrack given tagKey:"COMPILATION", hasValue:"1", logging:logging
            set compilation to false
            utils's logLine about "compilation: " & compilation given logging:logging

            -- composer --
            copy composer to originalValue
            set composer to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"COMPOSER", hasValue:originalValue & "(Modified)", logging:logging
            set composer to originalValue
            utils's logLine about "composer: " & composer given logging:logging

            -- conductor --
            set conductor to "(Modified)"
            utils's assertTag for testTrack given tagKey:"CONDUCTOR", hasValue:"(Modified)", logging:logging
            set conductor to missing value
            utils's logLine about "conductor: " & conductor given logging:logging

            -- copyright --
            set copyright to "(Modified)"
            utils's assertTag for testTrack given tagKey:"COPYRIGHT", hasValue:"(Modified)", logging:logging
            set copyright to missing value
            utils's logLine about "copyright: " & copyright given logging:logging

            -- date --
            copy release date to originalValue
            set release date to date "January 1, 2024"
            utils's assertTag for testTrack given tagKey:"DATE", hasValue:"2024-01-01", logging:logging
            set release date to originalValue
            utils's logLine about "date: " & release date given logging:logging

            -- description --
            copy description to originalValue
            set description to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"DESCRIPTION", hasValue:originalValue & "(Modified)", logging:logging
            set description to originalValue
            utils's logLine about "description: " & description given logging:logging

            -- director --
            set director to "(Modified)"
            utils's assertTag for testTrack given tagKey:"DIRECTOR", hasValue:"(Modified)", logging:logging
            set director to missing value
            utils's logLine about "director: " & director given logging:logging

            -- disc count --
            copy disc count to originalValue
            set disc count to originalValue + 1
            utils's assertTag for testTrack given tagKey:"TOTALDISCS", hasValue:(originalValue + 1) as text, logging:logging
            set disc count to originalValue
            utils's logLine about "disc count: " & disc count given logging:logging

            -- disc number --
            copy disc number to originalValue
            set disc number to originalValue + 1
            utils's assertTag for testTrack given tagKey:"DISCNUMBER", hasValue:(originalValue + 1) as text, logging:logging
            set disc number to originalValue
            utils's logLine about "disc number: " & disc number given logging:logging

            -- encoded by --
            copy encoded by to originalValue
            set encoded by to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"ENCODED_BY", hasValue:originalValue & "(Modified)", logging:logging
            set encoded by to originalValue
            utils's logLine about "encoded by: " & encoded by given logging:logging

            -- encoded using --
            set encoded using to "(Modified)"
            utils's assertTag for testTrack given tagKey:"ENCODED_USING", hasValue:"(Modified)", logging:logging
            set encoded using to missing value
            utils's logLine about "encoded using: " & encoded using given logging:logging

            -- encoder --
            set encoder to "(Modified)"
            utils's assertTag for testTrack given tagKey:"ENCODER", hasValue:"(Modified)", logging:logging
            set encoder to missing value
            utils's logLine about "encoder: " & encoder given logging:logging

            -- encoder options --
            set encoder options to "(Modified)"
            utils's assertTag for testTrack given tagKey:"ENCODER_OPTIONS", hasValue:"(Modified)", logging:logging
            set encoder options to missing value
            utils's logLine about "encoder options: " & encoder options given logging:logging

            -- genre --
            copy genre to originalValue
            set genre to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"GENRE", hasValue:originalValue & "(Modified)", logging:logging
            set genre to originalValue
            utils's logLine about "genre: " & genre given logging:logging

            -- ISRC --
            set ISRC to "(Modified)"
            utils's assertTag for testTrack given tagKey:"ISRC", hasValue:"(Modified)", logging:logging
            set ISRC to missing value
            utils's logLine about "ISRC: " & ISRC given logging:logging

            -- license --
            set license to "(Modified)"
            utils's assertTag for testTrack given tagKey:"LICENSE", hasValue:"(Modified)", logging:logging
            set license to missing value
            utils's logLine about "license: " & license given logging:logging

            -- lineage --
            set lineage to "(Modified)"
            utils's assertTag for testTrack given tagKey:"LINEAGE", hasValue:"(Modified)", logging:logging
            set lineage to missing value
            utils's logLine about "lineage: " & lineage given logging:logging

            -- location --
            copy location to originalValue
            set location to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"LOCATION", hasValue:originalValue & "(Modified)", logging:logging
            set location to originalValue
            utils's logLine about "location: " & location given logging:logging

            -- narrator --
            set narrator to "(Modified)"
            utils's assertTag for testTrack given tagKey:"NARRATOR", hasValue:"(Modified)", logging:logging
            set narrator to missing value
            utils's logLine about "narrator: " & narrator given logging:logging

            -- performer --
            set performer to "(Modified)"
            utils's assertTag for testTrack given tagKey:"PERFORMER", hasValue:"(Modified)", logging:logging
            set performer to missing value
            utils's logLine about "performer: " & performer given logging:logging

            -- producer --
            set producer to "(Modified)"
            utils's assertTag for testTrack given tagKey:"PRODUCER", hasValue:"(Modified)", logging:logging
            set producer to missing value
            utils's logLine about "producer: " & producer given logging:logging

            -- ratimg --
            set rating to 4
            utils's assertTag for testTrack given tagKey:"RATING", hasValue:"4", logging:logging
            set rating to missing value
            utils's logLine about "rating: " & rating given logging:logging

            -- replay album gain --
            set replay album gain to "-5.5"
            utils's assertTag for testTrack given tagKey:"REPLAYGAIN_ALBUM_GAIN", hasValue:"-5.5", logging:logging
            set replay album gain to missing value
            utils's logLine about "replay album gain: " & replay album gain given logging:logging

            -- replay album peak --
            set replay album peak to "0.95"
            utils's assertTag for testTrack given tagKey:"REPLAYGAIN_ALBUM_PEAK", hasValue:"0.95", logging:logging
            set replay album peak to missing value
            utils's logLine about "replay album peak: " & replay album peak given logging:logging

            -- replay track gain --
            set replay track gain to "-3.0"
            utils's assertTag for testTrack given tagKey:"REPLAYGAIN_TRACK_GAIN", hasValue:"-3.0", logging:logging
            set replay track gain to missing value
            utils's logLine about "replay track gain: " & replay track gain given logging:logging

            -- replay track peak --
            set replay track peak to "0.90"
            utils's assertTag for testTrack given tagKey:"REPLAYGAIN_TRACK_PEAK", hasValue:"0.90", logging:logging
            set replay track peak to missing value
            utils's logLine about "replay track peak: " & replay track peak given logging:logging

            -- sort album --
            set sort album to "(Modified)"
            utils's assertTag for testTrack given tagKey:"ALBUMSORT", hasValue:"(Modified)", logging:logging
            set sort album to missing value
            utils's logLine about "sort album: " & sort album given logging:logging

            -- sort album artist --
            set sort album artist to "(Modified)"
            utils's assertTag for testTrack given tagKey:"ALBUMARTISTSORT", hasValue:"(Modified)", logging:logging
            set sort album artist to missing value
            utils's logLine about "sort album artist: " & sort album artist given logging:logging

            -- sort artist --
            set sort artist to "(Modified)"
            utils's assertTag for testTrack given tagKey:"ARTISTSORT", hasValue:"(Modified)", logging:logging
            set sort artist to missing value
            utils's logLine about "sort artist: " & sort artist given logging:logging

            -- sort composer --
            set sort composer to "(Modified)"
            utils's assertTag for testTrack given tagKey:"COMPOSERSORT", hasValue:"(Modified)", logging:logging
            set sort composer to missing value
            utils's logLine about "sort composer: " & sort composer given logging:logging

            -- sort title --
            set sort title to "(Modified)"
            utils's assertTag for testTrack given tagKey:"TITLESORT", hasValue:"(Modified)", logging:logging
            set sort title to missing value
            utils's logLine about "sort title: " & sort title given logging:logging

            -- source --
            set source to "(Modified)"
            utils's assertTag for testTrack given tagKey:"SOURCE", hasValue:"(Modified)", logging:logging
            set source to missing value
            utils's logLine about "source: " & source given logging:logging

            -- title --
            copy title to originalValue
            set title to originalValue & "(Modified)"
            utils's assertTag for testTrack given tagKey:"TITLE", hasValue:originalValue & "(Modified)", logging:logging
            set title to originalValue
            utils's logLine about "title: " & title given logging:logging

            -- track count --
            copy track count to originalValue
            set track count to originalValue + 1
            utils's assertTag for testTrack given tagKey:"TOTALTRACKS", hasValue:(originalValue + 1) as text, logging:logging
            set track count to originalValue
            utils's logLine about "track count: " & track count given logging:logging

            -- track number --
            copy track number to originalValue
            set track number to originalValue + 1
            utils's assertTag for testTrack given tagKey:"TRACKNUMBER", hasValue:(originalValue + 1) as text, logging:logging
            set track number to originalValue
            utils's logLine about "track number: " & track number given logging:logging

            -- vendor --
            set vendor to "(Modified)"
            utils's assertTag for testTrack given tagKey:"VENDOR", hasValue:"(Modified)", logging:logging
            set vendor to missing value
            utils's logLine about "vendor: " & vendor given logging:logging

            -- version --
            set version to "(Modified)"
            utils's assertTag for testTrack given tagKey:"VERSION", hasValue:"(Modified)", logging:logging
            set version to missing value
            utils's logLine about "version: " & version given logging:logging
        end tell
    end tell
end testDefinedAppleScriptReadWriteTags

on testCountTags for testTrack at editorWindow given logging:logging
    tell application "SwiftTag"
        tell testTrack
            -- log all tags for debugging --
            repeat with thisTag in tags
                utils's logLine about "Tag key: " & (key of thisTag) & ", value: " & (value of thisTag) given logging:logging
            end repeat

            -- validate tag count --
            set tagCount to count of tags
            if tagCount is not in {14, 40} then
                try
                    set tagTest to (first tag whose key is "TEST")
                    if tagCount is not in {15, 41} or tagTest is not missing value then
                        error "ERROR: Unexpected track tag count: " & tagCount
                    end if
                on error errorMessage number errorNumber
                    if errorNumber is -1719 then
                        error "ERROR: Unexpected track tag count: " & tagCount & " (and `TEST` tag is missing/deleted)."
                    else
                        error "ERROR: Unexpected track tag count: " & tagCount & ". " & errorMessage & " (" & errorNumber & ")"
                    end if
                end try 
            else
                utils's logLine about "Track tag count: " & tagCount given logging:logging
            end if
        end tell

        -- reload track to ensure tag count is consistent after reload --
        copy (utils's posixFilePath for (file of testTrack)) to testTrackPath
        utils's deleteTrack for testTrackPath at editorWindow
        set reloadedTrack to utils's addTrack for testTrackPath at editorWindow without locking

        -- validate tag count again after reload --
        tell reloadedTrack
            -- log all tags for debugging --
            repeat with thisTag in tags
                utils's logLine about "Tag key: " & (key of thisTag) & ", value: " & (value of thisTag) given logging:logging
            end repeat

            -- validate tag count --
            set tagCount to count of tags
            if tagCount is not 14 then
                error "ERROR: Unexpected track tag count: " & tagCount
            else
                utils's logLine about "Track tag count after reload: " & tagCount given logging:logging
            end if
        end tell
    end tell
end testCountTags