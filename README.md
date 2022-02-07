# Invoke-Ping
Ping multiple computers asynchronously once or over a specified timeframe and intervals.
Data returned includes the total count of pings (TCnt) and successful count of pongs (SCnt).
Data is either sent to the pipeline or exported to CSV.
Default settings will ping for 4 hours at 60 second intervals.

## Example Output
```PowerShell
Computer  : comp1
Status    : Success
IPAddress : 0.0.0.0
TCnt      : 3
SCnt      : 3
```
