# Codyssey_Script_development

## 시스템 관제 자동화 스크립트 개발

### 체크리스트

#### SSH 포트 변경(20022) 및 Root 원격 접속 차단 설정 확인 내역
* SSH란?: 네트워크 상의 다른 컴퓨터에 로그인하거나 원격으로 명령을 실행할 수 있게 해주는 보안 네트워크 프로토콜입니다.
```bash
# 1. 설정 파일 수정 (Port 20022 변경 및 Root 로그인 차단)
sudo nano /etc/ssh/sshd_config
# 수정 내용: Port 20022 / PermitRootLogin no

# 2. SSH 서비스 시작 및 재구동
sudo /etc/init.d/ssh start
# 출력: Starting ssh (via systemctl): ssh.service.

# 3. 네트워크 상태 확인 (포트 활성화 여부 검증)
ss -tulnp | grep 20022
# 결과:
# tcp   LISTEN 0      4096         0.0.0.0:20022      0.0.0.0:* 
# tcp   LISTEN 0      4096            [::]:20022         [::]:* 
```

#### 방화벽(UFW 또는 firewalld) 활성화 및 20022/tcp, 15034/tcp만 허용 내역
```bash
# 0. UFW 설치
sudo apt install ufw -y

# 1. SSH 포트(20022) 허용
sudo ufw allow 20022/tcp
# Rules updated
# Rules updated (v6)

# 2. 애플리케이션 서비스 포트(15034) 허용
sudo ufw allow 15034/tcp
# Rules updated
# Rules updated (v6)

# 3. 방화벽 활성화 (적용)
sudo ufw enable
# 결과: Firewall is active and enabled on system startup

# 4. 방화벽 설정 상태 확인
sudo ufw status verbose
# 결과: 
# To                         Action      From
# --                         ------      ----
# 20022/tcp                  ALLOW IN    Anywhere                  
# 15034/tcp                  ALLOW IN    Anywhere                  
# 20022/tcp (v6)             ALLOW IN    Anywhere (v6)             
# 15034/tcp (v6)             ALLOW IN    Anywhere (v6)
```

#### 계정/그룹(agent-admin/dev/test, agent-common/core) 생성 확인 내역
```bash
# 1. 그룹 생성 common, core
sudo groupadd common
sudo groupadd core

# 2. 유저 생성 admin, dev, test
sudo useradd -m -g common -g core admin #admin만 그룹 2개
sudo useradd -m -g common dev
sudo useradd -m -g common test

# 3. id 확인
id admin
id dev
id test
# 결과 : 
# admin : uid=1001(admin) gid=1001(common) groups=1001(common),1002(core)
# dev   : uid=1002(dev) gid=1001(common) groups=1001(common)
# test  : uid=1003(test) gid=1001(common) groups=1001(common)

# /etc/group 에서  common, core찾기
grep -E 'common|core' /etc/group
# common:x:1001:
# core:x:1002:admin # 보조그룹
```
#### 디렉토리 구조 및 권한(ACL 포함) 확인 내역
* ACL(Access Control List) : 추가 접근 제어 목록 
```bash
# 1. 디렉토리 구조 생성
sudo mkdir -p /project/common
sudo mkdir -p /project/core

# 2. 기본 소유권 및 그룹 설정
# common 폴더는 common 그룹이, core 폴더는 core 그룹이 관리
sudo chown root:common /project/common
sudo chown root:core /project/core

# 3. 기본 권한 설정 (소유자/그룹은 모든 권한, 나머지는 접근 금지)
sudo chmod 770 /project/common
sudo chmod 770 /project/core

# 4. ACL 설정 (특정 사용자에게 특별 권한 부여)
# test 계정은 common 폴더를 '읽기'만 가능하도록 설정
sudo setfacl -m u:test:r-x /project/common
# dev 계정은 core 폴더에 접근조차 못 하게 명시적으로 차단
sudo setfacl -m u:dev:--- /project/core

ls -ld /project/common /project/core
# 결과 (+ 기호는 일반적인 리눅스 권한 외에 ACL 설정이 적용되어 있음을 의미)
# drwxrwx---+  2 root common 4096 May  8 21:50 /project/common
# drwxrwx---+  2 root core   4096 May  8 21:50 /project/core

getfacl /project/common
getfacl /project/core
# 결과
# getfacl /project/core
# getfacl: Removing leading '/' from absolute path names
# # file: project/common
# # owner: root
# # group: common
# user::rwx
# user:test:r-x
# group::rwx
# mask::rwx  //ACL로 부여할 수 있는 최대 권한 범위
# other::---

# getfacl: Removing leading '/' from absolute path names
# # file: project/core
# # owner: root
# # group: core
# user::rwx
# user:dev:---
# group::rwx
# mask::rwx
# other::---
```
#### 앱 Boot Sequence 5단계 [OK] 및 “Agent READY” 확인 내역

#### monitor.sh 실행 결과(프로세스/포트/리소스/경고) 내역

#### /var/log/agent-app/monitor.log 누적 기록 확인(최근 라인) 내역

#### crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역
---