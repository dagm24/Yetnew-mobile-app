# Get SHA-1 Fingerprint for Debug Keystore
# Run this script in PowerShell to get the SHA-1 needed for Firebase

$keystorePath = "$env:USERPROFILE\.android\debug.keystore"
$javaPath = "keytool" # Assuming keytool is in PATH, if not we might need to find it

if (Test-Path $keystorePath) {
    Write-Host "Found debug keystore at: $keystorePath" -ForegroundColor Green
    Write-Host "Running keytool..." -ForegroundColor Cyan
    
    try {
        & keytool -list -v -keystore "$keystorePath" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1:"
    } catch {
        Write-Host "Error running keytool. Make sure Java is installed and 'keytool' is in your PATH." -ForegroundColor Red
    }
} else {
    Write-Host "Debug keystore not found at standard location: $keystorePath" -ForegroundColor Yellow
}
