@echo off
setlocal
title Setup Ghigi

rem === Da aggiornare a ogni release (deve coincidere col tag GitHub) ===
set "VERSION=v1.0.0"
set "REPO=SIJ82/ghigi-setup"
set "ASSET=setup.bat"

echo Setup Ghigi %VERSION%
echo.

rem --- Auto-aggiornamento ---
set "LATEST="
for /f "delims=" %%t in ('powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try{(Invoke-RestMethod -UseBasicParsing https://api.github.com/repos/%REPO%/releases/latest -TimeoutSec 10).tag_name}catch{}"') do set "LATEST=%%t"
if not defined LATEST (
    echo [!] Impossibile controllare gli aggiornamenti, continuo.
    goto :install
)
rem ponytail: confronto per uguaglianza, non semver; basta che l'ultima release sia sempre la piu' nuova
if /i "%LATEST%"=="%VERSION%" goto :install

echo Nuova versione disponibile: %LATEST%. Scarico...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing https://github.com/%REPO%/releases/latest/download/%ASSET% -OutFile '%~f0.new'"
if errorlevel 1 (
    echo [!] Download fallito, continuo con la versione attuale.
    goto :install
)
rem cmd rilegge il .bat mentre gira: sostituirlo da un processo separato dopo che questo e' uscito
start "" cmd /c "timeout /t 2 /nobreak >nul & move /y "%~f0.new" "%~f0" >nul & "%~f0""
exit

:install
where winget >nul 2>&1 || (
    echo [X] winget non trovato. Installa "App Installer" dal Microsoft Store e riprova.
    goto :end
)

call :pkg EclipseAdoptium.Temurin.25.JDK "Java Temurin 25"
call :polymc

rem --- Ricarica PATH dal registro (winget non aggiorna la sessione corrente) ---
for /f "delims=" %%p in ('powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; [Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')"') do set "PATH=%%p"

call :checkjava && goto :ok

rem --- Java 25 non nel PATH: lo aggiungo al PATH utente ---
set "JDK="
for /d %%d in ("%ProgramFiles%\Eclipse Adoptium\jdk-25*") do set "JDK=%%d"
if not defined JDK (
    echo [X] Cartella di Temurin 25 non trovata in "%ProgramFiles%\Eclipse Adoptium".
    goto :end
)
echo Aggiungo "%JDK%\bin" al PATH utente...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; $p=[Environment]::GetEnvironmentVariable('Path','User'); [Environment]::SetEnvironmentVariable('Path','%JDK%\bin;'+$p,'User'); [Environment]::SetEnvironmentVariable('JAVA_HOME','%JDK%','User')"
set "PATH=%JDK%\bin;%PATH%"
call :checkjava || (
    echo [X] Java 25 ancora non trovato nel PATH.
    goto :end
)

:ok
echo.
echo [OK] Tutto pronto. Se un terminale era gia' aperto, riaprilo per vedere il nuovo PATH.

call :findpoly || (
    echo [X] polymc.exe non trovato.
    goto :end
)
echo Avvio PolyMC...
start "" "%POLY%"
exit

rem === Funzioni ===
:polymc
call :findpoly && (
    echo [OK] PolyMC gia' installato.
    exit /b 0
)
set "ARCH=amd64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=aarch64"
set "PMSETUP=%TEMP%\PolyMC-Setup.exe"
echo Scarico PolyMC (%ARCH%) dall'ultima release GitHub...
powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; $r=Invoke-RestMethod -UseBasicParsing https://api.github.com/repos/PolyMC/PolyMC/releases/latest; $a=$r.assets | ?{$_.name -like 'PolyMC-Windows-Setup-%ARCH%-*.exe'} | select -First 1; if(!$a){exit 1}; Invoke-WebRequest -UseBasicParsing $a.browser_download_url -OutFile '%PMSETUP%'"
if errorlevel 1 (
    echo [!] Download di PolyMC fallito.
    exit /b 1
)
echo Installo PolyMC...
start "" /wait "%PMSETUP%" /S
del "%PMSETUP%" >nul 2>&1
call :findpoly || echo [!] Installazione di PolyMC fallita.
exit /b 0

:findpoly
set "POLY="
for %%f in ("%LOCALAPPDATA%\Programs\PolyMC\polymc.exe" "%ProgramFiles%\PolyMC\polymc.exe") do if exist %%f set "POLY=%%~f"
if defined POLY exit /b 0
exit /b 1

:pkg
winget list --id %1 -e --source winget >nul 2>&1 && (
    echo [OK] %~2 gia' installato.
    exit /b 0
)
echo Installo %~2...
winget install --id %1 -e --source winget --silent --accept-package-agreements --accept-source-agreements
if errorlevel 1 echo [!] Installazione di %~2 fallita o annullata.
exit /b 0

:checkjava
java -version 2>&1 | findstr /r /c:"version .25" >nul || exit /b 1
echo [OK] Java 25 trovato nel PATH:
java -version 2>&1 | findstr /c:"version"
exit /b 0

:end
echo.
pause
