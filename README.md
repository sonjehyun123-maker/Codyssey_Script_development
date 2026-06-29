# 시스템 관제 자동화 스크립트 개발

# 0. 개발 환경 및 프로젝트 목표

## 개발 환경

| 항목 | 내용 |
|------|------|
| Host OS | macOS |
| Virtualization | OrbStack |
| Guest OS | Ubuntu Linux |
| Shell | Bash |
| Language | Python 3 |

---

## 프로젝트 목표

1. OrbStack 환경에서 Ubuntu 서버 구축
2. SSH 및 UFW를 이용한 기본 보안 설정
3. RBAC 기반 사용자/그룹 권한 관리
4. ACL과 setgid를 이용한 협업 환경 구성
5. 환경 변수 및 애플리케이션 실행 환경 구성
6. 프로세스 및 포트 상태 모니터링 자동화
7. CPU, Memory, Disk 사용량 수집
8. 로그 생성 및 로그 로테이션 구현
9. Cron 기반 주기적 모니터링 자동화
10. 장애 발생 시 원인 추적이 가능한 운영 환경 구축


---

# 1. 디렉토리 구조

```text
/home/agent-admin/agent-app/               # AGENT_HOME
├── bin/                                  # 실행 스크립트 저장
│   ├── monitor.sh                        # 시스템 관제 스크립트
│   └── stats.dat                         # CPU/MEM 통계 데이터
│
├── api_keys/                             # API Key 저장
│   └── t_secret.key
│
├── upload_files/                         # 사용자 공유 공간
│
├── agent_app.py                          # 메인 애플리케이션
│
└── .env                                  # 환경 변수 파일

/var/log/agent-app/                       # 로그 저장소
├── monitor.log                           # 현재 로그
├── monitor.log.1                         # 이전 로그
├── monitor.log.2
├── ...
└── monitor.log.10                        # 가장 오래된 로그
```

---

# 2. 보안 설정

## SSH 설정

```bash
sudo nano /etc/ssh/sshd_config

Port 20022
PermitRootLogin no

sudo systemctl restart ssh
sudo systemctl status ssh
ss -tulnp | grep ssh
```

### 적용 이유

- 기본 포트(22) 스캐닝 감소
- Root 계정 직접 로그인 차단
- 불필요한 외부 노출 최소화

---

## UFW 설정

```bash
sudo apt install ufw -y

sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp

sudo ufw enable
sudo ufw status verbose
```

### 정책

| 방향 | 정책 |
|------|------|
| 외부 → 서버 | 기본 차단 |
| 서버 → 외부 | 허용 |

허용 포트:

- 20022/tcp (SSH)
- 15034/tcp (Application)

---

# 3. 사용자 및 권한 관리

## 그룹 구조

| 그룹 | 사용자 | 역할 |
|------|--------|------|
| agent-common | agent-admin<br>agent-dev<br>agent-test | 협업 공간 |
| agent-core | agent-admin<br>agent-dev | 핵심 운영 및 보안 |

---

## 사용자 생성

```bash
sudo groupadd agent-common
sudo groupadd agent-core

sudo useradd -m -g agent-common -G agent-core agent-admin
sudo useradd -m -g agent-common -G agent-core agent-dev
sudo useradd -m -g agent-common agent-test
```

---

## 디렉토리 생성

```bash
sudo mkdir -p /home/agent-admin/agent-app/{upload_files,api_keys,bin}
sudo mkdir -p /var/log/agent-app
```

---

## 권한 설정

```bash
sudo chown -R agent-admin:agent-common \
/home/agent-admin/agent-app/upload_files

sudo chown -R agent-admin:agent-core \
/home/agent-admin/agent-app/api_keys

sudo chown -R agent-admin:agent-core \
/var/log/agent-app

sudo chmod 2770 \
/home/agent-admin/agent-app/upload_files

sudo chmod 2770 \
/home/agent-admin/agent-app/api_keys

sudo chmod 2770 \
/var/log/agent-app

sudo chmod 750 \
/home/agent-admin/agent-app
```

---

## ACL 설정

```bash
sudo apt install acl -y

sudo setfacl -m u:agent-test:rwx \
/home/agent-admin/agent-app/upload_files

sudo setfacl -m u:agent-test:--- \
/home/agent-admin/agent-app/api_keys
```

---

## 적용 목적

### 최소 권한 원칙

- 테스트 계정의 운영 데이터 접근 차단
- API Key 보호
- 운영 로그 보호

### setgid

```text
새로운 파일과 디렉토리가 부모 그룹을 자동 상속하도록 설정한다.
협업 과정에서 그룹 권한 불일치를 방지할 수 있다.
```

---

# 4. 실행 환경 구성

## 환경 변수

```bash
export AGENT_HOME="/home/agent-admin/agent-app"
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys/t_secret.key"
export AGENT_LOG_DIR="/var/log/agent-app"
```

---

## API Key 생성

```bash
echo "agent_api_key_test" > $AGENT_KEY_PATH
```

---

## 애플리케이션 실행

```bash
cd $AGENT_HOME
python3 agent_app.py &
```

---

## LISTEN 확인

```bash
ss -tulnp | grep 15034
```

예시:

```text
tcp LISTEN 0 128 0.0.0.0:15034 0.0.0.0:* users:(("python3",pid=1234))
```

---

# 5. 시스템 관제 자동화

## Health Check

### 프로세스 확인

```bash
PID=$(pgrep -fo "agent_app.py")
```

프로세스가 존재하지 않으면:

```bash
exit 1
```

---

### 포트 확인

```bash
ss -tuln | grep LISTEN | grep -q ":15034 "
```

LISTEN 상태가 아니면:

```bash
exit 1
```

---

## 시스템 자원 수집

### CPU

```bash
CPU=$(top -bn2 -d 0.5 \
| awk '/Cpu\(s\):/ {print 100 - $8}' \
| tail -n 1)
```

사용률:

```text
100 - Idle(%)
```

---

### Memory

```bash
MEM=$(free \
| grep Mem \
| awk '{print $3/$2 * 100.0}')
```

사용률:

```text
사용 메모리 / 전체 메모리
```

---

### Disk

```bash
DISK=$(df -Ph / \
| tail -1 \
| awk '{print $5}' \
| sed 's/%//')
```

---

# 6. 로그 관리

## 로그 기록

```bash
echo "$LOG_LINE" >> "$LOG_FILE"
```

로그는 시간순으로 누적 저장한다.

---

## 로그 포맷

```text
[2026-06-29 12:00:00]
PID:1234
CPU:3.0%
MEM:7.2%
DISK_USED:1%
```

시간 기준 장애 추적 및 자동 분석을 쉽게 하기 위한 구조이다.

---

# 7. 로그 로테이션

## 정책

- monitor.log : 현재 로그
- monitor.log.1 ~ .10 : 이전 로그
- 최대 10개 유지

---

## 동작 순서

```text
1. monitor.log 크기 확인
2. 10MB 초과 여부 확인
3. monitor.log.10 삭제
4. .9 → .10
5. .8 → .9
6. ...
7. .1 → .2
8. monitor.log → monitor.log.1
9. 새로운 monitor.log 생성
```

---

## 로테이션 코드

```bash
if [ $(stat -c%s "$LOG_FILE") -gt $MAX_SIZE ]; then
    [ -f "$LOG_FILE.10" ] && rm -f "$LOG_FILE.10"

    for i in {9..1}; do
        [ -f "$LOG_FILE.$i" ] &&
        mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
    done

    mv "$LOG_FILE" "$LOG_FILE.1"

    touch "$LOG_FILE"
    chown agent-admin:agent-core "$LOG_FILE"
    chmod 660 "$LOG_FILE"
fi
```

---

# 8. Cron 자동 실행

```bash
crontab -e
```

```cron
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1
```

---

## Cron 표현식

```text
* * * * *
│ │ │ │ │
│ │ │ │ └── 요일 (0~7)
│ │ │ └──── 월 (1~12)
│ │ └────── 일 (1~31)
│ └──────── 시 (0~23)
└────────── 분 (0~59)
```

현재 설정:

```text
매분 monitor.sh 실행
```

---

# 9. 장애 대응 정책

## Hard Failure

즉시 종료:

- 프로세스 없음
- 포트 미오픈

```bash
exit 1
```

---

## Soft Warning

서비스는 계속 동작:

- CPU 임계치 초과
- Memory 임계치 초과
- Disk 임계치 초과
- Firewall 비활성화

```text
[WARNING]
```

---

# 10. 장애 분석 순서

```text
1. ss -tulnp
2. Application Log
3. ps / pgrep
4. journalctl
5. UFW 상태
```

---

