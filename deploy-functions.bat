pi @echo off
chcp 65001 >nul
echo ========================================================
echo   Supabase Edge Functions Deployment (CLI)
echo   Project Ref: oawsmjpibfwpiaebvhot
echo ========================================================
echo.

set PROJECT_REF=oawsmjpibfwpiaebvhot

echo [1/7] Deploying create-customer...
call npx.cmd supabase functions deploy create-customer --project-ref %PROJECT_REF%

echo.
echo [2/7] Deploying create-tenant...
call npx.cmd supabase functions deploy create-tenant --project-ref %PROJECT_REF%

echo.
echo [3/7] Deploying delete-user...
call npx.cmd supabase functions deploy delete-user --project-ref %PROJECT_REF%

echo.
echo [4/7] Deploying genieacs-proxy...
call npx.cmd supabase functions deploy genieacs-proxy --project-ref %PROJECT_REF%

echo.
echo [5/7] Deploying send-whatsapp-notification...
call npx.cmd supabase functions deploy send-whatsapp-notification --project-ref %PROJECT_REF%

echo.
echo [6/7] Deploying update-user-auth...
call npx.cmd supabase functions deploy update-user-auth --project-ref %PROJECT_REF%

echo.
echo [7/7] Deploying whatsapp-reminder (no-verify-jwt untuk cron/webhook)...
call npx.cmd supabase functions deploy whatsapp-reminder --no-verify-jwt --project-ref %PROJECT_REF%

echo.
echo ========================================================
echo   Selesai! Semua Edge Functions telah diproses.
echo ========================================================
pause
