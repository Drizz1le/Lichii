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
rem Cache the page pointers of per-draw texture handle reads.
set EDEN_NX2_HANDLE_PTR_CACHE=1
rem Skip rebuilding the pipeline key when the registers it reads are unchanged.
set EDEN_NX2_PIPELINE_CLEAN=1
rem Compare small uniform buffers in guest memory instead of copying them first.
set EDEN_NX2_UBO_INPLACE=1
rem Log where the GPU threads spend their time every 10 s (eden_log.txt).
set EDEN_NX2_GPU_PROFILE=1

rem Measured slower on a 9800X3D (25 to 21 fps in Kokiri Forest); left off.
rem set EDEN_NX2_CORE_PLAN=1
rem Draws per GPU submission (default 4096 on desktop): try 1024 if the GPU waits a lot.
rem set EDEN_NX2_FLUSH_DRAWS=1024

rem Function-level profile instead of the zone timers above: samples the GPU threads and the
rem game CPU cores 1000 times a second for 20 s, starting 90 s after launch (get in game by then),
rem into nx2_samples_<pid>.bin in %APPDATA%\eden\log. Send that file with eden_log.txt.
rem set EDEN_NX2_SAMPLE_PROFILE=1000
rem set EDEN_NX2_SAMPLE_DELAY=90
rem set EDEN_NX2_SAMPLE_THREADS=GPU,GPUBack,VulkanWorker,CPUCore_*

start "" "%~dp0lichii.exe" %*
