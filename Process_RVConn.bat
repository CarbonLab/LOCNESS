@echo on
cd /d C:\Users\spraydata
"C:\Program Files\MATLAB\R2022a\bin\matlab.exe" -noopengl -r "try; run('C:\Users\spraydata\Documents\GitHub\LOCNESS\run_ship_data_processing.m'); catch; end; exit;" >> C:\Users\spraydata\matlab_log.txt 2>&1
