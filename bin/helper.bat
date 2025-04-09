@echo off

set arg=%1
if not defined arg (
  echo ERROR: %~nx0 - missing arguments
  exit /b 1
)

set command=
set args=

:loop
set arg=%1
if not defined arg goto run

call set "arg=%%arg:\"="%%"
call set "arg=%%arg:\\=\%%"

if not defined command (
  set command=%arg%
) else if not defined args (
  set args=%arg%
) else (
  set args=%args% %arg%
)
shift
goto loop

:run
::echo cmd: %command% %args%
%command% %args%

exit /b %ERRORLEVEL%
