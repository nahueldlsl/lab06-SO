# INFORME — Laboratorio 06
## DevOps Moderno con GitHub Actions y Azure DevOps

**Alumno:** Nahuel De Los Santos  
**Email:** nahueldelossanto@gmail.com  
**Fecha:** 21 de mayo de 2026  
**Repositorio:** https://github.com/nahueldlsl/lab06-so

---

## 1. Introducción

Este laboratorio implementa un flujo DevOps completo que automatiza el ciclo de integración y entrega continua (CI/CD) para dos aplicaciones dummy, empaquetadas como contenedores Docker y desplegadas automáticamente en un servidor Linux propio mediante SSH y Docker Compose.

### ¿Qué es DevOps?

DevOps es una cultura y conjunto de prácticas que integra los equipos de desarrollo (Dev) y operaciones (Ops) para acortar el ciclo de vida del software. Se apoya en automatización, monitoreo continuo y colaboración para entregar software de mayor calidad con mayor frecuencia.

### CI vs CD

| Concepto | Significado | En este lab |
|---|---|---|
| **CI** (Integración Continua) | Validar, testear y construir automáticamente en cada push | Lint + pytest + `docker build` + push a ghcr.io |
| **CD** (Entrega Continua) | Desplegar automáticamente el artefacto probado | SSH → `docker compose pull` + `up -d` + smoke tests |

### ¿Qué es un pipeline?

Un pipeline es una cadena automatizada de pasos que transforma código fuente en software funcionando en producción. Cada paso depende del anterior; si uno falla, el pipeline se detiene antes de llegar a producción.

### ¿Qué es un contenedor Docker?

Un contenedor es una unidad estándar de software que empaqueta la aplicación junto a todas sus dependencias, garantizando que se ejecute de manera idéntica en cualquier entorno: laptop del desarrollador, runner de CI o servidor de producción.

### ¿Qué es un artifact?

En CI/CD, un artefacto es el resultado construido de un pipeline que se versiona y distribuye. En este lab, los artefactos son las imágenes Docker publicadas en ghcr.io con tags `latest` y el SHA del commit.

### ¿Qué es un secreto o variable segura?

Un secreto es un valor sensible (clave SSH, token) almacenado cifrado en la plataforma CI/CD y referenciado como `${{ secrets.NOMBRE }}` en el pipeline, sin exponerse en los logs.

---

## 2. Desarrollo

### 2.1 Estructura del Repositorio

```
lab06-so/
├── app/
│   ├── dummy-a/
│   │   ├── Dockerfile
│   │   ├── index.html
│   │   └── nginx.conf
│   └── dummy-b/
│       ├── Dockerfile
│       ├── .dockerignore
│       ├── app.py
│       ├── requirements.txt
│       └── tests/
│           └── test_app.py
├── scripts/
│   └── deploy.sh
├── docker-compose.yml
├── pipeline/
│   ├── azure-pipelines-ci.yml
│   └── azure-pipelines-cd.yml
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── cd.yml
├── INFORME.md
└── README.md
```

### 2.2 Aplicación Dummy A — Sitio Estático

Página HTML que muestra "Hola Mundo DevOps", servida por NGINX dentro de un contenedor Docker en el puerto 80.

**Dockerfile:**
```
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

La imagen base `nginx:alpine` es minimal (~7 MB). No requiere ningún proceso de instalación en el servidor.

### 2.3 Aplicación Dummy B — API Flask

API mínima en Python/Flask expuesta en el puerto 8080.

| Endpoint | Respuesta |
|---|---|
| `GET /` | HTML de bienvenida |
| `GET /health` | `{"status": "ok", "service": "dummy-b", "version": "1.0.0"}` — HTTP 200 |

**Dockerfile:**
```
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
CMD ["python", "app.py"]
```

El `.dockerignore` excluye `tests/` de la imagen de producción para reducir el tamaño.

**Tests automáticos (pytest):**
- `test_health_returns_200` — código HTTP correcto
- `test_health_returns_json` — body con `"status": "ok"`
- `test_index_returns_200` — raíz responde

### 2.4 Docker Compose en el servidor

`docker-compose.yml` orquesta ambos servicios en el servidor:

```yaml
services:
  dummy-a:
    image: ghcr.io/nahueldlsl/lab06-so-dummy-a:latest
    ports: ["80:80"]
    restart: unless-stopped
  dummy-b:
    image: ghcr.io/nahueldlsl/lab06-so-dummy-b:latest
    ports: ["8080:8080"]
    restart: unless-stopped
```

`restart: unless-stopped` garantiza que los contenedores se relancen automáticamente si el servidor se reinicia.

### 2.5 Pipeline CI (GitHub Actions)

Archivo: `.github/workflows/ci.yml`  
Trigger: `push` y `pull_request` a `main`.

```
push
 │
 ├─ Job: test            (siempre, incluido en PRs)
 │    ├─ flake8 (lint)
 │    └─ pytest
 │
 └─ Job: build-push      (solo en push a main)
      ├─ docker login ghcr.io
      ├─ docker build & push dummy-a (:latest + :SHA)
      └─ docker build & push dummy-b (:latest + :SHA)
```

El `build-push` usa `docker/build-push-action` con **GitHub Actions Cache** para acelerar builds sucesivos.

**Permisos necesarios:**
```yaml
permissions:
  contents: read
  packages: write   # para hacer push a ghcr.io
```

### 2.6 Pipeline CD (GitHub Actions)

Archivo: `.github/workflows/cd.yml`  
Trigger: `workflow_run` cuando el CI completa con éxito en `main`.

Pasos:
1. Configurar clave SSH en el runner.
2. Copiar `docker-compose.yml` y `deploy.sh` al servidor por SCP.
3. Ejecutar `deploy.sh` vía SSH con las variables `GHCR_TOKEN` y `GHCR_USER`.
4. `deploy.sh` hace: login ghcr.io → `docker compose pull` → `docker compose up -d`.
5. Smoke tests externos desde el runner (`curl`).

**Secretos necesarios en GitHub:**

| Secret | Descripción |
|---|---|
| `SSH_HOST` | IP o hostname del servidor |
| `SSH_USER` | Usuario SSH |
| `SSH_KEY` | Clave privada SSH (contenido del `.pem`) |

`GITHUB_TOKEN` es automático — no hace falta configurarlo.

### 2.7 Pipeline Comparativo — Azure DevOps

Los archivos `pipeline/azure-pipelines-ci.yml` y `pipeline/azure-pipelines-cd.yml` replican el mismo flujo en Azure DevOps Pipelines con Docker.

**Diferencias observadas:**

| Aspecto | GitHub Actions | Azure DevOps |
|---|---|---|
| Autenticación ghcr.io | `GITHUB_TOKEN` automático | PAT manual (`GHCR_TOKEN` como variable) |
| Permisos de packages | `permissions: packages: write` | Configurar service connection |
| Cache Docker | `type=gha` (GitHub Actions Cache) | `Cache@2` task separado |
| Test results | Sin tarea nativa | `PublishTestResults@2` integrado |
| Trigger entre pipelines | `workflow_run` | `resources.pipelines` |

### 2.8 Infraestructura del Servidor

| Componente | Configuración |
|---|---|
| Sistema Operativo | Linux (Ubuntu recomendado) |
| Docker | Engine + Compose plugin instalados |
| Puertos abiertos | 22 (SSH), 80 (HTTP), 8080 (API) |
| Acceso | IP pública con clave SSH |

**Preparación única del servidor (se hace una sola vez):**
```bash
# Instalar Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Crear directorio de despliegue
sudo mkdir -p /opt/lab06
sudo chown $USER:$USER /opt/lab06
```

---

## 3. Problemas Encontrados y Soluciones

| Problema | Causa | Solución |
|---|---|---|
| `workflow_run` no dispara el CD | Falta `branches` en el trigger | Agregar `branches: [main]` al `workflow_run` |
| `docker push` denegado en ghcr.io | Falta permiso `packages: write` | Agregar al bloque `permissions` del workflow |
| Contenedor no arranca tras `up -d` | Puerto ya ocupado en el servidor | Verificar con `ss -tlnp` y liberar el puerto |
| Imagen desactualizada en el servidor | `latest` en caché local de Docker | `docker compose pull` fuerza descarga de la nueva imagen |
| `ssh-keyscan` falla silenciosamente | Host no accesible o firewall | Verificar NSG/firewall del servidor antes del deploy |
| `deploy.sh` falla con "GHCR_TOKEN unbound" | Variable no exportada al shell remoto | Pasar como `VAR='...' bash script.sh` en lugar de export |

---

## 4. Conclusiones

1. **Docker + Docker Compose** simplifica drásticamente el despliegue: el servidor no necesita instalaciones manuales de Python, NGINX ni dependencias. Solo necesita Docker.

2. **ghcr.io** integrado con GitHub Actions elimina la necesidad de un registry externo (DockerHub, etc.). El `GITHUB_TOKEN` automático autentica el push sin secretos adicionales.

3. La separación `ci.yml` / `cd.yml` con `workflow_run` garantiza que nunca se despliega código que no pasó tests.

4. **Docker Compose** en el servidor permite agregar más servicios (base de datos, proxy reverso, etc.) editando un solo archivo YAML, sin cambiar el script de deploy.

5. Versionar imágenes con el SHA del commit permite hacer rollback instantáneo: basta cambiar el tag en `docker-compose.yml` y correr `docker compose up -d` de nuevo.

---

## 5. Reflexión Técnica

**1. ¿Qué ventajas ofrece DevOps frente al despliegue manual?**  
Elimina el error humano, garantiza reproducibilidad total (mismo contenedor en dev y producción), reduce el tiempo de entrega y genera un historial auditable de cada build y deploy.

**2. ¿Qué problemas podrían ocurrir sin automatización?**  
"Funciona en mi máquina" — diferencias de entorno entre desarrolladores y servidores. Con Docker esto desaparece: la imagen es el entorno.

**3. ¿Qué parte del pipeline fue más compleja?**  
La integración CI → CD mediante `workflow_run`: asegurarse de que el CD solo corre cuando el CI termina exitosamente *en la rama correcta* requirió entender bien el evento.

**4. ¿Qué mejorarían en un ambiente empresarial real?**  
Ambiente de staging previo a producción, aprobaciones manuales, healthchecks en Docker Compose, notificaciones por Slack/Teams y rollback automático si el smoke test falla.

**5. ¿Qué riesgos de seguridad identificaron?**  
- Clave SSH expuesta si se loguea en el pipeline.
- Puerto 22 abierto al mundo (mitigar con allowlist de IPs en firewall).
- Imagen base desactualizada con CVEs (usar Dependabot o `docker scout`).
- `restart: unless-stopped` puede reiniciar un contenedor con configuración rota en un loop.

**6. ¿Cómo escalarían esta solución?**  
Reemplazando Docker Compose por Kubernetes (o Azure Container Apps), usando un registry privado, implementando blue-green deployments con un load balancer, y separando la infraestructura con Terraform.

---

## 6. URL Pública del Servicio

- **Dummy A (sitio estático):** `http://<SSH_HOST>/`
- **Dummy B (API health):** `http://<SSH_HOST>:8080/health`
