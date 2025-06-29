@echo off
setlocal

:: Set default values
set BUILD_TYPE=Release
set RUN_TESTS=OFF
set ENABLE_TIDY=OFF
set ENABLE_FORMAT=OFF
set USE_MSVC=OFF

:: Parse command line arguments
:parse_args
if "%~1"=="" goto :end_parse_args
if /i "%~1"=="--debug" set BUILD_TYPE=Debug
if /i "%~1"=="--test" set RUN_TESTS=ON
if /i "%~1"=="--tidy" set ENABLE_TIDY=ON
if /i "%~1"=="--msvc" set USE_MSVC=ON
if /i "%~1"=="--format" set ENABLE_FORMAT=ON
shift
goto :parse_args
:end_parse_args

echo Updating git submodules...
git submodule update --init --recursive

:: If not using MSVC, check if clang is in PATH
if "%USE_MSVC%"=="OFF" (
    where clang >nul 2>nul
    if errorlevel 1 (
        echo "clang not found in PATH!"
        exit /b 1
    )
)

:: Initialize bgfx.cmake if build directory doesn't exist
if not exist "thirdparty\bgfx.cmake" (
    echo Error: bgfx.cmake directory not found!
    exit /b 1
)

if not exist "thirdparty\bgfx.cmake\build" (
    echo Initializing bgfx.cmake...
    pushd thirdparty\bgfx.cmake
    git submodule init
    git submodule update

    if "%USE_MSVC%"=="ON" (
        :: Use default MSVC compiler
        cmake -S. -B build
    ) else (
        :: Use Clang compiler
        cmake -S. -B build -G "Ninja" ^
            -DCMAKE_C_COMPILER=clang ^
            -DCMAKE_CXX_COMPILER=clang++
    )
    
    cmake --build build
    popd
)

:: Run clang-format if enabled
if "%ENABLE_FORMAT%"=="ON" (
    echo Running clang-format on source files...
    for /r src %%f in (*.cpp) do clang-format -i "%%f"
    for /r src %%f in (*.h) do clang-format -i "%%f"
    for /r tests %%f in (*.cpp) do clang-format -i "%%f"
    for /r tests %%f in (*.h) do clang-format -i "%%f"
)



:: Set build directory based on compiler
if "%USE_MSVC%"=="ON" (
    set BUILD_DIR=build-msvc
) else (
    set BUILD_DIR=build-clang
)

if not exist %BUILD_DIR% mkdir %BUILD_DIR%
cd %BUILD_DIR%

:: Configure CMake 
:: Let system decide the generator
if "%USE_MSVC%"=="ON" (
    if "%ENABLE_TIDY%"=="ON" (
        cmake .. -DCLANG_TIDY_ENABLE=ON
    ) else (
        cmake ..
    )
) else (
    if "%ENABLE_TIDY%"=="ON" (
        cmake .. -G "Ninja" ^
            -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
            -DCMAKE_C_COMPILER=clang ^
            -DCMAKE_CXX_COMPILER=clang++ ^
            -DCLANG_TIDY_ENABLE=ON
    ) else (
        cmake .. -G "Ninja" ^
            -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
            -DCMAKE_C_COMPILER=clang ^
            -DCMAKE_CXX_COMPILER=clang++
    )
)

:: Build project
if "%USE_MSVC%"=="ON" (
    :: For MSVC, specify the configuration
    cmake --build . --config %BUILD_TYPE%
) else (
    cmake --build .
)

:: If you need to run tests
if "%RUN_TESTS%"=="ON" (
    if "%USE_MSVC%"=="ON" (
        ctest -C %BUILD_TYPE% -R Boids_Test --output-on-failure
    ) else (
        ctest -R Boids_Test --output-on-failure
    )
)

endlocal