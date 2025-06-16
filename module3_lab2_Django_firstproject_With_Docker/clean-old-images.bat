@echo off

:: -------- CONFIG --------
set REGION=us-south
set RESOURCE_GROUP=Default
set NAMESPACE=django-apps
set REGISTRY=us.icr.io
set KEEP_COUNT=2
set ENV_FILE=codeengine.env
set IMG_TMP=_images.txt
set IMG_SORTED=_images_sorted.txt

:: -------- LOAD API KEY --------
echo Loading IBM Cloud API key from %ENV_FILE%...
if not exist "%ENV_FILE%" (
    echo ERROR: .env file not found.
    exit /B 1
)

set "IBM_CLOUD_API_KEY="
for /F "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if /I "%%A"=="IBM_CLOUD_API_KEY" set "IBM_CLOUD_API_KEY=%%B"
)

if "%IBM_CLOUD_API_KEY%"=="" (
    echo ERROR: IBM_CLOUD_API_KEY not set in %ENV_FILE%.
    exit /B 1
)

:: -------- LOGIN TO IBM CLOUD --------
echo Logging into IBM Cloud...
ibmcloud logout >nul
ibmcloud login --apikey "%IBM_CLOUD_API_KEY%" -r %REGION% -g %RESOURCE_GROUP% >nul
ibmcloud cr region-set %REGION% >nul

:: -------- FETCH IMAGE LIST --------
echo Getting image list in namespace "%NAMESPACE%"...
ibmcloud cr images --restrict %NAMESPACE% --format "{{.Repository}}@{{.Digest}}" > %IMG_TMP%
sort %IMG_TMP% > %IMG_SORTED%

:: -------- COUNT IMAGES --------
set COUNT=0
for /F "usebackq delims=" %%L in ("%IMG_SORTED%") do (
    set /A COUNT=COUNT+1
)

echo Found %COUNT% image(s) in the registry.

:: -------- DELETE OLD IMAGES IF NEEDED --------
set /A DELETE_COUNT=%COUNT% - %KEEP_COUNT%
if %DELETE_COUNT% LEQ 0 (
    echo No cleanup needed.
    goto :done
)

echo Deleting %DELETE_COUNT% old image(s)...

set INDEX=0
for /F "usebackq delims=" %%L in ("%IMG_SORTED%") do (
    set /A INDEX=INDEX+1
    call :processImage %%INDEX%% %%L
    if %INDEX% GEQ %DELETE_COUNT% goto :done
)

:done
del %IMG_TMP% >nul 2>&1
del %IMG_SORTED% >nul 2>&1
echo Cleanup complete.
exit /B 0

:processImage
set IDX=%1
set IMG_LINE=%2
echo Deleting image: %REGISTRY%/%IMG_LINE%
ibmcloud cr image-rm --force %REGISTRY%/%IMG_LINE% >nul 2>&1
exit /B 0
