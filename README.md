# Codyssey_Script_development

## 시스템 관제 자동화 스크립트 개발

---

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

# 2. 기본 정책 설정
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 3. SSH 포트 허용
sudo ufw allow 20022/tcp

# 4. APP 포트 허용
sudo ufw allow 15034/tcp

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
#### 3. 앱 Boot Sequence 5단계 [OK] 및 “Agent READY” 확인 내역

#### monitor.sh 실행 결과(프로세스/포트/리소스/경고) 내역

#### /var/log/agent-app/monitor.log 누적 기록 확인(최근 라인) 내역

#### crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역
---