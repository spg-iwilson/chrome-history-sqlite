# Chrome History to CSV script

This PowerShell script will retrieve the last 180 days of browser history for separate profiles and write the results to history.csv. 

This CSV file can then be used for analysing your activity by date, Chrome profile, domain. I find this useful to recall what I was working on.

Can be configured to scan multiple Chromium-based browsers such as Google Chrome and Microsoft Edge in a single execution.

The script uses a sqlite DLL to access the Chrome history data.

<img width="800" alt="Daily page visits and profiles" src="https://github.com/user-attachments/assets/a2cef85d-6dbc-4d21-94a8-ade430fc4ef0" />
