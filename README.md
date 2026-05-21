# Lab 06 — DevOps Moderno con GitHub Actions y Azure DevOps

Implementación de un pipeline CI/CD completo para dos aplicaciones dummy, desplegadas automáticamente en una VM Ubuntu en Azure.

## Estructura

```
app/dummy-a/      → Sitio estático HTML (NGINX, puerto 80)
app/dummy-b/      → API Flask con /health (Python, puerto 8080)
scripts/          → Script de despliegue remoto SSH
.github/workflows → CI/CD con GitHub Actions
pipeline/         → Pipelines equivalentes en Azure DevOps
INFORME.md        → Informe técnico completo
```

## Flujo CI/CD

```
git push → CI (lint + tests + package) → CD (SCP → deploy.sh → smoke tests)
```

## Secretos requeridos (GitHub Settings → Secrets)

| Secret | Descripción |
|---|---|
| `AZURE_VM_IP` | IP pública de la VM Azure |
| `AZURE_VM_USER` | Usuario SSH (ej. `ubuntu`) |
| `AZURE_VM_SSH_KEY` | Clave privada SSH (contenido del `.pem`) |

## Ejecutar tests localmente

```bash
cd app/dummy-b
pip install -r requirements.txt
python -m pytest tests/ -v
```

Ver [INFORME.md](INFORME.md) para documentación completa.
