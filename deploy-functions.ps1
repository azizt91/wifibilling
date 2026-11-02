# Script PowerShell untuk Deploy Semua Supabase Edge Functions
$ProjectRef = "oawsmjpibfwpiaebvhot"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Supabase Edge Functions Deployment (CLI)" -ForegroundColor Cyan
Write-Host "  Project Ref: $ProjectRef" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$functions = @(
    @{ Name = "create-customer"; NoJwt = $false },
    @{ Name = "create-tenant"; NoJwt = $false },
    @{ Name = "delete-user"; NoJwt = $false },
    @{ Name = "genieacs-proxy"; NoJwt = $false },
    @{ Name = "send-whatsapp-notification"; NoJwt = $false },
    @{ Name = "update-user-auth"; NoJwt = $false },
    @{ Name = "whatsapp-reminder"; NoJwt = $true }
)

$i = 1
$total = $functions.Count

foreach ($fn in $functions) {
    Write-Host "`n[$i/$total] Deploying $($fn.Name)..." -ForegroundColor Yellow
    if ($fn.NoJwt) {
        & npx.cmd supabase functions deploy $fn.Name --no-verify-jwt --project-ref $ProjectRef
    } else {
        & npx.cmd supabase functions deploy $fn.Name --project-ref $ProjectRef
    }
    $i++
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "  Selesai! Semua Edge Functions telah diproses." -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
