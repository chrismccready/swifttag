global utils

on run
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
    set testFLACPath_1 to testFLACPath
    set testPNGData to "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO3ZbZ0AAAAASUVORK5CYII="

    -- Run tests --
    set testTrack to getTrack for testFLACPath_1 at (getFrontEditorWindow()) given addTrack:true, logging:logging
    testFrontCoverPicture for testTrack given logging:logging
    utils's logLine about "PASSED: Front Cover Picture test." given logging:logging

    testPictureAddEditDelete for testTrack given testPNGData:testPNGData, logging:logging
    utils's logLine about "PASSED: Picture Add/Edit/Delete test." given logging:logging

    testPictureImportExport for testTrack given testPNGData:testPNGData, logging:logging
    utils's logLine about "PASSED: Picture Import/Export test." given logging:logging

    return "PASS"
end runTests

on getTrack for posixPath at editorWindow given addTrack:addTrack, logging:logging
    tell application "SwiftTag"
        if not addTrack then
            try
                set foundTrack to (first track of editorWindow whose its file is POSIX file posixPath)
                utils's logLine about "Using existing track for test FLAC path: " & (file of foundTrack) given logging:logging
                return foundTrack
            on error errorMessage number errorNumber
                if errorNumber is -1719 then
                    error "ERROR: Could not find existing track for test FLAC path: " & posixPath
                else
                    error "ERROR: Failed to get track for test FLAC path: " & posixPath & ". " & errorMessage & " (" & errorNumber & ")"
                end if
            end try
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

on testFrontCoverPicture for testTrack given logging:logging
    tell application "SwiftTag"
        tell testTrack
            set firstCover to item 1 of (every picture whose picture type is front cover)

            -- Picture ID and pool ID --
            set frontCoverId to id of firstCover
            if frontCoverId is missing value or (length of frontCoverId) is 0 then
                error "ERROR: First cover picture ID is invalid: " & frontCoverId
            else
                utils's logLine about "First cover picture ID: " & frontCoverId given logging:logging
            end if
            set frontCoverPoolId to pool id of firstCover
            if frontCoverPoolId is missing value or (length of frontCoverPoolId) is 0 then
                error "ERROR: First cover picture pool ID is invalid: " & frontCoverPoolId
            else
                utils's logLine about "First cover picture pool ID: " & frontCoverPoolId given logging:logging
            end if

            -- Picture type --
            set frontCoverPictureType to picture type of firstCover
            if frontCoverPictureType is not front cover then
                error "ERROR: First cover picture type is not front cover: " & frontCoverPictureType
            else
                utils's logLine about "First cover picture type: " & frontCoverPictureType given logging:logging
            end if

            -- Picture description --
            set frontCoverPictureDescription to description of firstCover
             if frontCoverPictureDescription is missing value or frontCoverPictureDescription is not "" then
                error "ERROR: First cover picture description is invalid (expected ''): " & frontCoverPictureDescription
            else
                utils's logLine about "First cover picture description: " & frontCoverPictureDescription given logging:logging
            end if

            -- Picture MIME type --
            set frontCoverPictureMimeType to mime type of firstCover
            if frontCoverPictureMimeType is not in {"image/jpeg", "image/png"} then
                error "ERROR: First cover picture MIME type is not valid: " & frontCoverPictureMimeType
            else
                utils's logLine about "First cover picture MIME type: " & frontCoverPictureMimeType given logging:logging
            end if

            -- Piscture Width and Height --
            set frontCoverPictureWidth to width of firstCover
            if frontCoverPictureWidth is missing value or frontCoverPictureWidth is not equal to 128 then
                error "ERROR: First cover picture width is invalid (expected 128): " & frontCoverPictureWidth
            else
                utils's logLine about "First cover picture width: " & frontCoverPictureWidth given logging:logging
            end if
            set frontCoverPictureHeight to height of firstCover
            if frontCoverPictureHeight is missing value or frontCoverPictureHeight is not equal to 128 then
                error "ERROR: First cover picture height is invalid (expected 128): " & frontCoverPictureHeight
            else
                utils's logLine about "First cover picture height: " & frontCoverPictureHeight given logging:logging
            end if

            -- Picture color depth and colors --
            set frontCoverPictureColorDepth to color depth of firstCover
            if frontCoverPictureColorDepth is missing value or frontCoverPictureColorDepth is not 24 then
                error "ERROR: First cover picture color depth is invalid (expected 24): " & frontCoverPictureColorDepth
            else
                utils's logLine about "First cover picture color depth: " & frontCoverPictureColorDepth given logging:logging
            end if
            set frontCoverPictureColors to colors of firstCover
            if frontCoverPictureColors is missing value or frontCoverPictureColors is not 0 then
                error "ERROR: First cover picture colors is invalid (expected 0): " & frontCoverPictureColors
            else
                utils's logLine about "First cover picture colors: " & frontCoverPictureColors given logging:logging
            end if

            -- Picture data --
            set frontCoverPictureData to data of firstCover
            set frontCoverPictureDataLengthKb to utils's getDataLengthKb for frontCoverPictureData
            if frontCoverPictureDataLengthKb is missing value or frontCoverPictureDataLengthKb is not equal to 2.5380859375 then
                error "ERROR: First cover picture data length is invalid (expected 2.5380859375 KB): " & frontCoverPictureDataLengthKb & " KB"
            else
                utils's logLine about "First cover picture data size (KB): " & frontCoverPictureDataLengthKb given logging:logging
            end if
        end tell
    end tell
end testFrontCoverPicture

on testPictureAddEditDelete for testTrack given testPNGData:testPNGData, logging:logging
    tell application "SwiftTag"
        tell testTrack
            -- Add picture --
            set newPictureDescription to "Test Add from AppleScript"
            try
                set existingPicture to first picture whose description is newPictureDescription and picture type is back cover
                delete existingPicture
                utils's logLine about "Deleted existing picture with description: " & newPictureDescription given logging:logging
            end try
            try
                set newPicture to make new picture with properties {data:testPNGData, picture type:back cover, description:newPictureDescription}
                utils's logLine about "Added picture with:" & return & Â
                    "  ¥ ID: " & id of newPicture & return & Â
                    "  ¥ pool ID: " & pool id of newPicture & return & Â
                    "  ¥ type: " & picture type of newPicture & return & Â
                    "  ¥ description: " & description of newPicture & return Â
                    given logging:logging
            on error errorMessage number errorNumber
                error "ERROR: Failed to add picture. " & errorMessage & " (" & errorNumber & ")"
            end try

            -- Confirm no duplicate picture IDs --
            try
                set picturesByPoolId to every picture whose pool id is (pool id of newPicture) and picture type is back cover
                if (count of picturesByPoolId) > 1 then
                    repeat with pic in picturesByPoolId
                        utils's logLine about "Duplicate picture ID: " & (id of pic) & ", description: " & (description of pic) given logging:logging
                    end repeat
                    error "ERROR: Duplicate picture IDs found for pool ID: " & (pool id of newPicture) & ", picture type: back cover. Count: " & (count of picturesByPoolId)
                end if
            on error errorMessage number errorNumber
                error "ERROR: Failed check for duplicate picture IDs. " & errorMessage & " (" & errorNumber & ")"
            end try

            -- Edit picture --
            try
                set description of newPicture to "Test Edit from AppleScript"
                utils's logLine about "Edited picture with ID: " & id of newPicture & ", new description: " & description of newPicture given logging:logging
            on error errorMessage number errorNumber
                error "ERROR: Failed to edit picture. " & errorMessage & " (" & errorNumber & ")"
            end try

            -- Delete picture --
            try
                copy id of newPicture to deletedPictureId
                delete newPicture
                utils's logLine about "Deleted picture with ID: " & deletedPictureId given logging:logging
            on error errorMessage number errorNumber
                error "ERROR: Failed to delete picture. " & errorMessage & " (" & errorNumber & ")"
            end try

            -- Add duplicate picture of same type --
            try
                set duplicatePicture_1 to make new picture with properties {data:testPNGData, picture type:back cover, description:"Duplicate Test 1"}
                set duplicatePicture_2 to make new picture with properties {data:testPNGData, picture type:back cover, description:"Duplicate Test 2"}
                set picturesByPoolId to every picture whose pool id is (pool id of duplicatePicture_1) and picture type is back cover
                if (count of picturesByPoolId) > 1 then
                    repeat with pic in picturesByPoolId
                        utils's logLine about "Found duplicate picture with ID: " & (id of pic) & ", description: " & (description of pic) given logging:logging
                    end repeat
                    error "ERROR: Was able to add duplicate pictures of same type with pool ID: " & (pool id of duplicatePicture_1) & ", picture type: back cover. This should not be allowed."
                end if
                set addedPicture to first item of picturesByPoolId
                if (description of addedPicture) is not equal to "Duplicate Test 2" then
                    error "ERROR: Picture with duplicate pool ID does not have expected description 'Duplicate Test 2'. Actual description: " & (description of addedPicture)
                end if
                utils's logLine about "Added single picture with pool ID: " & (pool id of addedPicture) & ", picture type: back cover, description: " & (description of addedPicture) given logging:logging
            on error errorMessage number errorNumber
                error "ERROR: Failed duplicate picture test. " & errorMessage & " (" & errorNumber & ")"
            end try

            -- Add duplicate picture of different type --
            try
                set duplicatePicture_3 to make new picture with properties {data:testPNGData, picture type:leaflet, description:"Duplicate by type Test 3"}
                set picturesByPoolId to every picture whose pool id is (pool id of duplicatePicture_3)
                repeat with pic in picturesByPoolId
                    utils's logLine about "Picture with same pool ID: " & (pool id of pic) & ", ID: " & (id of pic) & ", type: " & (picture type of pic) & ", description: " & (description of pic) given logging:logging
                end repeat
                if (count of picturesByPoolId) is not equal to 2 then
                    error "ERROR: Expected 2 pictures with same pool ID but found " & (count of picturesByPoolId) & " for pool ID: " & (pool id of duplicatePicture_3) given logging:logging
                end if
            on error errorMessage number errorNumber
                error "ERROR: Failed duplicate picture of different type test. " & errorMessage & " (" & errorNumber & ")"
            end try

            -- Restore track --
            set poolIdToDelete to (pool id of (first item of picturesByPoolId))
            delete every picture whose pool id is poolIdToDelete
            utils's logLine about "Restored track by deleting test pictures with pool ID: " & poolIdToDelete given logging:logging
        end tell
    end tell
end testPictureAddEditDelete

on testPictureImportExport for testTrack given testPNGData:testPNGData, logging:logging
    tell application "SwiftTag"
        tell testTrack
            -- Get original picture data --
            set leafletPictures to every picture whose picture type is leaflet
            if (count of leafletPictures) is not 1 then
                error "ERROR: Expected 1 leaflet picture but found " & (count of leafletPictures)
            end if
            set leafletPicture to first item of leafletPictures
            utils's logLine about "Original leaflet picture info:" & return & Â
                "  ¥ ID: " & id of leafletPicture & return & Â
                "  ¥ pool ID: " & pool id of leafletPicture & return & Â
                "  ¥ MIME type: " & MIME type of leafletPicture & return & Â
                "  ¥ width x height: " & width of leafletPicture & "x" & height of leafletPicture & return & Â
                "  ¥ description: " & description of leafletPicture given logging:logging
            copy data of leafletPicture to originalLeafletPictureData
            copy pool id of leafletPicture to originalLeafletPicturePoolId
            copy description of leafletPicture to originalLeafletPictureDescription

            -- import original picture as different type (to retain pool id in app) --
            try
                set reimportedAsMediaPicture to make new picture with properties {data:originalLeafletPictureData, picture type:media, description:"Reimported Original Picture As Media"}
                utils's logLine about "Reimported original leaflet as media picture info:" & return & Â
                    "  ¥ ID: " & id of reimportedAsMediaPicture & return & Â
                    "  ¥ pool ID: " & pool id of reimportedAsMediaPicture & return & Â
                    "  ¥ MIME type: " & MIME type of reimportedAsMediaPicture & return & Â
                    "  ¥ width x height: " & width of reimportedAsMediaPicture & "x" & height of reimportedAsMediaPicture & return & Â
                    "  ¥ description: " & description of reimportedAsMediaPicture given logging:logging
            on error errorMessage number errorNumber
                error "ERROR: Failed to reimport original picture. " & errorMessage & " (" & errorNumber & ")"
            end try
            if (pool id of reimportedAsMediaPicture) is not equal to originalLeafletPicturePoolId then
                error "ERROR: Reimported picture as different type has different pool ID. Original pool ID: " & originalLeafletPicturePoolId & ", reimported as media pool ID: " & (pool id of reimportedAsMediaPicture)
            end if

            -- Delete original picture --
            delete leafletPicture
            utils's logLine about "Deleted original leaflet picture to test reimporting original data." given logging:logging

            -- Import new picture --
            try
                set importedNewPicture to make new picture with properties {data:testPNGData, picture type:leaflet, description:"Test Import New Picture"}
                utils's logLine about "Imported new leaflet picture info:" & return & Â
                    "  ¥ ID: " & id of importedNewPicture & return & Â
                    "  ¥ pool ID: " & pool id of importedNewPicture & return & Â
                    "  ¥ MIME type: " & MIME type of importedNewPicture & return & Â
                    "  ¥ width x height: " & width of importedNewPicture & "x" & height of importedNewPicture & return & Â
                    "  ¥ description: " & description of importedNewPicture given logging:logging
            on error errorMessage number errorNumber
                error "ERROR: Failed to import picture. " & errorMessage & " (" & errorNumber & ")"
            end try

            -- Import original picture from memory --
            try
                set reimportedPicture to make new picture with properties {data:originalLeafletPictureData, picture type:leaflet, description:"Reimported Original Picture"}
                utils's logLine about "Reimported (from memory) original leaflet picture info:" & return & Â
                    "  ¥ ID: " & id of reimportedPicture & return & Â
                    "  ¥ pool ID: " & pool id of reimportedPicture & return & Â
                    "  ¥ MIME type: " & MIME type of reimportedPicture & return & Â
                    "  ¥ width x height: " & width of reimportedPicture & "x" & height of reimportedPicture & return & Â
                    "  ¥ description: " & description of reimportedPicture given logging:logging
            on error errorMessage number errorNumber
                error "ERROR: Failed to reimport original picture. " & errorMessage & " (" & errorNumber & ")"
            end try
            if (pool id of reimportedPicture) is not equal to originalLeafletPicturePoolId then
                error "ERROR: Reimported picture as different type has different pool ID. Original pool ID: " & originalLeafletPicturePoolId & ", reimported as media pool ID: " & (pool id of reimportedPicture)
            end if

            -- Delete reimported original picture --
            delete reimportedPicture
            utils's logLine about "Deleted reimported (from memory) original picture to test importing original data from file." given logging:logging

            -- Export/Import original picture to/from file --
            if count of (every picture whose picture type is leaflet) is not 1 then
                error "ERROR: Expected one leaflet pictures after deleting reimported picture."
            end if
            set exportFilePath to (POSIX path of (path to temporary items)) & "SwiftTagTestLeafletPicture.png"
            utils's saveBinaryData to exportFilePath given binaryData:originalLeafletPictureData
            utils's logLine about "Exported original leaflet picture data to file: " & exportFilePath given logging:logging
            set exportedPictureData to utils's getBase64EncodedData from exportFilePath
            set reimportedExportedPicture to make new picture with properties {data:exportedPictureData, picture type:leaflet, description:originalLeafletPictureDescription}
            utils's logLine about "Reimported (from file) original leaflet picture info:" & return & Â
                "  ¥ ID: " & id of reimportedExportedPicture & return & Â
                "  ¥ pool ID: " & pool id of reimportedExportedPicture & return & Â
                "  ¥ MIME type: " & MIME type of reimportedExportedPicture & return & Â
                "  ¥ width x height: " & width of reimportedExportedPicture & "x" & height of reimportedExportedPicture & return & Â
                "  ¥ description: " & description of reimportedExportedPicture given logging:logging
            if (pool id of reimportedExportedPicture) is not equal to originalLeafletPicturePoolId then
                error "ERROR: Reimported exported picture has different pool ID than original. Original pool ID: " & originalLeafletPicturePoolId & ", reimported exported pool ID: " & (pool id of reimportedExportedPicture)
            end if
            if not modified then
                error "ERROR: Track should be modified after importing picture from file, but is not."
            end if

            -- Delete imported new picture, media copy of original picture and reimport of original picture from file --
            copy (id of importedNewPicture) to importedNewPictureId
            copy (id of reimportedAsMediaPicture) to reimportedAsMediaPictureId
            delete importedNewPicture
            delete reimportedAsMediaPicture
            utils's logLine about "Deleted imported test pictures with ID: " & importedNewPictureId & " and " & reimportedAsMediaPictureId given logging:logging
            set leafletPictures to every picture whose picture type is leaflet
            if (count of leafletPictures) is not 1 then
                error "ERROR: Expected 1 leaflet picture but found " & (count of leafletPictures)
            end if
            if (description of (first item of leafletPictures)) is not equal to originalLeafletPictureDescription then
                error "ERROR: Leaflet picture description after test does not match original. Expected: " & originalLeafletPictureDescription & ", actual: " & (description of (first item of leafletPictures))
            end if
            if modified then
                error "ERROR: Track should not be modified after deleting test pictures and restoring original picture, but is still modified."
            end if
             utils's logLine about "Restored track to original state by deleting test pictures and confirming original picture is intact with correct description." given logging:logging
        end tell
    end tell
end testPictureImportExport