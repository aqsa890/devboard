# DevBoard Production DevSecOps CI/CD Pipeline

This repository is configured with a 15-stage DevSecOps pipeline designed for production delivery. It combines automated code linting, security scanning, static analysis (SonarQube), dynamic vulnerability assessment (OWASP ZAP), SBOM generation, container scanning, integration testing, and automated deployment to AWS EC2 staging and production environments using self-hosted runners.

---

## 🏗️ Pipeline Architecture

```
PR / Push
   │
   ├── Job 1: Secret Scan (Gitleaks)
   ├── Job 2: Lint (Go Vet + ESLint)
   ├── Job 3: SAST (SonarQube)
   ├── Job 4: Dependency/SCA (Trivy FS Scan)
   ├── Job 5: IaC Security (Trivy Config Scan)
   │
   └──────────────┐
                  ↓
          Security Gate 1
                  │
                  ↓
          Job 6: Unit Tests (Go + Vitest)
                  │
                  ↓
          Job 7: Build (Docker Container Build)
                  │
                  ↓
          Job 8: Generate SBOM (Syft / Trivy SPDX)
                  │
                  ↓
          Job 9: Container Scan (Trivy Image Scan)
                  │
                  ↓
          Job 10: Integration Tests (Docker Compose Stack Verification)
                  │
                  ↓
          Job 11: Deploy Test (Ephemeral Environment)
                  │
                  ↓
          Job 12: DAST / ZAP (OWASP ZAP Dynamic Vulnerability Assessment)
                  │
                  ↓
          Final Security Gate
                  │
                  ↓
          Job 13: Build Release (Tag & Push Release Containers to Registry)
                  │
                  ↓
          Job 14: Deploy Staging (Deploy to Staging AWS EC2 Instance)
                  │
                  ↓
          Approval (GitHub Environment Production Gate)
                  │
                  ↓
          Job 15: Deploy Production (Deploy to Production AWS EC2 Instance)
```

---

## 🛠️ Step-by-Step Configuration Guide

### 1. Setting Up the Self-Hosted Runner on AWS EC2

1. Launch an AWS EC2 instance (Ubuntu 22.04 / 24.04 LTS recommended, `t3.medium` or larger).
2. Install Docker & Docker Compose on the EC2 instance:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose-v2
   sudo usermod -aG docker ubuntu
   ```
3. In GitHub, navigate to **Settings -> Actions -> Runners -> New self-hosted runner**.
4. Download and configure the runner package on the EC2 host:
   ```bash
   mkdir actions-runner && cd actions-runner
   curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.320.0/actions-runner-linux-x64-2.320.0.tar.gz
   tar xzf ./actions-runner-linux-x64.tar.gz
   ./config.sh --url https://github.com/<your-org>/devboard --token <YOUR_RUNNER_TOKEN>
   sudo ./svc.sh install
   sudo ./svc.sh start
   ```

---

### 2. SonarQube Setup

1. **Deploy SonarQube via Docker** (on an EC2 server or dedicated host):
   ```bash
   docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
   ```
2. Access `http://<sonarqube-ip>:9000` (default login: `admin`/`admin`).
3. Navigate to **Account -> Security -> Tokens** and generate a token for `devboard`.
4. Add secrets in GitHub:
   - `SONAR_HOST_URL`: `http://<sonarqube-ip>:9000`
   - `SONAR_TOKEN`: `<your-sonarqube-token>`

---

### 3. OWASP ZAP (DAST) Configuration

- The pipeline utilizes `zaproxy/action-baseline` to perform baseline security scanning against the running test instance at `http://localhost:8080`.
- Scanning rules are defined in `.zap/zap-baseline.conf`.
- Rule severities (e.g. `IGNORE`, `WARN`, `FAIL`) can be adjusted in `.zap/zap-baseline.conf`.

---

### 4. GitHub Environment Approval Gate (Production)

To ensure manual authorization before Job 15 executes:
1. In your GitHub repository, go to **Settings -> Environments**.
2. Create an environment named `production`.
3. Enable **Required reviewers** and assign authorized deployment approvers.
4. (Optional) Create an environment named `staging` for environment-specific secrets.

---

### 5. Required Repository Secrets Summary

Add the following under **Settings -> Secrets and variables -> Actions**:

| Secret Name | Description | Example / Note |
|---|---|---|
| `SONAR_HOST_URL` | SonarQube server URL | `http://1.2.3.4:9000` |
| `SONAR_TOKEN` | SonarQube user/project token | `sqp_123456789...` |
| `DOCKER_USERNAME` | Docker Hub username | `myuser` |
| `DOCKER_PASSWORD` | Docker Hub access token | `dckr_pat_...` |
| `EC2_SSH_KEY` | Private SSH key for EC2 deployment | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `EC2_STAGING_HOST` | Staging EC2 IP / Hostname | `54.210.xx.xx` |
| `EC2_PRODUCTION_HOST` | Production EC2 IP / Hostname | `54.211.xx.xx` |
| `EC2_USER` | SSH Username on EC2 | `ubuntu` |

---

## 🧪 Local Verification

You can verify the integration test locally by running:
```bash
./scripts/integration_test.sh
```

This will automatically build the backend, frontend, and PostgreSQL containers, execute API checks, and verify service health.
