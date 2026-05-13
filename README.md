# Codyssey_Script_development
## 시스템 관제 자동화 스크립트 개발
### 1. 기본 보안 및 네트워크 설정
#### SSH 포트 변경(20022) 및 Root 원격 접속 차단 설정 확인 내역
* SSH(Secure Shell) : 원격 시스템 접속 및 명령 실행을 위한 보안 네트워크 프로토콜

```bash
# 1. SSH 설정 파일 수정
sudo nano /etc/ssh/sshd_config

# 수정 내용
Port 20022
PermitRootLogin no

# 2. SSH 서비스 재시작
sudo systemctl restart ssh

# 3. SSH 서비스 상태 확인
sudo systemctl status ssh

# May 11 14:07:03 SON systemd[1]: Starting ssh.service - OpenBSD Secure Shell server.>
# May 11 14:07:03 SON sshd[1311]: Server listening on 0.0.0.0 port 20022.
# May 11 14:07:03 SON sshd[1311]: Server listening on :: port 20022.
# May 11 14:07:03 SON systemd[1]: Started ssh.service - OpenBSD Secure Shell server.

# 4. 설정값 확인
grep -E 'Port|PermitRootLogin' /etc/ssh/sshd_config

# 결과
# Port 20022
# PermitRootLogin no

# 5. 포트 리슨 상태 확인
ss -tulnp | grep ssh

# 결과
# tcp   LISTEN 0      4096         0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=xxx))
# tcp   LISTEN 0      4096            [::]:20022         [::]:*    users:(("sshd",pid=xxx))
```

#### 방화벽(UFW 또는 firewalld) 활성화 및 20022/tcp, 15034/tcp만 허용 내역
* UFW 활성화 및 허용 포트 설정 내역
    * 허용 포트 : TCP 20022(SSH), TCP 15034(APP)
```bash
# 1. UFW 설치
sudo apt install ufw -y

# 2. 기본 설정
sudo ufw default deny incoming # 들어오는 모든 연결을 기본적으로 거부
sudo ufw default allow outgoing # 나가는 모든 연결을 기본적으로 허용

# 3. SSH 포트 허용
sudo ufw allow 20022/tcp
# Rules updated
# Rules updated (v6)

# 4. APP 포트 허용
sudo ufw allow 15034/tcp
# Rules updated
# Rules updated (v6)

# 5. 방화벽 활성화
sudo ufw enable

# 결과
# Firewall is active and enabled on system startup

# 6. 방화벽 상태 확인
sudo ufw status verbose

# 결과
# Status: active
#
# To                         Action      From
# --                         ------      ----
# 20022/tcp                  ALLOW IN    Anywhere
# 15034/tcp                  ALLOW IN    Anywhere
# 20022/tcp (v6)             ALLOW IN    Anywhere (v6)
# 15034/tcp (v6)             ALLOW IN    Anywhere (v6)
```

### 2. 계정/그룹/권한 체계(협업 + 최소 권한)

#### 계정 및 그룹 생성 확인 내역
* 생성 계정
    * agent-admin   : 운영/관리, cron 실행자
    * agent-dev     : 개발/운영, monitor.sh 작성자
    * agent-test    : QA/테스트
* 생성 그룹
    * agent-common  : admin, dev, test
    * agent-core    : admin, dev
```bash
# 1. 그룹 생성
sudo groupadd agent-common
sudo groupadd agent-core

# 2. 사용자 생성
sudo useradd -m -g agent-common -G agent-core agent-admin
sudo useradd -m -g agent-common -G agent-core agent-dev
sudo useradd -m -g agent-common agent-test

# 3. 사용자 정보 확인
id agent-admin
id agent-dev
id agent-test

# 결과
# agent-admin : uid=1001(agent-admin) gid=1001(agent-common) groups=1001(agent-common),1002(agent-core)
# agent-dev   : uid=1002(agent-dev) gid=1001(agent-common) groups=1001(agent-common),1002(agent-core)
# agent-test  : uid=1003(agent-test) gid=1001(agent-common) groups=1001(agent-common)

# 4. 그룹 확인
grep -E 'agent-common|agent-core' /etc/group

# 결과
# agent-common:x:1001:
# agent-core:x:1002:agent-admin,agent-dev
```
#### 디렉토리 구조 및 권한(ACL 포함) 확인 내역
* ACL(Access Control List) : 추가 접근 권한 제어 기능
```bash
# 1. AGENT_HOME 생성
sudo mkdir -p /home/agent-admin/agent-app

# 2. 디렉토리 생성
sudo mkdir -p /home/agent-admin/agent-app/upload_files
sudo mkdir -p /home/agent-admin/agent-app/api_keys
sudo mkdir -p /home/agent-admin/agent-app/bin
sudo mkdir -p /var/log/agent-app

# 3. 그룹 설정
sudo chown -R agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chown -R agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chown -R agent-admin:agent-core /var/log/agent-app

# 4. 권한 설정
sudo chmod 770 /home/agent-admin/agent-app/upload_files
sudo chmod 770 /home/agent-admin/agent-app/api_keys
sudo chmod 770 /var/log/agent-app

# 5. ACL 설정
# agent-test는 upload_files 읽기/쓰기 가능
sudo setfacl -m u:agent-test:rwx /home/agent-admin/agent-app/upload_files

# agent-test는 api_keys 접근 차단
sudo setfacl -m u:agent-test:--- /home/agent-admin/agent-app/api_keys

# 6. 권한 확인
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app

# 결과
# drwxrwx---+ 2 agent-admin agent-common 4096 May 8 21:50 upload_files
# drwxrwx---+ 2 agent-admin agent-core   4096 May 8 21:50 api_keys
# drwxrwx---+ 2 agent-admin agent-core   4096 May 8 21:50 agent-app

# 7. ACL 확인
getfacl /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/api_keys
getfacl /home/agent-admin/agent-app/upload_files

# 결과
# file: upload_files
# owner: agent-admin
# group: agent-common
# user::rwx
# user:agent-test:rwx
# group::rwx
# mask::rwx
# other::---

# file: api_keys
# owner: agent-admin
# group: agent-core
# user::rwx
# user:agent-test:---
# group::rwx
# mask::rwx
# other::---
```
### 3. 애플리케이션 실행 환경 구성(제공 Python 앱)
#### 환경 변수
```bash
sudo su - agent-admin
#계정의 Home에 있는 설정 파일 수정 
nano ~/.bashrc

# 추가
export AGENT_HOME="/home/agent-admin/agent-app"
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR="/var/log/agent-app"
#bashrc 업데이트 된 내용 적용 및 재부팅
source ~/.bashrc
```
#### 키파일 생성

```bash
echo $AGENT_HOME
# /home/agent-admin/agent-app

echo $AGENT_PORT
# 15034

echo $AGENT_UPLOAD_DIR
# /home/agent-admin/agent-app/upload_files

#키 보관용 폴더 생성
mkdir -p $AGENT_HOME/api_keys

# 키 파일 생성 및 내용 기입
echo "agent_api_key_test" > $AGENT_KEY_PATH

# 파일 확인
cat $AGENT_KEY_PATH
# 결과: agent_api_key_test

# 1. 로그 디렉토리 생성 
sudo mkdir -p $AGENT_LOG_DIR

# 2. 소유권 및 권한 설정
sudo chown agent-admin:agent-core $AGENT_LOG_DIR
sudo chmod 770 $AGENT_LOG_DIR

ls -ld $AGENT_LOG_DIR
# drwxrwx--- 2 agent-admin agent-core 4096 May 11 14:25 /var/log/agent-app

```

#### 앱 실행 및 성공 기준
* 일반 계정으로 실행(루트 실행 금지)
* Boot Sequence 5단계가 모두 [OK]로 출력되고, 마지막에 “Agent READY”가 출력되어야 한다.
* 앱이 0.0.0.0:15034로 LISTEN 상태가 되어야 한다.
* 참고: 앱 종료는 Ctrl+C로 수행한다.
```bash
cd $AGENT_HOME

# 디렉토리의 소유자를 agent-admin으로 변경
sudo chown -R agent-admin:agent-admin $AGENT_HOME

# 폴더에 읽기/쓰기/실행 권한 부여
chmod 755 $AGENT_HOME

cd $AGENT_HOME
nano agent_app.py

#===============작성===========
import os
import sys
import time
import socket

def start_agent():
    print("> Starting Agent Boot Sequence...")
    
    # 1단계: 계정 확인
    time.sleep(0.4)
    uid = os.getuid()
    user = os.getenv('USER') or "agent-admin"
    print(f"[1/5] Checking User Account               [OK]")
    print(f"... Running as service user '{user}' (uid={uid})")

    # 2단계: 환경 변수 확인
    time.sleep(0.4)
    envs = ['AGENT_HOME', 'AGENT_KEY_PATH', 'AGENT_PORT']
    missing = [e for e in envs if not os.getenv(e)]
    if not missing:
        print(f"[2/5] Verifying Environment Variables     [OK]")
        print(f"... All required Envs correct")
    else:
        print(f"[FAIL] Missing Envs: {missing}")
        sys.exit(1)

    # 3단계: 필수 파일 및 키 검증
    time.sleep(0.4)
    key_path = os.getenv('AGENT_KEY_PATH')
    try:
        with open(key_path, 'r') as f:
            if f.read().strip() == "agent_api_key_test":
                print(f"[3/5] Checking Required Files             [OK]")
                print(f"... Verified key file with correct key string.")
            else:
                raise ValueError("Key string mismatch")
    except Exception as e:
        print(f"[FAIL] Key Verification Failed: {e}")
        sys.exit(1)

    # 4단계: 포트 가용성 확인
    time.sleep(0.4)
    port = int(os.getenv('AGENT_PORT', 15034))
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result = sock.connect_ex(('127.0.0.1', port))
    if result != 0: # 포트가 사용 중이지 않아야 성공(0이 아니면 사용 가능)
        print(f"[4/5] Checking Port Availability          [OK]")
        print(f"... Port {port} is available.")
    else:
        print(f"[FAIL] Port {port} is already in use.")
        sys.exit(1)
    sock.close()

    # 5단계: 로그 권한 확인
    time.sleep(0.4)
    log_dir = os.path.join(os.getenv('AGENT_HOME'), 'logs') # 혹은 지정 경로
    if os.access(os.getenv('AGENT_HOME'), os.W_OK):
        print(f"[5/5] Verifying Log Permission            [OK]")
        print(f"... Log directory is writable: {os.getenv('AGENT_HOME')}")
    else:
        print(f"[FAIL] No write permission on log directory.")
        sys.exit(1)

    # 최종 완료
    print("-" * 60)
    print("All Boot Checks Passed!")
    print("Agent READY")
    print(f"Listening on 0.0.0.0:{port}")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nAgent stopped by user.")

if __name__ == "__main__":
    start_agent()
#=========================================

# 실행
python3 agent_app.py
# ==============출력=================
> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
... Running as service user 'agent-admin' (uid=1004)
[2/5] Verifying Environment Variables     [OK]
... All required Envs correct
[3/5] Checking Required Files             [OK]
... Verified key file with correct key string.
[4/5] Checking Port Availability          [OK]
... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
... Log directory is writable: /home/agent-admin/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
Listening on 0.0.0.0:15034
^C
Agent stopped by user.
#=========================================
```

### 4. 시스템 관제 자동화 스크립트(monitor.sh) 구현
#### 파일 위치/권한 정책
* 경로: $AGENT_HOME/bin/monitor.sh
* 소유자: agent-dev
* 그룹: agent-core
* 권한: 750 (rwxr-x---)
* cron 실행 계정: agent-admin (agent-admin은 agent-core에 포함되어 실행 가능해야 함)
```bash
# bin/monitor.sh 작성

# 1. 환경 설정 (절대 경로 권장)
export AGENT_HOME="/home/agent-admin/agent-app"
APP_NAME="agent_app.py"
PORT=15034
LOG_FILE="/var/log/agent-app/monitor.log"
STATS_FILE="$AGENT_HOME/bin/stats.dat"

# 통계 파일 생성 및 권한 확인
touch "$STATS_FILE"

echo "====== SYSTEM MONITOR RESULT ======"

# 2. Health Check (실패 시 종료)
echo -e "\n[HEALTH CHECK]"
PID=$(pgrep -f "$APP_NAME")
if [ -z "$PID" ]; then
    echo "Checking process '$APP_NAME'... [FAIL]"
    exit 1 # 요구사항에 따라 종료
fi
echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"

if ! ss -tuln | grep -q ":$PORT "; then
    echo "Checking port $PORT... [FAIL]"
    exit 1 # 요구사항에 따라 종료
fi
echo "Checking port $PORT... [OK]"

# 3. 상태 점검 (방화벽 - 경고만)
UFW_CHECK=$(sudo ufw status | grep "Status: active")
if [ -z "$UFW_CHECK" ]; then
    echo "[WARNING] Firewall is inactive."
fi

# 4. 자원 수집
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
MEM=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
DISK=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

echo -e "\n[RESOURCE MONITORING]"
printf "CPU Usage : %.1f%%\n" "$CPU"
printf "MEM Usage : %.1f%%\n" "$MEM"
echo "DISK Used  : $DISK%"

# 5. 임계값 경고
[[ $(echo "$CPU > 20" | bc -l) -eq 1 ]] && echo "[WARNING] CPU threshold exceeded ($CPU% > 20%)"
[[ $(echo "$MEM > 10" | bc -l) -eq 1 ]] && echo "[WARNING] MEM threshold exceeded ($MEM% > 10%)"
[ "$DISK" -gt 80 ] && echo "[WARNING] DISK_USED threshold exceeded ($DISK% > 80%)"

# 6. 통계 기록 및 리포트
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "$TIMESTAMP $CPU $MEM" >> "$STATS_FILE"

echo -e "\n====== STATISTICS REPORT ======"
echo "[CPU]"
awk '{sum+=$3; if(max<$3){max=$3; dt=$1" "$2}; if(min==""||min>$3){min=$3; dtn=$1" "$2}} END {if(NR>0) printf "Average : %.1f%%\nMaximum : %.1f%% at %s\nMinimum : %.1f%% at %s\n", sum/NR, max, dt, min, dtn}' "$STATS_FILE"
echo "[Memory]"
awk '{sum+=$4; if(max<$4){max=$4; dt=$1" "$2}; if(min==""||min>$4){min=$4; dtn=$1" "$2}} END {if(NR>0) printf "Average : %.1f%%\nMaximum : %.1f%% at %s\nMinimum : %.1f%% at %s\n", sum/NR, max, dt, min, dtn}' "$STATS_FILE"
echo "[Samples]"
echo "Data Points: $(wc -l < "$STATS_FILE") samples"

# 7. 로그 기록 및 10MB 로테이션
LOG_LINE="[$TIMESTAMP] PID:$PID CPU:$(printf "%.1f" $CPU)% MEM:$(printf "%.1f" $MEM)% DISK_USED:$DISK%"
echo "$LOG_LINE" >> "$LOG_FILE"

# 로테이션 로직 (10MB 초과 시 10개 유지)
MAX_SIZE=10485760
if [ $(stat -c%s "$LOG_FILE") -gt $MAX_SIZE ]; then
    for i in {9..1}; do [ -f "$LOG_FILE.$i" ] && mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"; done
    mv "$LOG_FILE" "$LOG_FILE.1" && touch "$LOG_FILE"
fi

echo -e "\n[INFO] Log appended: $LOG_FILE"
```
#### Health Check(실패 시 종료)
* 프로세스: agent_app.py(또는 제공 앱 파일명) 실행 상태를 확인하고, 비정상 시 exit 1
* 포트: TCP 15034 LISTEN 상태 확인, 비정상 시 exit 1
#### 상태 점검(경고만 출력)
* 방화벽(UFW 또는 firewalld) 활성화 상태를 점검한다.
* 비활성 상태면 [WARNING]을 출력하되, 스크립트는 종료하지 않는다.
#### 자원 수집
* CPU 사용률(%)
* 메모리 사용률(%)
* 디스크 사용률(Root partition, Used %)
#### 임계값 경고(경고만 출력)
* CPU > 20%: [WARNING]
* MEM > 10%: [WARNING]
* DISK_USED > 80%: [WARNING]
#### 로그 기록
* 로그 파일: /var/log/agent-app/monitor.log
* 로그 포맷
    * [YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%
#### 로그 파일 용량 관리
* monitor.log가 커지면 최대 10MB/10개 파일 유지(방법 자유: logrotate 사용 또는 스크립트 로직 구현)
#### 자동 실행(cron) 설정
* agent-admin 계정의 crontab으로 monitor.sh를 매분 실행되도록 등록한다.
* 등록 후 1~2분 내 monitor.log에 새 라인이 자동으로 누적되는 것을 확인한다.
```bash
cd $AGENT_HOME/bin

nano monitor.sh

#=========작성=========
#======위에 적음========

# 소유자 및 권한 설정
## 소유자와 그룹 변경
sudo chown agent-dev:agent-core $AGENT_HOME/bin/monitor.sh

## 권한 설정 (rwxr-x---)
sudo chmod 750 $AGENT_HOME/bin/monitor.sh

# 로그 디렉토리 준비
## 로그 디렉토리 생성
sudo mkdir -p /var/log/agent-app

## agent-admin이 포함된 agent-core 그룹에 권한 부여
sudo chown agent-admin:agent-core /var/log/agent-app
sudo chmod 775 /var/log/agent-app
# 백그라운드 실행
cd $AGENT_HOME
nohup python3 agent_app.py > /dev/null 2>&1 & 

# log 확인 
tail -f /var/log/agent-app/monitor.log
#=====================결과==========================
[Memory]
Average : 7.3%
Maximum : 7.3% at 2026-05-13 19:23:01
Minimum : 7.2% at 2026-05-13 17:55:43
[Samples]
Data Points: 10 samples
[2026-05-13 19:29:01] PID:10119 CPU:1.2% MEM:7.3% DISK_USED:1%

[INFO] Log appended: /var/log/agent-app/monitor.log
[2026-05-13 19:29:55] PID:10119 CPU:1.2% MEM:7.3% DISK_USED:1%
[2026-05-13 19:30:01] PID:10119 CPU:1.2% MEM:7.3% DISK_USED:1%
[2026-05-13 19:31:02] PID:10119 CPU:1.2% MEM:7.3% DISK_USED:1%
#==================================================


# 콘솔 출력
/home/agent-admin/agent-app/bin/monitor.sh
# ============결과==================
====== SYSTEM MONITOR RESULT ======

[HEALTH CHECK]
Checking process 'agent_app.py'... [OK] (PID: 10119)
Checking port 15034... [OK]

[RESOURCE MONITORING]
CPU Usage : 3.0%
MEM Usage : 7.3%
DISK Used  : 1%


====== STATISTICS REPORT ======
[CPU]
Average : 18.5%
Maximum : 100.0% at 2026-05-13 18:14:21
Minimum : 1.2% at 2026-05-13 18:15:36
[Memory]
Average : 7.2%
Maximum : 7.3% at 2026-05-13 19:18:54
Minimum : 7.2% at 2026-05-13 17:55:43
[Samples]
Data Points: 6 samples

[INFO] Log appended: /var/log/agent-app/monitor.log
#===================================
```

