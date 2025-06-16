@echo off
SETLOCAL

:: ----------- CONFIGURATION -----------
set REGISTRY=us.icr.io
set NAMESPACE=django-apps
set CE_PROJECT=django-project
set REGION=us-south
set RESOURCE_GROUP=Default

:: ----------- LOAD CONFIG FILE AND VALIDATE API KEY -----------
set CONFIG_FILE=codeengine.env

echo Loading environment variables from "%CONFIG_FILE%"...

if not exist "%CONFIG_FILE%" (
    echo.
    echo ❌ ERROR: Config file "%CONFIG_FILE%" not found in the script directory.
    echo 📁 Expected location: %~dp0%CONFIG_FILE%
    echo 💡 Create a file named "%CONFIG_FILE%" with this content:
    echo IBM_CLOUD_API_KEY=your-api-key-here
    echo.
    pause
    exit /B 1
)

:: Load variables from config file
for /F "tokens=1,2 delims==" %%a in (%CONFIG_FILE%) do (
    set %%a=%%b
)

:: Check if API key is actually set
if "%IBM_CLOUD_API_KEY%"=="" (
    echo.
    echo ❌ ERROR: IBM_CLOUD_API_KEY is not set or is empty in "%CONFIG_FILE%".
    echo 💡 Make sure it contains:
    echo IBM_CLOUD_API_KEY=your-api-key-here
    echo.
    pause
    exit /B 1
)

@echo off
SETLOCAL

:: ----------- CONFIGURATION -----------
set REGISTRY=us.icr.io
set NAMESPACE=django-apps
set CE_PROJECT=django-project
set REGION=us-south
set CONFIG_FILE=codeengine.env

:: ----------- LOAD ENVIRONMENT VARIABLES -----------
echo Loading environment variables from "%CONFIG_FILE%"...
if not exist "%CONFIG_FILE%" (
    echo ❌ ERROR: Config file "%CONFIG_FILE%" not found.
    echo 💡 Expected: IBM_CLOUD_API_KEY=your-api-key
    pause
    exit /B 1
)

for /F "tokens=1,2 delims==" %%a in (%CONFIG_FILE%) do (
    set %%a=%%b
)

if "%IBM_CLOUD_API_KEY%"=="" (
    echo ❌ ERROR: IBM_CLOUD_API_KEY is not set.
    pause
    exit /B 1
)

:: ----------- SET AND VALIDATE APP NAME -----------
set "APP_NAME=django-app-1"


set IMAGE=%REGISTRY%/%NAMESPACE%/%APP_NAME%:latest

:: ----------- IBM CLOUD LOGIN -----------
echo Logging in to IBM Cloud...
ibmcloud login --apikey %IBM_CLOUD_API_KEY% -q
IF ERRORLEVEL 1 (
    echo ERROR: IBM Cloud login failed.
    EXIT /B 1
)

:: ----------- AUTO-DETECT DEFAULT RESOURCE GROUP -----------
echo Detecting default resource group...
for /F "tokens=1,3" %%a in ('ibmcloud resource groups') do (
    echo %%b | findstr /I /C:"true" >nul
    if not errorlevel 1 (
        set "RESOURCE_GROUP=%%a"
    )
)

if "%RESOURCE_GROUP%"=="" (
    echo ❌ ERROR: Could not detect default resource group.
    echo 💡 Tip: Run 'ibmcloud resource groups' to check your access.
    pause
    exit /B 1
)

echo ✅ Default resource group detected: %RESOURCE_GROUP%

:: ----------- SET TARGET -----------
echo Targeting region: %REGION%, resource group: %RESOURCE_GROUP%...
ibmcloud target -r %REGION% -g %RESOURCE_GROUP%

:: ----------- CONTAINER REGISTRY LOGIN -----------
echo Setting Container Registry region...
ibmcloud cr region-set %REGION%
echo Logging into IBM Container Registry...
ibmcloud cr login


:: ----------- ENSURE NAMESPACE EXISTS -----------
echo Checking for namespace "%NAMESPACE%"...
set "FOUND_NAMESPACE="
FOR /F "tokens=*" %%i IN ('ibmcloud cr namespaces') DO (
    echo %%i | findstr /I /C:"%NAMESPACE%" >nul
    IF NOT ERRORLEVEL 1 (
        set FOUND_NAMESPACE=true
    )
)
IF NOT DEFINED FOUND_NAMESPACE (
    echo Namespace "%NAMESPACE%" not found. Creating...
    ibmcloud cr namespace-add %NAMESPACE%
    IF ERRORLEVEL 1 (
        echo ERROR: Failed to create namespace.
        exit /B 1
    )
) ELSE (
    echo Namespace "%NAMESPACE%" already exists.
)

:: ----------- BUILD, TAG, AND PUSH IMAGE -----------
echo Building Docker image %APP_NAME%:latest ...
docker build . -t %APP_NAME%:latest
IF ERRORLEVEL 1 (
    echo ❌ ERROR: Docker build failed.
    exit /B 1
)

echo Tagging image for push to ICR...
docker tag %APP_NAME%:latest %IMAGE%

:: ----------- CLEAN OLD IMAGES IF QUOTA NEAR LIMIT -----------
echo Checking images in namespace "%NAMESPACE%"...

setlocal EnableDelayedExpansion
set COUNT=0
set IMAGE_LIMIT=10

:: Get all image digests in the namespace and write to temp file
set "TMP_IMG_LIST=_imagelist.txt"
ibmcloud cr images --restrict %NAMESPACE% --format "{{.Repository}}:{{.Tag}}" > %TMP_IMG_LIST%

for /F "usebackq delims=" %%i in ("%TMP_IMG_LIST%") do (
    set /A COUNT+=1
    set "IMG[!COUNT!]=%%i"
)

echo 🧮 Found !COUNT! images in registry.

if !COUNT! GTR !IMAGE_LIMIT! (
    set /A TO_DELETE=!COUNT! - !IMAGE_LIMIT!
    echo 🗑 Removing !TO_DELETE! oldest images...

    for /L %%K in (1,1,!TO_DELETE!) do (
        echo Deleting: us.icr.io/!IMG[%%K]!
        ibmcloud cr image-rm --force us.icr.io/!IMG[%%K]! >nul 2>&1
    )
) else (
    echo ✅ Image count within limit. No cleanup needed.
)

del %TMP_IMG_LIST%
endlocal



echo Pushing Docker image to IBM Cloud Container Registry...
docker push %IMAGE%

:: ----------- CHECK OR CREATE CODE ENGINE PROJECT -----------
echo Checking for Code Engine project "%CE_PROJECT%"...
set "PROJECT_FOUND="
FOR /F "usebackq tokens=*" %%p IN (`ibmcloud ce project list --output json ^| findstr /i /C:"\"name\""`) DO (
    echo %%p | findstr /I /C:"%CE_PROJECT%" >nul
    IF NOT ERRORLEVEL 1 (
        set "PROJECT_FOUND=true"
    )
)
IF NOT DEFINED PROJECT_FOUND (
    echo Project "%CE_PROJECT%" not found. Creating...
    ibmcloud ce project create --name %CE_PROJECT%
    IF ERRORLEVEL 1 (
        echo ❌ ERROR: Failed to create Code Engine project.
        exit /B 1
    )
)

echo Selecting Code Engine project "%CE_PROJECT%"...
ibmcloud ce project select --name %CE_PROJECT%

echo 🛡️ Checking if 'icr-secret' exists...
for /f "tokens=*" %%s in ('ibmcloud ce registry list --output json ^| findstr /C:"\"name\": \"icr-secret\""') do set SECRET_FOUND=1

if NOT DEFINED SECRET_FOUND (
    echo 🔐 'icr-secret' not found. Creating...
    ibmcloud ce registry create --name icr-secret ^
        --server %REGISTRY% ^
        --username iamapikey ^
        --password %IBM_CLOUD_API_KEY%
) else (
    echo ✅ 'icr-secret' already exists.
)



:: ----------- DEPLOY APPLICATION -----------
echo 🚀 Deploying with APP_NAME: %APP_NAME%
set IMAGE_PATH=%REGISTRY%/%NAMESPACE%/%APP_NAME%:latest

echo Deploying application to Code Engine...
ibmcloud ce application create --name %APP_NAME% --image %IMAGE_PATH% --registry-secret icr-secret --port 8000

