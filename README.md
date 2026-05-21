# Lab 06 — DevOps Moderno con GitHub Actions y Azure DevOps

Pipeline CI/CD completo para dos apps dummy, empaquetadas como imágenes Docker y desplegadas automáticamente en un servidor Linux propio vía SSH.

## Estructura

```
app/
  dummy-a/            → Sitio estático HTML (imagen NGINX, puerto 80)
    Dockerfile
    index.html
    nginx.conf
  dummy-b/            → API Flask con /health (imagen Python, puerto 8080)
    Dockerfile
    app.py
    requirements.txt
    tests/
scripts/
  deploy.sh           → Script de despliegue remoto (docker compose pull + up)
docker-compose.yml    → Orquestación en el servidor
.github/workflows/
  ci.yml              → CI: lint + tests + build + push a ghcr.io
  cd.yml              → CD: SSH → docker compose up
pipeline/
  azure-pipelines-ci.yml
  azure-pipelines-cd.yml
INFORME.md
```

## Flujo CI/CD

```
git push → CI (flake8 + pytest + docker build + push ghcr.io)
         → CD (SSH → docker compose pull → up -d → smoke tests)
```

## Secretos requeridos (GitHub Settings → Secrets)

| Secret | Descripción |
|---|---|
| `SSH_HOST` | IP o hostname del servidor |
| `SSH_USER` | Usuario SSH |
| `SSH_KEY` | Clave privada SSH (contenido del `.pem`) |

> `GITHUB_TOKEN` se usa automáticamente para autenticar en ghcr.io — no necesita configuración extra.

## Ejecutar tests localmente

```bash
cd app/dummy-b
pip install -r requirements.txt
python -m pytest tests/ -v
```

## Ejecutar con Docker localmente

```bash
docker compose up --build
# Dummy A: http://localhost
# Dummy B: http://localhost:8080/health
```

Ver [INFORME.md](INFORME.md) para documentación completa.
