# Defensa y presentacion unificada: Dashboard DevSecOps con Wazuh

## 1. Idea central para defender

La aplicacion consume informacion real desde Wazuh, la normaliza, la guarda en una base de datos propia y permite observar el ciclo de vida de las vulnerabilidades en el tiempo.

La frase principal para decir al profesor es:

> Wazuh detecta vulnerabilidades, el Wazuh Indexer las almacena, nuestro backend FastAPI las consulta por API, las procesa, las persiste en TimescaleDB/PostgreSQL y el frontend las muestra en un dashboard.

El proyecto no debe presentarse como producto final cerrado. Es una primera entrega funcional, integrada y medible, con deuda tecnica identificada y plan de mejora.

## PUNTOS CLAVE PARA LA DEFENSA:

- La fuente real de datos es Wazuh. La aplicacion no usa datos inventados, mockeados ni cargados manualmente para simular resultados.
- La app no extrae datos desde la interfaz visual de Wazuh Dashboard. Consulta el Wazuh Indexer por API REST en el puerto `9200`.
- El backend FastAPI funciona como middleware entre Wazuh, la base de datos y el frontend. Centraliza autenticacion, conexion, sincronizacion, procesamiento y exposicion de datos.
- FastAPI genera OpenAPI automaticamente. Eso permite documentar endpoints, probarlos en `/api/docs` y facilitar el escaneo DAST con OWASP ZAP.
- La base local no duplica Wazuh por capricho. Existe para normalizar, historizar y consultar evolucion de vulnerabilidades con un modelo propio.
- La tabla `wazuh_vulnerabilities` representa el estado actual de las vulnerabilidades: activas o resueltas.
- La tabla `vulnerability_detections` representa eventos historicos con `timestamp`. Por eso permite ver aparicion, persistencia, resolucion y reaparicion.
- `TimescaleDB` se usa porque el problema tiene naturaleza temporal. Las vulnerabilidades deben analizarse como eventos en el tiempo, no solo como una lista estatica.
- El frontend Vue/Nginx solo visualiza y dispara acciones. No contiene la logica critica de ingesta ni se conecta directamente a Wazuh.
- Docker Compose separa responsabilidades en servicios reproducibles: `frontend`, `api` y `db-api`.
- Jenkins orquesta el pipeline DevSecOps. Ejecuta pruebas, build, analisis con SonarQube, Quality Gate y DAST con OWASP ZAP.
- SonarQube representa SAST: revisa codigo sin ejecutarlo para detectar bugs, vulnerabilidades, code smells y deuda tecnica.
- OWASP ZAP representa DAST: revisa la aplicacion mientras esta corriendo y prueba la API usando el documento OpenAPI.
- La deuda tecnica esta identificada: DAST frontend, Trivy, SCA, RBAC fuerte, Vault real, backups, hardening y paginacion para grandes volumenes.
- La defensa debe ser honesta: la primera entrega demuestra integracion funcional, persistencia historica y pipeline operativo, no una plataforma productiva final.

Respuesta corta si el profesor pide resumir todo:

> La aplicacion toma vulnerabilidades reales desde el Wazuh Indexer, las procesa en un backend FastAPI, las guarda en PostgreSQL/TimescaleDB con historial temporal y las muestra en un dashboard. Ademas, el pipeline Jenkins valida calidad y seguridad con tests, SonarQube, Quality Gate y OWASP ZAP.

## 2. Que demuestra la aplicacion

La aplicacion demuestra tres cosas importantes:

1. Hay comunicacion real con Wazuh.
2. Los datos no son inventados ni estaticos.
3. La aplicacion tiene persistencia propia para analizar evolucion historica.

Flujo resumido:

```text
Agente Wazuh
  -> Wazuh Manager
  -> Wazuh Indexer
  -> Backend FastAPI
  -> TimescaleDB/PostgreSQL
  -> Frontend Vue/Nginx
```

Punto clave:

> La aplicacion no lee desde el dashboard visual de Wazuh. Se conecta al Wazuh Indexer, que es donde Wazuh guarda los documentos consultables de vulnerabilidades.

## 3. Conceptos que seguramente preguntaran

### API

API significa:

```text
Application Programming Interface
```

Una API es una interfaz para que dos sistemas se comuniquen de forma ordenada. En vez de que el frontend lea directamente la base de datos o Wazuh, llama endpoints definidos por el backend.

Ejemplo en este proyecto:

```text
Frontend -> GET /api/vulns -> Backend -> Base de datos
```

Para que sirve:

- separar frontend y backend,
- controlar autenticacion,
- validar datos,
- centralizar reglas de negocio,
- exponer informacion en formato JSON,
- permitir pruebas automaticas y escaneos de seguridad.

Respuesta corta:

> Una API es el contrato de comunicacion entre sistemas. En nuestra app permite que el frontend consulte al backend y que el backend consulte Wazuh sin exponer la logica interna.

### FastAPI

FastAPI es un framework de Python para construir APIs web.

En este proyecto es el backend principal:

```text
vuln-api/app/main.py
```

Para que sirve:

- crear endpoints REST,
- autenticar usuarios,
- administrar conexiones Wazuh,
- consultar el Wazuh Indexer,
- procesar vulnerabilidades,
- guardar datos en PostgreSQL/TimescaleDB,
- generar documentacion OpenAPI automaticamente.

Por que se eligio:

- es liviano,
- funciona bien en Docker,
- se integra con SQLAlchemy,
- soporta autenticacion JWT,
- genera documentacion automatica,
- facilita que OWASP ZAP escanee la API usando OpenAPI.

Respuesta corta:

> FastAPI es el framework Python que usamos para construir el middleware entre Wazuh, la base de datos y el dashboard.

### OpenAPI

OpenAPI es una especificacion estandar que describe una API REST.

Describe:

- endpoints disponibles,
- metodos HTTP,
- parametros,
- cuerpos de request,
- respuestas,
- codigos de estado.

En FastAPI se genera automaticamente en:

```text
https://127.0.0.1/api/openapi.json
```

Tambien permite ver documentacion interactiva en:

```text
https://127.0.0.1/api/docs
```

Para que sirve en el proyecto:

- documentar la API sin escribir todo a mano,
- facilitar pruebas manuales,
- permitir que OWASP ZAP escanee la API,
- demostrar al profesor que los endpoints existen y estan definidos formalmente.

Respuesta corta:

> OpenAPI es el mapa formal de nuestra API. FastAPI lo genera automaticamente y ZAP lo usa para saber que endpoints debe probar.

### REST

REST es un estilo de arquitectura para APIs web. Usa HTTP y recursos.

Ejemplos:

```text
GET  /vulns
POST /wazuh-connections
POST /wazuh-connections/{id}/sync
```

Respuesta corta:

> REST es la forma en que exponemos operaciones de la aplicacion usando endpoints HTTP claros.

### Wazuh Indexer

El Wazuh Indexer es el componente donde Wazuh almacena los datos indexados. En versiones actuales se basa en OpenSearch.

La app consulta este indice:

```text
wazuh-states-vulnerabilities-*/_search
```

Respuesta corta:

> El Indexer es la fuente tecnica de datos para nuestra app. Desde ahi extraemos las vulnerabilidades reales.

## 4. Distribucion fisica del sistema

### Servidor Wazuh

En el servidor Wazuh estan:

- Wazuh Dashboard: interfaz visual.
- Wazuh Manager: recibe datos de agentes.
- Wazuh Indexer/OpenSearch: almacena indices y vulnerabilidades.

Puertos importantes:

```text
9200/tcp: Wazuh Indexer / OpenSearch
1514/tcp: comunicacion del agente con Wazuh Manager
1515/tcp: enrolamiento/autenticacion inicial de agentes
443/tcp: Wazuh Dashboard, segun instalacion
```

Ejemplo de URL local usada durante pruebas:

```text
https://192.168.1.46:9200
```

Si se usa el Wazuh del profesor, se debe reemplazar por la IP, DNS, puerto y credenciales que entregue el profesor.

### Maquina del alumno

En la maquina del alumno corren:

- la aplicacion con Docker Compose,
- el frontend Vue servido por Nginx,
- el backend FastAPI,
- la base TimescaleDB/PostgreSQL,
- opcionalmente el agente Wazuh local.

Servicios principales de la app:

```text
frontend -> Vue + Nginx
api      -> FastAPI
db-api   -> TimescaleDB/PostgreSQL
```

## 5. Arquitectura general

Diagrama logico:

```text
Usuario
  |
  v
Frontend Vue/Nginx
  |
  | /api
  v
Backend FastAPI
  |
  +----------------------> Wazuh Indexer/API
  |
  v
TimescaleDB/PostgreSQL
```

Diagrama Wazuh completo:

```text
Agente Wazuh
  |
  | puerto 1514/tcp
  v
Wazuh Manager
  |
  v
Wazuh Indexer/OpenSearch
  ^
  | HTTPS REST, puerto 9200
  |
Backend FastAPI de la app
  |
  | SQL
  v
TimescaleDB/PostgreSQL de la app
```

Pipeline DevSecOps:

```text
GitHub -> Jenkins -> Tests -> Build -> SonarQube -> Quality Gate -> OWASP ZAP
```

## 6. Como levantar y entrar a la app

Desde la raiz del repositorio:

```bash
cd /home/sidwilson0/Escritorio/devsecops
docker compose up -d --build
```

Verificar contenedores:

```bash
docker compose ps
```

Resultado esperado:

```text
db-api     Up ... healthy
api        Up ... healthy
frontend   Up ... 0.0.0.0:80->80, 0.0.0.0:443->443
```

Entrar desde navegador:

```text
https://127.0.0.1
```

Como el certificado local es autofirmado, el navegador puede mostrar advertencia de seguridad. En entorno local se acepta la excepcion.

Probar frontend:

```bash
curl -k -I https://127.0.0.1/
```

Probar OpenAPI:

```bash
curl -k https://127.0.0.1/api/openapi.json | head
```

## 7. Frontend

Tecnologia:

```text
Vue 3 + Vite + Nginx
```

Archivos principales:

```text
frontend/src/presentation/views/Login.vue
frontend/src/presentation/views/Dashboard.vue
frontend/src/presentation/views/Timeline.vue
frontend/src/presentation/views/ConfigWazuh.vue
frontend/src/application/services/vulnService.js
frontend/src/application/services/wazuhService.js
frontend/nginx.conf
```

Responsabilidades:

- permitir inicio de sesion,
- mostrar dashboard de vulnerabilidades,
- mostrar evolucion historica,
- administrar conexiones Wazuh,
- probar conexion,
- ejecutar sincronizacion manual.

El frontend no se conecta directamente a Wazuh. Llama al backend usando rutas con prefijo:

```text
/api
```

Nginx hace el proxy:

```text
Navegador -> https://127.0.0.1/api/... -> contenedor api:8000
```

## 8. Backend

Tecnologia:

```text
FastAPI + SQLAlchemy + PostgreSQL/TimescaleDB
```

Archivos principales:

```text
vuln-api/app/main.py
vuln-api/app/models.py
vuln-api/app/wazuh_client.py
vuln-api/app/db.py
vuln-api/app/auth.py
vuln-api/app/crypto.py
```

Responsabilidades:

- autenticar usuarios,
- administrar usuarios,
- guardar conexiones Wazuh,
- cifrar la password de Wazuh,
- probar conexion contra Wazuh,
- sincronizar vulnerabilidades desde Wazuh,
- guardar vulnerabilidades actuales,
- guardar eventos historicos,
- exponer datos al frontend mediante API REST.

Rutas principales:

```text
POST /auth/login
GET  /users/me
GET  /wazuh-connections
POST /wazuh-connections
POST /wazuh-connections/{id}/test
POST /wazuh-connections/{id}/sync
POST /vulns/sync-all
GET  /vulns
GET  /vulns/evolution/summary
GET  /vulns/evolution/weekly
GET  /vulns/evolution/top-assets
```

## 9. Comunicacion con Wazuh

La integracion esta implementada en:

```text
vuln-api/app/wazuh_client.py
```

Funciones importantes:

```text
test_connection(indexer_url, wazuh_user, wazuh_password)
fetch_all_vulns(indexer_url, wazuh_user, wazuh_password)
```

Indice consultado:

```text
wazuh-states-vulnerabilities-*/_search
```

Prueba manual del Indexer:

```bash
curl -k -u usuario:password https://IP_DEL_WAZUH:9200
```

Prueba manual del indice de vulnerabilidades:

```bash
curl -k -u usuario:password \
  "https://IP_DEL_WAZUH:9200/wazuh-states-vulnerabilities-*/_search?size=1"
```

Si responde JSON, hay conectividad y autenticacion.

## 10. Conexion del agente Wazuh

Si la maquina del alumno tambien funciona como agente Wazuh, el agente debe apuntar al Wazuh Manager correcto.

Archivo:

```text
/var/ossec/etc/ossec.conf
```

Bloque esperado:

```xml
<client>
  <server>
    <address>IP_DEL_WAZUH_MANAGER</address>
    <port>1514</port>
    <protocol>tcp</protocol>
  </server>
</client>
```

Diagnostico:

```bash
sudo systemctl status wazuh-agent
nc -vz IP_DEL_WAZUH_MANAGER 1514
nc -vz IP_DEL_WAZUH_MANAGER 1515
sudo grep -A5 -B2 "<server>" /var/ossec/etc/ossec.conf
```

Reiniciar agente:

```bash
sudo systemctl restart wazuh-agent
```

Verificar estado:

```bash
sudo grep ^status /var/ossec/var/run/wazuh-agentd.state
```

Resultado correcto:

```text
status='connected'
```

## 11. Base de datos propia

La aplicacion no depende solo de Wazuh para visualizar datos. Despues de consultar Wazuh, guarda informacion en una base propia.

Base usada:

```text
TimescaleDB sobre PostgreSQL
```

Servicio:

```text
db-api
```

Volumen persistente:

```text
postgres_api_data
```

Esto significa que los datos sobreviven si se reinician contenedores.

Tablas principales:

```text
wazuh_connections
wazuh_vulnerabilities
vulnerability_history
managers
assets
vulnerability_catalog
vulnerability_detections
users
user_interactions
```

## 12. Modelo de datos

El profesor pidio que la app no sea solo una foto fija. Debe permitir observar el ciclo de vida de las vulnerabilidades.

Por eso el modelo separa tres niveles:

### Infraestructura

Tabla:

```text
managers
```

Representa servidores Wazuh configurados:

```text
id
nombre
api_url
api_key_vault_ref
legacy_connection_id
```

Tabla:

```text
assets
```

Representa agentes o equipos monitoreados:

```text
id
wazuh_agent_id
hostname
os_version
ip_address
manager_id
```

### Catalogo

Tabla:

```text
vulnerability_catalog
```

Evita duplicar informacion larga de CVEs:

```text
cve_id
severity
description
cvss_score
```

### Eventos

Tabla:

```text
vulnerability_detections
```

Es la tabla clave para evolucion temporal:

```text
timestamp
asset_id
cve_id
status
package_name
package_version
```

Estados posibles:

```text
Detected
Resolved
Re-emerged
```

Respuesta corta:

> El diseno separa infraestructura, catalogo y eventos. Asi evitamos duplicar datos y podemos consultar cuando una vulnerabilidad aparecio, desaparecio o reaparecio.

## 13. TimescaleDB e hypertable

La tabla:

```text
vulnerability_detections
```

se convierte en hypertable de TimescaleDB usando:

```text
timestamp
```

Esto permite manejar series de tiempo. En vez de guardar solo el estado actual, la app guarda observaciones historicas de cada sincronizacion.

Demostrar que TimescaleDB esta instalado:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select extname from pg_extension where extname = '\''timescaledb'\'';"'
```

Demostrar hypertable:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select hypertable_name from timescaledb_information.hypertables where hypertable_name = '\''vulnerability_detections'\'';"'
```

## 14. Sincronizacion de vulnerabilidades

Cuando se presiona "Forzar Sincronizacion":

1. El frontend llama al backend.
2. El backend busca la conexion Wazuh activa.
3. El backend descifra la password guardada.
4. El backend consulta el Wazuh Indexer.
5. Wazuh devuelve documentos de vulnerabilidades.
6. El backend identifica agente, sistema operativo, paquete, CVE, severidad y score.
7. Se actualiza `wazuh_vulnerabilities`.
8. Se actualiza `vulnerability_catalog`.
9. Se registra un evento en `vulnerability_detections`.
10. El dashboard consulta nuevamente el backend y muestra metricas actualizadas.

Endpoint usado:

```text
POST /wazuh-connections/{id}/sync
```

Endpoint para sincronizar todas:

```text
POST /vulns/sync-all
```

## 15. Logica de evolucion

Nueva vulnerabilidad:

```text
Si llega una combinacion nueva:
connection_id + agent_id + package_name + package_version + cve_id

Se guarda:
status = ACTIVE
evento = Detected
```

Vulnerabilidad persistente:

```text
Si ya existia y sigue llegando desde Wazuh:
status = ACTIVE
evento = Detected
```

Esto no es duplicado conceptual. Es una nueva observacion temporal.

Vulnerabilidad resuelta:

```text
Si estaba activa pero Wazuh ya no la reporta:
status = RESOLVED
evento = Resolved
```

Vulnerabilidad reaparecida:

```text
Si estaba resuelta y Wazuh vuelve a reportarla:
status = ACTIVE
evento = Re-emerged
```

Frase para defender eventos historicos:

> Eventos historicos aumenta con cada sincronizacion porque la aplicacion registra cada escaneo como una muestra temporal. No son vulnerabilidades duplicadas; son observaciones historicas que permiten medir persistencia, resolucion y reaparicion.

## 16. Como demostrar que hay datos de Wazuh en la base

Ver conexiones Wazuh configuradas:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select id, name, indexer_url, is_active, tested, last_test_ok from wazuh_connections order by id;"'
```

Ver vulnerabilidades actuales:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select status, count(*) from wazuh_vulnerabilities group by status order by status;"'
```

Ver ultimos datos procesados:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select agent_id, agent_name, package_name, package_version, cve_id, severity, score_base, last_seen from wazuh_vulnerabilities order by last_seen desc limit 10;"'
```

Ver eventos historicos:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select status, count(*) from vulnerability_detections group by status order by status;"'
```

Ver eventos con fecha:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select timestamp, status, cve_id, package_name, package_version from vulnerability_detections order by timestamp desc limit 20;"'
```

Ver tendencia semanal:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select time_bucket('\''1 week'\'', timestamp) as semana, count(*) as total_vulnerabilidades from vulnerability_detections where status = '\''Detected'\'' group by semana order by semana;"'
```

Ver top de servidores vulnerables:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select a.hostname, count(distinct vd.cve_id) as total from assets a join vulnerability_detections vd on a.id = vd.asset_id where vd.timestamp > now() - interval '\''7 days'\'' and vd.status in ('\''Detected'\'', '\''Re-emerged'\'') group by a.hostname order by total desc limit 5;"'
```

Ver tablas:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\dt"'
```

## 17. Demostracion recomendada en clase

Antes de presentar:

1. Verificar que Wazuh este arriba.
2. Verificar que el Indexer responda.
3. Verificar que el agente, si aplica, este conectado.
4. Levantar la app.
5. Verificar contenedores.
6. Entrar a la app.
7. Probar conexion Wazuh.
8. Sincronizar.
9. Mostrar datos en base.
10. Mostrar dashboard y timeline.

Comandos:

```bash
curl -k -u usuario:password https://IP_DEL_WAZUH:9200
nc -vz IP_DEL_WAZUH 9200
docker compose ps
curl -k -I https://127.0.0.1/
curl -k https://127.0.0.1/api/openapi.json | head
```

Orden recomendado durante la presentacion:

1. Mostrar Wazuh Dashboard.
2. Mostrar que el agente aparece activo, si corresponde.
3. Mostrar que el Indexer responde por terminal.
4. Mostrar la app en `https://127.0.0.1`.
5. Ir a configuracion Wazuh y probar conexion.
6. Ejecutar sincronizacion.
7. Mostrar dashboard.
8. Mostrar SQL con datos en `wazuh_vulnerabilities`.
9. Mostrar SQL con eventos en `vulnerability_detections`.
10. Explicar que la app guarda series de tiempo.

## 18. Demostracion rapida en 10 comandos

1. Ver agente conectado, si aplica:

```bash
sudo grep ^status /var/ossec/var/run/wazuh-agentd.state
```

2. Ver puerto del Indexer:

```bash
nc -vz IP_DEL_WAZUH 9200
```

3. Ver Indexer:

```bash
curl -k -u usuario:password https://IP_DEL_WAZUH:9200
```

4. Ver indice de vulnerabilidades:

```bash
curl -k -u usuario:password "https://IP_DEL_WAZUH:9200/wazuh-states-vulnerabilities-*/_search?size=1"
```

5. Ver contenedores:

```bash
cd /home/sidwilson0/Escritorio/devsecops
docker compose ps
```

6. Ver frontend:

```bash
curl -k -I https://127.0.0.1/
```

7. Ver API/OpenAPI:

```bash
curl -k https://127.0.0.1/api/openapi.json | head
```

8. Ver conexion Wazuh guardada:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select id, name, indexer_url, last_test_ok from wazuh_connections;"'
```

9. Ver vulnerabilidades actuales:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select status, count(*) from wazuh_vulnerabilities group by status;"'
```

10. Ver eventos historicos:

```bash
docker compose exec -T db-api sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select status, count(*) from vulnerability_detections group by status;"'
```

## 19. Pipeline DevSecOps

El pipeline esta definido en:

```text
dev-tools/jenkins/Jenkinsfile
```

Flujo general:

1. Jenkins clona el repo desde GitHub.
2. Levanta backend en Docker y corre `pytest`.
3. Construye frontend y ejecuta coverage.
4. Levanta SonarQube si no esta arriba.
5. Ejecuta `sonar-scanner`.
6. Espera el Quality Gate.
7. Levanta una app temporal para DAST.
8. Ejecuta OWASP ZAP contra la API usando OpenAPI.
9. Intenta escanear frontend.

Estado reportado en primera entrega:

```text
Finished: SUCCESS
Quality Gate: OK
```

Quedo operativo:

- Backend CI.
- Frontend CI/build.
- SonarQube SAST.
- Quality Gate.
- ZAP API DAST contra `http://api:8000/openapi.json`.
- Jenkins usando token correcto de SonarQube.
- SonarQube procesando el proyecto `vuln-app`.

Deuda importante:

```text
Job spider failed to access URL http://frontend:80
frontend: Temporary failure in name resolution
```

Interpretacion honesta:

- ZAP backend si escaneo.
- ZAP frontend no fue realmente escaneado.
- El pipeline es funcional, pero DAST frontend queda como deuda tecnica.

Estimacion:

```text
Validez del pipeline actual: 80-85%
Validez CI + SonarQube + Quality Gate: 95%
Validez DAST completo: 65-70%
```

## 20. Herramientas DevSecOps

### Jenkins

Jenkins es el orquestador del pipeline.

No reemplaza a SonarQube ni ZAP. Los coordina.

Carpeta:

```text
dev-tools/jenkins
```

Entrar a Jenkins:

```text
http://localhost:8080
```

Respuesta corta:

> Jenkins automatiza el flujo DevSecOps. Ejecuta pruebas, build, analisis y controles de seguridad en orden.

### SonarQube

SonarQube es una herramienta SAST.

SAST significa:

```text
Static Application Security Testing
```

Analiza el codigo sin ejecutarlo. Busca:

- bugs,
- vulnerabilidades,
- code smells,
- duplicacion,
- deuda tecnica,
- problemas de mantenibilidad.

Archivo:

```text
dev-tools/sonarqube/sonar-project.properties
```

Entrar a SonarQube:

```text
http://localhost:9000
```

Respuesta corta:

> SonarQube revisa calidad y seguridad estatica del codigo antes de considerar valido el build.

### Quality Gate

Un gate es una compuerta de control.

El Quality Gate de SonarQube evalua metricas como:

- bugs,
- vulnerabilidades,
- code smells,
- duplicacion,
- cobertura,
- mantenibilidad.

Respuesta corta:

> El Quality Gate decide si el proyecto cumple reglas minimas de calidad. Si no cumple, el pipeline debe fallar.

### OWASP ZAP

OWASP ZAP es una herramienta DAST.

DAST significa:

```text
Dynamic Application Security Testing
```

A diferencia de SAST, DAST analiza la aplicacion en ejecucion. Hace peticiones HTTP y busca problemas desde fuera.

En este proyecto:

- escanea la API usando OpenAPI,
- revisa endpoints,
- detecta problemas HTTP y headers,
- genera reportes HTML.

Respuesta corta:

> ZAP complementa SonarQube. SonarQube mira codigo; ZAP mira comportamiento de la aplicacion ejecutandose.

### Trivy

Trivy escanea contenedores, imagenes Docker, dependencias, IaC y vulnerabilidades conocidas.

Actualmente no esta integrado. Queda como mejora futura:

```text
Jenkins -> Trivy -> imagen backend/frontend -> gate de severidad
```

### SCA

SCA significa:

```text
Software Composition Analysis
```

Analiza dependencias de terceros, como paquetes `npm` o `pip`.

Herramientas posibles:

- Snyk.
- OWASP Dependency-Check.
- npm audit.
- pip-audit.

Actualmente no esta integrado formalmente. Es deuda tecnica.

## 21. Conceptos de Git y build

### Commit

Un commit es un punto de control del codigo fuente. Representa un cambio versionado, con autor, fecha y mensaje.

Respuesta corta:

> El commit deja trazabilidad de los cambios y permite que Jenkins ejecute una version conocida del proyecto.

### Push

El push envia commits locales al repositorio remoto.

En este proyecto Jenkins lee desde GitHub. Si un cambio no esta pusheado, Jenkins no lo ejecuta.

### Build

Build es el proceso de construir una version ejecutable o desplegable de la app.

Incluye:

- instalar dependencias,
- correr pruebas,
- generar cobertura,
- construir imagenes Docker,
- compilar frontend Vue,
- preparar contenedores.

Respuesta corta:

> El build confirma que el codigo puede transformarse en una aplicacion ejecutable y reproducible.

## 22. Modelo DevSecOps

DevSecOps integra desarrollo, operaciones y seguridad.

En este proyecto:

- Desarrollo: backend Python/FastAPI y frontend Vue.
- Operaciones: Docker, Docker Compose, Jenkins.
- Seguridad: SonarQube, OWASP ZAP, autenticacion, manejo de tokens y cifrado de credenciales Wazuh.

### Shift-left

Shift-left significa revisar seguridad antes, no al final.

Ejemplo:

```text
Commit -> Build -> Tests -> SonarQube -> Quality Gate -> DAST
```

Respuesta corta:

> Shift-left permite encontrar problemas de seguridad y calidad antes de desplegar o entregar la aplicacion.

### Responsabilidad compartida

En DevSecOps la seguridad no es solo responsabilidad de un equipo.

Participan:

- desarrollo,
- operaciones,
- seguridad,
- quien define requisitos,
- quien administra infraestructura.

Respuesta corta:

> Si una vulnerabilidad llega a produccion, no falla solo seguridad. Tambien falla el proceso, el pipeline y las decisiones tecnicas.

## 23. Por que esta arquitectura

### Por que FastAPI

Se eligio porque permite crear un middleware claro entre Wazuh y el dashboard. Ademas genera OpenAPI automaticamente, lo que facilita documentacion, pruebas y escaneo DAST.

### Por que Vue

Vue permite construir dashboards interactivos, filtros, tablas y timeline sin mezclar logica visual con logica de ingesta.

### Por que PostgreSQL/TimescaleDB

El problema es temporal. No basta guardar el ultimo estado. PostgreSQL da integridad relacional y TimescaleDB agrega soporte para series de tiempo.

### Por que Docker Compose

Docker Compose permite levantar servicios reproducibles localmente. Para una primera entrega es suficiente y evita complejidad innecesaria de Kubernetes o nube.

### Por que no nube todavia

La primera entrega prioriza integracion, normalizacion, persistencia, pipeline y demostracion local. Nube agrega costos, dominios, certificados, gestion de secretos y seguridad perimetral. Queda como evolucion.

### Evolucion a microservicios

Hoy la app esta contenedorizada y separada por responsabilidades, pero no es una arquitectura de microservicios orientada a eventos completa.

Evolucion posible:

```text
Servicio de ingesta Wazuh
  -> vulnerability.detected
  -> vulnerability.resolved
  -> vulnerability.reemerged

Servicio de procesamiento historico
  -> dwell time
  -> tendencias
  -> agregaciones

Servicio API/visualizacion
  -> endpoints para frontend
```

## 24. Conexion con el Wazuh del profesor

Datos necesarios:

- IP o DNS del Wazuh Indexer.
- Puerto, normalmente `9200`.
- Protocolo, normalmente `https`.
- Usuario y contrasena o token autorizado.
- Certificado CA, si usa TLS interno.
- Si requiere VPN.
- Si el servidor permite conexiones desde la IP del alumno.
- Permisos sobre `wazuh-states-vulnerabilities-*`.

Formato esperado:

```text
https://IP_O_HOST_DEL_WAZUH:9200
```

Pruebas desde la maquina:

```bash
ping IP_DEL_WAZUH
nc -vz IP_DEL_WAZUH 9200
curl -k https://IP_DEL_WAZUH:9200
curl -k -u usuario:password https://IP_DEL_WAZUH:9200
curl -k -u usuario:password "https://IP_DEL_WAZUH:9200/wazuh-states-vulnerabilities-*/_search?size=1"
```

Prueba desde Docker:

```bash
docker run --rm curlimages/curl:8.12.1 -k https://IP_DEL_WAZUH:9200
```

Si desde el host funciona pero desde Docker no, revisar:

- DNS,
- rutas,
- firewall,
- VPN,
- modo de red Docker.

Configuracion en la app:

```text
Nombre: Wazuh Profesor
Indexer URL: https://IP_DEL_WAZUH:9200
Usuario: usuario_entregado
Password: password_entregado
```

Respuesta corta sobre VPN:

> Si el Wazuh del profesor esta en una red privada, necesitamos VPN para que nuestra maquina tenga ruta hacia ese servidor. Primero validamos conectividad desde el host, luego desde Docker y finalmente configuramos la URL del Indexer en la app.

## 25. Deuda tecnica actual

Deuda identificada:

- ZAP frontend no escanea realmente por error DNS interno.
- Falta Trivy para contenedores.
- Falta SCA formal para dependencias.
- Falta RBAC fuerte por roles/grupos.
- `api_key_vault_ref` existe como concepto, pero no hay Vault real.
- Faltan backups automaticos.
- Falta hardening completo de headers.
- Falta paginacion robusta para muchisimos registros Wazuh.
- Falta configurar CA/TLS formal en vez de depender de `verify=False`.
- Faltan sincronizaciones automaticas programadas.

Deuda aceptable para primera entrega:

```text
Integracion Wazuh: funcional
Persistencia local: funcional
Pipeline Jenkins: funcional
SonarQube: funcional
Quality Gate: funcional
DAST API: funcional
DAST frontend: pendiente
Trivy/SCA/RBAC/Vault: pendientes
```

## 26. Que pasa si hay un apagon

Los servicios Docker tienen:

```text
restart: unless-stopped
```

La base usa volumen:

```text
postgres_api_data
```

Por eso los datos no deberian perderse al reiniciar contenedores.

Despues de un apagon:

```bash
cd /home/sidwilson0/Escritorio/devsecops
docker compose ps
docker compose up -d
```

Verificar Wazuh, segun corresponda:

```bash
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-indexer
sudo systemctl status wazuh-dashboard
sudo systemctl status wazuh-agent
```

Riesgo principal:

> Si la IP del servidor Wazuh cambia por DHCP, fallaran el agente Wazuh y la conexion de la app. La solucion es IP fija o reserva DHCP.

## 27. Preguntas probables del profesor

### Que hace SonarQube?

Analiza codigo estatico de backend y frontend. Busca bugs, vulnerabilidades, code smells y deuda tecnica.

### Que es el Quality Gate?

Es una compuerta de calidad. Si el proyecto no cumple las reglas configuradas, el pipeline debe fallar.

### Que hace OWASP ZAP?

Hace DAST. Escanea la aplicacion en ejecucion desde fuera. En este proyecto escanea la API usando OpenAPI.

### Por que el pipeline dice SUCCESS si ZAP frontend fallo?

Porque esa etapa quedo como no bloqueante para no cortar la primera entrega por una deuda conocida. Se declara honestamente: backend DAST si corre, frontend DAST debe corregirse.

### Que hace Jenkins?

Orquesta herramientas. Ejecuta pruebas, build, SonarQube, Quality Gate y ZAP.

### Que hace Docker Compose?

Levanta servicios reproducibles: API, base, frontend, SonarQube, Jenkins y servicios temporales.

### Por que usan base local si Wazuh ya tiene datos?

Porque el proyecto necesita historizar, normalizar y analizar evolucion. Wazuh entrega datos, pero la app necesita su propio modelo para calcular ciclo de vida, filtros y visualizaciones.

### Por que se necesita timestamp?

Porque sin timestamp solo se ve el estado actual. Con timestamp se puede saber cuando aparecio, cuando desaparecio y cuanto tiempo estuvo activa una vulnerabilidad.

### Que significa deuda tecnica?

Son pendientes o decisiones que permiten avanzar ahora, pero que deben resolverse para mejorar seguridad, mantenibilidad o completitud.

### Que falta para produccion?

RBAC fuerte, secrets manager real, Trivy, SCA, DAST frontend corregido, hardening de headers, migraciones robustas, backups y despliegue automatizado.

### Que es API?

Es el contrato de comunicacion entre sistemas. En la app permite que el frontend hable con el backend y que el backend hable con Wazuh.

### Que es FastAPI?

Es el framework Python usado para construir el backend y exponer endpoints REST.

### Que es OpenAPI?

Es la especificacion que documenta formalmente los endpoints de la API. FastAPI la genera automaticamente y ZAP la usa para escanear la API.

## 28. Checklist para la presentacion

Antes de presentar:

- Verificar app en `https://127.0.0.1`.
- Verificar `docker compose ps`.
- Verificar Wazuh Indexer con `curl`.
- Verificar conexion Wazuh guardada en base.
- Sincronizar datos.
- Mostrar dashboard.
- Mostrar consulta SQL de vulnerabilidades.
- Mostrar consulta SQL de eventos historicos.
- Verificar Jenkins, si se presentara pipeline.
- Verificar SonarQube, si se presentara Quality Gate.

Comandos utiles:

```bash
docker compose ps
curl -k -I https://127.0.0.1/
curl -k https://127.0.0.1/api/openapi.json | head
curl http://localhost:9000/api/system/status
git log --oneline -5
```

## 29. Explicacion corta para decir al profesor

> Nuestra aplicacion corre con Docker Compose y separa frontend, backend y base de datos. El frontend esta hecho en Vue y no se conecta directo a Wazuh. El backend esta hecho con FastAPI y actua como middleware: autentica usuarios, administra conexiones Wazuh, consulta el Wazuh Indexer por API REST, procesa las vulnerabilidades y las guarda en PostgreSQL/TimescaleDB. La base no guarda solo una foto fija, sino eventos con timestamp para demostrar evolucion: vulnerabilidades detectadas, resueltas y reaparecidas. Ademas, el proyecto tiene pipeline DevSecOps con Jenkins, tests, SonarQube, Quality Gate y OWASP ZAP para la API.

## 30. Frase final recomendada

> Para la primera entrega dejamos implementada una capa funcional de integracion con Wazuh, persistencia historica, visualizacion inicial y un pipeline DevSecOps operativo. La solucion aun tiene deuda tecnica, pero esa deuda esta identificada, medida y alineada con las siguientes entregas.
