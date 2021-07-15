# DB Haproxy Netstat IP list with number of connections
netstat -tunlpa | grep "ESTABLISHED" | grep 5432 | grep "10.10.0.5" | wc -l
netstat -tunlpa | grep "ESTABLISHED" | grep "188.188.188.188" | wc -l
netstat -ntu | awk ' $5 ~ /^[0-9]/ {print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
netstat -antu | grep 10.10.0.5 | grep -v LISTEN | cut -d: -f2 | sort | uniq -c | sort -n

# Logs
# https://www.linux.com/training-tutorials/how-analyze-haproxy-logs/
cat haproxy.log | halog -srv -H -q | awk 'NR==1; NR > 1 {print $0 | "sort -n -r -k 6"}' | column -t
cat haproxy.log.2021-02-22 | halog -srv -H -q | awk 'NR==1; NR > 1 {print $0 | "sort -n -r -k 6"}' | column -t
