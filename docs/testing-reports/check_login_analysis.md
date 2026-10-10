# Check Login Function Analysis

## Mechanism
Bot function `check_login()` located at /usr/local/bin/bot-daemon line 613:
- Parses /var/log/xray/access.log (last 3 minutes)
- Uses awk to extract username + IPs from "accepted" lines
- Counts unique (user,IP) pairs per user
- format_online_users() filters by protocol via grep on expiry files

## Bottlenecks Identified
1. Protocol detection: O(n×m) - sequential grep per user
2. Log parsing: tac reverses entire log file
3. No caching between requests

## Test Requirements
- Create 5-10 users per protocol
- Simulate concurrent connections
- Verify all users detected correctly
- Compare bot output vs ground truth (manual log parse)
