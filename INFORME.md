# INFORME — Laboratorio 06
## DevOps Moderno con GitHub Actions y Azure DevOps

**Alumno:** Nahuel De Los Santos  
**Email:** nahueldelossanto@gmail.com  
**Fecha:** 21 de mayo de 2026  
**Repositorio:** https://github.com/nahueldlsl/lab06-so

---

## 1. Introducción

Este laboratorio tiene como objetivo implementar un flujo DevOps completo que automatice el ciclo de integración y entrega continua (CI/CD) para dos aplicaciones dummy, desde el código fuente hasta el despliegue en una VM Ubuntu en Azure.

### ¿Qué es DevOps?

DevOps es una cultura y conjunto de prácticas que integra los equipos de desarrollo (Dev) y operaciones (Ops) para acortar el ciclo de vida del software. Se apoya en automatización, monitoreo continuo y colaboración para entregar software de mayor calidad con mayor frecuencia.

### CI vs CD

| Concepto | Significado | En este lab |
|---|---|---|
| **CI** (Integración Continua) | Validar y construir el código automáticamente en cada push | Job de lint + tests + empaquetado |
| **CD** (Entrega/Despliegue Continuo) | Desplegar automáticamente el artefacto probado | Job SSH → VM → smoke tests |

### ¿Qué es un pipeline?

Un pipeline es una cadena automatizada de pasos (jobs/stages) que transforman código fuente en software funcionando en producción. Cada paso depende del anterior; si uno falla, el pipeline se detiene.

### ¿Qué es Infrastructure as Code?

IaC es la práctica de gestionar infraestructura (servidores, redes, reglas de firewall) mediante archivos de configuración versionados en Git, en lugar de configuración manual. En este lab, el archivo `scripts/deploy.sh` y los workflows YAML son ejemplos de IaC ligero.

### ¿Qué es un secreto o variable segura?

Un secreto es un valor sensible (clave SSH, contraseña, token) almacenado cifrado en la plataforma CI/CD y referenciado como `${{ secrets.NOMBRE }}` en el pipeline, sin exponerse en los logs.

---

## 2. Desarrollo

### 2.1 Estructura del Repositorio

```
lab06-so/
├── app/
│   ├── dummy-a/              # Sitio estático HTML
│   │   ├── index.html
│   │   └── nginx.conf
│   └── dummy-b/              # API Flask
│       ├── app.py
│       ├── requirements.txt
│       └── tests/
│           └── test_app.py
├── scripts/
│   └── deploy.sh             # Script de despliegue remoto
├── pipeline/
│   ├── azure-pipelines-ci.yml
│   └── azure-pipelines-cd.yml
├── .github/
│   └── workflows/
│       ├── ci.yml            # GitHub Actions CI
│       └── cd.yml            # GitHub Actions CD
├── INFORME.md
└── README.md
```

### 2.2 Aplicación Dummy A — Sitio Estático

Página HTML estática que muestra "Hola Mundo DevOps". Se despliega con NGINX en el puerto 80.

**Validación CI:** La herramienta `tidy` verifica la sintaxis HTML antes de empaquetar.

**Despliegue:** Se empaqueta como `.tar.gz`, se copia por SCP al servidor y se extrae en `/var/www/dummy-a`. NGINX sirve el contenido.

### 2.3 Aplicación Dummy B — API Flask

API mínima en Python/Flask con dos endpoints:

| Endpoint | Método | Respuesta |
|---|---|---|
| `/` | GET | Página HTML de bienvenida |
| `/health` | GET | `{"status": "ok", "service": "dummy-b", "version": "1.0.0"}` con HTTP 200 |

**Tests automáticos (`pytest`):**
- `test_health_returns_200` — verifica código HTTP 200
- `test_health_returns_json` — verifica que el body tenga `"status": "ok"`
- `test_index_returns_200` — verifica que la raíz responda

**Despliegue:** Se instala como servicio `systemd` en `/opt/dummy-b`, escucha en el puerto 8080.

### 2.4 Pipeline CI (GitHub Actions)

Archivo: `.github/workflows/ci.yml`

```
push / pull_request
       │
       ├─ Job: lint-dummy-a
       │      ├─ checkout
       │      ├─ tidy (HTML lint)
       │      ├─ tar -czf dummy-a.tar.gz
       │      └─ upload-artifact
       │
       └─ Job: test-dummy-b
              ├─ checkout
              ├─ setup-python 3.12
              ├─ pip install
              ├─ flake8 (lint)
              ├─ pytest (tests)
              ├─ tar -czf dummy-b.tar.gz
              └─ upload-artifact
```

Ambos jobs corren en paralelo sobre `ubuntu-latest`.

### 2.5 Pipeline CD (GitHub Actions)

Archivo: `.github/workflows/cd.yml`

Se activa con `workflow_run` cuando el CI pasa en `main`. Pasos:

1. Descarga artefactos del CI.
2. Instala la clave SSH en el runner.
3. Copia artefactos + script al servidor vía `scp`.
4. Ejecuta `deploy.sh dummy-a` y `deploy.sh dummy-b` por SSH.
5. Smoke tests finales desde el runner (`curl`).

**Secretos necesarios en GitHub:**

| Secret | Descripción |
|---|---|
| `AZURE_VM_IP` | IP pública de la VM |
| `AZURE_VM_USER` | Usuario SSH (ej. `ubuntu`) |
| `AZURE_VM_SSH_KEY` | Clave privada SSH (contenido del `.pem`) |

### 2.6 Pipeline Comparativo — Azure DevOps

Los archivos `pipeline/azure-pipelines-ci.yml` y `pipeline/azure-pipelines-cd.yml` replican el mismo flujo en Azure DevOps Pipelines.

**Diferencias observadas respecto a GitHub Actions:**

| Aspecto | GitHub Actions | Azure DevOps |
|---|---|---|
| Sintaxis de secretos | `${{ secrets.X }}` | `$(X)` |
| Publicar artefactos | `upload-artifact` action | `PublishBuildArtifacts` task |
| Instalar SSH key | Manual (echo + chmod) | `InstallSSHKey@0` task |
| Test results | Sin soporte nativo | `PublishTestResults@2` integrado |
| Tiempo de setup | Menor (todo en GitHub) | Mayor (proyecto + service connection) |

### 2.7 Infraestructura Azure

| Componente | Configuración |
|---|---|
| VM | Ubuntu 24.04 LTS, B1s |
| NSG | TCP 22 (SSH), 80 (HTTP), 8080 (API) |
| IP | Pública estática |
| Auto-shutdown | 20:00 (Cost Management) |

---

## 3. Problemas Encontrados y Soluciones

| Problema | Causa | Solución |
|---|---|---|
| `workflow_run` no dispara el CD | Rama en el trigger incorrecta | Especificar `branches: [main]` en el trigger del `workflow_run` |
| `tidy` sale con código 1 en warnings | Por defecto tidy falla en advertencias | Agregar `|| true` para ignorar warnings (solo errores fatales interrumpen) |
| Servicio `dummy-b` no inicia tras deploy | Permisos de archivo en `/opt/dummy-b` | Agregar `sudo chown -R ubuntu` en el script de deploy |
| SSH known_hosts vacío en runner | El runner no conoce el fingerprint de la VM | `ssh-keyscan` antes del primer `ssh` |
| Artefacto de CI no disponible en CD | El `download-artifact` necesita el `run-id` del CI | Usar `github.event.workflow_run.id` como `run-id` |

---

## 4. Conclusiones

1. **GitHub Actions** simplifica enormemente la automatización CI/CD cuando el código ya está en GitHub: no requiere infraestructura extra y el marketplace de actions cubre la mayoría de los casos de uso.

2. **Azure DevOps** ofrece más granularidad (Environments con aprobaciones, grupos de variables, integraciones con Boards) pero tiene mayor complejidad de configuración inicial.

3. La separación en dos pipelines (`ci.yml` / `cd.yml`) es una buena práctica: permite re-desplegar sin re-ejecutar tests y deja un historial claro de builds vs deploys.

4. Usar secretos en lugar de valores hardcodeados es fundamental: exponer una clave SSH en el YAML comprometería el acceso al servidor.

5. Los smoke tests al final del CD son críticos — detectan fallos de configuración que los unit tests no pueden ver.

---

## 5. Reflexión Técnica

**1. ¿Qué ventajas ofrece DevOps frente al despliegue manual?**  
Elimina el error humano, garantiza reproducibilidad, reduce el tiempo de entrega y genera un historial auditable de cada despliegue.

**2. ¿Qué problemas podrían ocurrir sin automatización?**  
Configuraciones inconsistentes entre ambientes, despliegues fallidos por pasos olvidados, ausencia de rollback y falta de trazabilidad.

**3. ¿Qué parte del pipeline fue más compleja?**  
La configuración del CD: gestión de secretos SSH, transferencia de artefactos entre jobs/pipelines y los smoke tests end-to-end.

**4. ¿Qué mejorarían en un ambiente empresarial real?**  
Agregar ambientes intermedios (staging), aprobaciones manuales antes de producción, notificaciones (Slack/Teams), monitoreo post-deploy y rollback automático si el smoke test falla.

**5. ¿Qué riesgos de seguridad identificaron?**  
Exposición de la clave SSH si se loguea por error, surface de ataque del puerto 22 abierto al mundo (mitigar con IP allowlist en NSG), dependencias Python desactualizadas con CVEs.

**6. ¿Cómo escalarían esta solución?**  
Contenedorizando con Docker + container registry, usando un orquestador (Kubernetes / Azure Container Apps), implementando blue-green deployments y separando la infraestructura con Terraform.

---

## 6. URL Pública del Servicio

> Nota: los valores de IP se configuran como secretos en GitHub/Azure DevOps.  
> Una vez desplegado, el servicio queda disponible en:

- **Dummy A (sitio estático):** `http://<AZURE_VM_IP>/`
- **Dummy B (API health):** `http://<AZURE_VM_IP>:8080/health`
