@echo on
cd /d C:\Users\spraydata
REM "C:\Program Files\MATLAB\R2022a\bin\matlab.exe" -nosplash -nodesktop "run('C:\Users\spraydata\Documents\GitHub\Spray2_Processing\prelim_plot_spray2pH.m')" >> C:\Users\spraydata\matlab_log.txt 2>&1
"C:\Program Files\MATLAB\R2022a\bin\matlab.exe" -noopengl -r "try; run('C:\Users\spraydata\Documents\GitHub\LOCNESS\run_data_processing.m'); catch; end; exit;" >> C:\Users\spraydata\matlab_log.txt 2>&1

REM taskkill /IM matlab.exe /F
REM matlab -r "run('C:\Users\spraydata\Documents\GitHub\Spray2_Processing\prelim_plot_spray2pH.m')" >> C:\Users\spraydata\matlab_log.txt 2>&1