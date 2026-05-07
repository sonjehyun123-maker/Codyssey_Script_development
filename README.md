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

#### 디렉토리 구조 및 권한(ACL 포함) 확인 내역

#### 앱 Boot Sequence 5단계 [OK] 및 “Agent READY” 확인 내역

#### monitor.sh 실행 결과(프로세스/포트/리소스/경고) 내역

#### /var/log/agent-app/monitor.log 누적 기록 확인(최근 라인) 내역

#### crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역
---