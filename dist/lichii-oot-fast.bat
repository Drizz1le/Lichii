@echo off
rem Starts Lichii with the draw fast paths and the GPU profile on.
rem Variables set here are in place before lichii.exe starts, so they work even in builds
rem where nx2_switches.txt is read too late for them. Put "rem " in front of a line to turn it off.

rem Reuse an unchanged draw's bindings; 2 also takes draws that only change buffers or offsets.
set EDEN_NX2_FAST_DRAW=2
rem Skip vertex buffer lookups and upload scans for ranges nothing wrote since the last draw.
set EDEN_NX2_BUFFER_SKIP=1
rem Tell the texture, query and shader caches only about pages they hold something on.
set EDEN_NX2_INLINE_INVALIDATE=1
rem Skip dynamic state updates on draws that changed none.
set EDEN_NX2_DYNAMIC_SKIP=1
rem Log where the GPU threads spend their time every 10 s (eden_log.txt).
set EDEN_NX2_GPU_PROFILE=1

rem Measured slower on a 9800X3D (25 to 21 fps in Kokiri Forest); left off.
rem set EDEN_NX2_CORE_PLAN=1
rem Draws per GPU submission (default 128): try 256 and 512.
rem set EDEN_NX2_FLUSH_DRAWS=256

start "" "%~dp0lichii.exe" %*
