function Push-CurrentFileLocation() {
    <#
    .Synopsis
        Runs Push-Location into the location of the current file
    .Description
        Runs Push-Location into the location of the current file
    .Example
        Push-CurrentFileLocation
    #>
    param()
    Push-Location (Split-Path $psise.CurrentFile.FullPath)
}