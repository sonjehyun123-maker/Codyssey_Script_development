#!/bin/bash

export AGENT_HOME="/home/agent-admin/agent-app"

APP_NAME="agent_app.py"
PORT=15034
LOG_FILE="/var/log/agent-app/monitor.log"
STATS_FILE="$AGENT_HOME/bin/stats.dat"
MAX_SIZE=$((10 * 1024 * 1024))

touch "$STATS_FILE"
touch "$LOG_FILE"
# 프로세스 살아있는지 확인
echo "====== SYSTEM MONITOR RESULT ======"
echo

echo "[HEALTH CHECK]"

PID=$(pgrep -fo "$APP_NAME")

if [ -z "$PID" ]; then
    echo "Checking process '$APP_NAME'... [FAIL]"
    exit 1
fi

echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"
# 포트 확인 
if ! ss -tuln | grep LISTEN | grep -q ":$PORT "; then
    echo "Checking port $PORT... [FAIL]"
    exit 1
fi
# 방화벽 확인
echo "Checking port $PORT... [OK]"

UFW_CHECK=$(sudo ufw status | grep "Status: active")

if [ -z "$UFW_CHECK" ]; then
    echo "[WARNING] Firewall is inactive."
fi
# CPU, 메모리, 디스크 추출
CPU=$(top -bn2 -d 0.5 | awk '/Cpu\(s\):/ {print 100 - $8}' | tail -n 1)
MEM=$(free | awk '/Mem:/ {print $3/$2 * 100.0}')
DISK=$(df -Ph / | tail -1 | awk '{print $5}' | sed 's/%//')

echo
echo "[RESOURCE MONITORING]"

printf "CPU Usage : %.1f%%\n" "$CPU"
printf "MEM Usage : %.1f%%\n" "$MEM"
echo "DISK Used  : $DISK%"

[[ $(echo "$CPU > 20" | bc -l) -eq 1 ]] \
&& echo "[WARNING] CPU threshold exceeded ($CPU% > 20%)"

[[ $(echo "$MEM > 10" | bc -l) -eq 1 ]] \
&& echo "[WARNING] MEM threshold exceeded ($MEM% > 10%)"

[ "$DISK" -gt 80 ] \
&& echo "[WARNING] DISK_USED threshold exceeded ($DISK% > 80%)"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "$TIMESTAMP $CPU $MEM" >> "$STATS_FILE"

LOG_LINE="[$TIMESTAMP] PID:$PID CPU:$(printf "%.1f" "$CPU")% MEM:$(printf "%.1f" "$MEM")% DISK_USED:$DISK%"

#로그 로테이션
echo "$LOG_LINE" >> "$LOG_FILE"

if [ "$(stat -c%s "$LOG_FILE")" -gt "$MAX_SIZE" ]; then

    [ -f "$LOG_FILE.10" ] && rm -f "$LOG_FILE.10"

    for i in {9..1}; do
        [ -f "$LOG_FILE.$i" ] \
        && mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
    done

    mv "$LOG_FILE" "$LOG_FILE.1"

    touch "$LOG_FILE"
    chown agent-admin:agent-core "$LOG_FILE"
    chmod 660 "$LOG_FILE"
fi

echo
echo "[INFO] Log appended: $LOG_FILE"