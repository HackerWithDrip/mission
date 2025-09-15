## NGINX React Hello – OpenShift CI/CD Mission

Production-ready, minimal static site served by NGINX and deployed to OpenShift with GitHub Actions. Verification is done via Ansible.

### Project Overview
- App type: Static HTML (mission-compliant) served by NGINX
- Container: `nginx:1.25-alpine` with hardened permissions for OpenShift random UID
- Platform: OpenShift (Route + Service + Deployment)
- CI/CD: GitHub Actions builds, tags, pushes, and deploys
- Verification: Ansible playbooks hit Route and check content/health

### Repository Structure
```
.
├─ ansible/
│  ├─ fetch-endpoint.yml           # Fetch and log content + health
│  ├─ hosts                        # Inventory with route host
│  └─ verify-endpoint.yml          # Pipeline verification (optional)
├─ k8s/
│  ├─ deployment.yaml              # Deployment (2 replicas, 8080)
│  ├─ route.yaml                   # Exposes service externally
│  └─ service.yaml                 # ClusterIP on 8080
├─ .github/workflows/ci-cd.yml     # CI/CD pipeline (unique tags)
├─ default.conf                    # NGINX server config (8080, /health)
├─ nginx.conf                      # Base nginx config
├─ public/index.html               # Mission message (static)
├─ Dockerfile                      # Minimal, copies static HTML
├─ package.json                    # Present from earlier React scaffold
└─ src/                            # Present from earlier React scaffold
```

### Prerequisites
- Docker (login to Docker Hub)
- OpenShift CLI (`oc`) logged in and project selected
- GitHub repository with Actions enabled

### OpenShift Resources
- Service: `nginx-react-hello-svc` (TCP 8080)
- Route: `nginx-react-hello-route` (edge TLS)
- Deployment: `nginx-react-hello` (2 replicas)

### Health Endpoint
- Path: `/health`
- Returns: `healthy\n`

### Build, Tag, Push (Local)
Use a unique image tag to avoid caching (commit hash + timestamp):
```bash
COMMIT_HASH=$(git rev-parse --short HEAD)
TS=$(date +%Y%m%d-%H%M%S)
IMAGE=lionelraseemela/nginx-react-hello:${COMMIT_HASH}-${TS}

docker build -t "$IMAGE" .
docker run --rm "$IMAGE" cat /usr/share/nginx/html/index.html  # quick check
docker push "$IMAGE"
```

Optionally also push `:latest`:
```bash
docker tag "$IMAGE" lionelraseemela/nginx-react-hello:latest
docker push lionelraseemela/nginx-react-hello:latest
```

### Deploy/Update on OpenShift (Manual)
```bash
# Make sure the k8s resources exist (first-time only)
oc apply -f k8s/service.yaml
oc apply -f k8s/route.yaml
oc apply -f k8s/deployment.yaml

# Roll out a new image
oc set image deployment/nginx-react-hello \
  nginx=$IMAGE
oc rollout status deployment/nginx-react-hello
```

### GitHub Actions – CI/CD
Workflow: `.github/workflows/ci-cd.yml`

On push to `main`/`master`:
- Build image with unique tag `${COMMIT_HASH}-${TIMESTAMP}`
- Push unique tag and `latest`
- `oc login` and set image on the deployment to the unique tag
- Wait for rollout
- Optionally verify via Ansible

Set repository Secrets (Settings → Secrets and variables → Actions):
- `DOCKER_USERNAME` – Docker Hub username
- `DOCKER_PASSWORD` – Docker Hub access token/password
- `OPENSHIFT_SERVER` – e.g. `https://api.rm1.0a51.p1.openshiftapps.com:6443`
- `OPENSHIFT_TOKEN` – `oc whoami -t`
- `OPENSHIFT_PROJECT` – your OpenShift project/namespace

### Ansible – Fetch/Verify Endpoint
Inventory (`ansible/hosts`):
```
[openshift_apps]
nginx-app ansible_host=<route-hostname> ansible_connection=local
```

Fetch content and health:
```bash
cd ansible
ansible-playbook -i hosts fetch-endpoint.yml
```

Optional verify play (used in CI):
```bash
ansible-playbook ansible/verify-endpoint.yml -e target_url=https://<route-hostname>
```

### Local Development Tips
- Edit `public/index.html` to update the message (simple static mission approach)
- Build and push with a unique tag to guarantee rollout picks the new image
- The Deployment sets `imagePullPolicy: Always`

### Troubleshooting
- Pods CrashLoopBackOff with nginx permission errors:
  - Ensure Dockerfile sets group-writable perms on `/var/cache/nginx`, `/var/run`, `/etc/nginx`, `/usr/share/nginx/html`
  - Container runs as non-root (OpenShift random UID). Avoid writing to root-owned paths.
- Route returns default “Application Not Available” page:
  - Check Service selector matches Pod labels (`app: nginx-react-hello`)
  - Confirm Service port 8080 and Route `targetPort: 8080`
  - `oc get endpoints nginx-react-hello-svc` should list Pod IPs
- Changes not reflected after deploy:
  - Use unique image tags (as implemented). Confirm with `oc describe deployment` image field
  - `oc rollout restart deployment/nginx-react-hello` if needed
- Authentication in CI fails:
  - Refresh `OPENSHIFT_TOKEN` and validate `OPENSHIFT_SERVER` has no stray characters

### Security Notes
- `allowPrivilegeEscalation: false`, `capabilities: drop: [ALL]`, run as non-root
- No shell access required; use `oc exec` for diagnostics

### License
For assessment/mission purposes. by Lionel Raseemela


