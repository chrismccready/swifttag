use framework "Foundation"
use scripting additions

on run
    return "SwiftTag Library"
end run

on trackExists for posixPath at editorWindow
    tell application "SwiftTag"
        set foundTrack to (first track of editorWindow whose its file is POSIX file posixPath)
        return foundTrack is not missing value
    end tell
end trackExists

on getTrack for posixPath at editorWindow
    tell application "SwiftTag"
        try
            set foundTrack to (first track of editorWindow whose its file is POSIX file posixPath)
            return foundTrack
        end try
    end tell
    return missing value
end getTrack

on addTrack for posixPath at editorWindow given locking:locking
    tell application "SwiftTag"
        try
            set newTrack to add POSIX file posixPath with lock locking to editorWindow
            return newTrack
        on error errorMessage number errorNumber
            if errorNumber is 8 then
                error "ERROR: Failed to add track. " & errorMessage & " (8) Permissions (sandbox) issue."
            else
                error "ERROR: Failed to add track. " & errorMessage
            end if
        end try
    end tell
end addTrack

on deleteTrack for posixPath at editorWindow
    tell application "SwiftTag"
        try
            set foundTrack to (first track of editorWindow whose its file is POSIX file posixPath)
            if foundTrack is not missing value then
                delete foundTrack
                return true
            end if
        end try
    end tell
    return false
end deleteTrack

on deleteMetadata for theTrack given deleteTags:deleteTags, deletePictures:deletePictures
    tell application "SwiftTag"
        if deleteTags then
            try
                delete tags of theTrack
            on error errMsg number errNum
                if errNum is not -1728 then -- ignore "can't delete missing value" error which can happen if there are no tags to delete
                    "Error deleting tags: " & errMsg & " (error number: " & errNum & ")"
                end if
            end try
        end if
        if deletePictures then
            try
                delete pictures of theTrack
            on error errMsg number errNum
                if errNum is not -1728 then -- ignore "can't delete missing value" error which can happen if there are no pictures to delete
                    "Error deleting pictures: " & errMsg & " (error number: " & errNum & ")"
                end if
            end try
        end if
    end tell
end deleteMetadata

on hfsFilePath for posixFilePath
    return POSIX file posixFilePath
end hfsFilePath

on posixFilePath for hfsFilePath
    return POSIX path of hfsFilePath
end posixFilePath

on getDataLengthKb for binaryData
    set dataSizeBytes to my getDataLength for binaryData
    set dataSizeKb to dataSizeBytes / 1024
    return dataSizeKb
end getDataLengthKb

on getDataLength for binaryData
    set tempBlobPath to (path to temporary items as text) & "swifttag-binary-blob.bin"
    set blobFileDescriptor to open for access tempBlobPath with write permission
    try
        set eof blobFileDescriptor to 0
        write (binaryData as data) to blobFileDescriptor

        set byteCount to get eof blobFileDescriptor
        set eof blobFileDescriptor to 0
        close access blobFileDescriptor

        return byteCount
    on error errMsg number errNum
        try
            close access blobFileDescriptor
        end try
        error errMsg number errNum
    end try
end getDataLength

on getData from filePath
    try
        set fileAlias to POSIX file filePath as alias
    on error
         error "ERROR: Could not get file alias. Check the path."
    end try

    set fileHandle to open for access fileAlias
    try
        set fileData to read fileAlias to eof as data
        close access fileHandle
        return fileData
    on error errMsg number errNum
        try
            close access fileHandle
        end try
        error errMsg number errNum
    end try
end getData

on getBase64EncodedData from filePath
    try
        set fileURL to current application's |NSURL|'s fileURLWithPath:filePath
        set fileData to current application's NSData's dataWithContentsOfURL:fileURL
        if fileData is missing value then
            error "ERROR: Could not read data from file. Check the path."
        end if
        return (fileData's base64EncodedStringWithOptions:0) as text
    on error errorMessage number errorNumber
        error "ERROR: Failed to get byte data. " & errorMessage & " (" & errorNumber & ")"
    end try
end getBase64EncodedData

on saveBinaryData to filePath given binaryData:binaryData
    set fileDescriptor to open for access filePath with write permission
    try
        set eof fileDescriptor to 0
        write (binaryData as data) to fileDescriptor
        close access fileDescriptor
    on error errMsg number errNum
        try
            close access fileDescriptor
        end try
        error errMsg number errNum
    end try
end saveBinaryData

on shortUUID from theUUID
    return text 1 thru 8 of theUUID
end shortUUID

on logLine about theLine given logging:logging
    if logging then
        log theLine
    end if
end logLine

-- assertions --

on assertTrackExists for posixPath at editorWindow
    tell application "SwiftTag"
        set foundTrack to (first track of editorWindow whose its file is POSIX file posixPath)
         if foundTrack is missing value then
            error "ERROR: Expected to find a track with file path " & posixPath & ", but did not find one."
        end if
    end tell
end assertTrackExists

on assertDeleteTrack for track at editorWindow
    tell application "SwiftTag"
        try
            delete track of editorWindow
        on error errorMessage number errorNumber
            error "ERROR: Failed to delete track: " & errorMessage & " (Error number: " & errorNumber & ")"
        end try
    end tell
end assertDeleteTrack

on assertTag for testTrack given tagKey:tagKey, hasValue:expectedValue, logging:logging
    tell application "SwiftTag"
        set tagValue to (value of (first tag whose key is tagKey) of testTrack)
        if tagValue is not expectedValue then
            error "ERROR: Tag '" & tagKey & "' value mismatch. Expected: '" & expectedValue & "', but got: '" & tagValue & "'."
        end if
    end tell
end assertTag

on assertFileExists for posixPath
    try
        POSIX file posixPath as alias
    on error
        error "ERROR: File does not exist at path: " & posixPath
    end try   
end assertFileExists