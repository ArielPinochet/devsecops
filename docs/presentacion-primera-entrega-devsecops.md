# Presentacion Primera Entrega: Dashboard DevSecOps con Wazuh

## 1. Objetivo De La Presentacion

Este documento resume como funciona la aplicacion, como esta construido el pipeline DevSecOps, que partes quedaron operativas, que deuda tecnica existe y como defender tecnicamente las decisiones tomadas.

La idea principal para la presentacion es:

> La aplicacion consume informacion real desde Wazuh, la normaliza, la persiste en una base de datos propia y permite observar el ciclo de vida de las vulnerabilidades en el tiempo. El pipeline de Jenkins valida automaticamente tests, build, analisis estatico con SonarQube, Quality Gate y un escaneo DAST basico con OWASP ZAP.

Esta es la primera entrega, por lo tanto no se debe vender como producto final cerrado. Se debe presentar como una base funcional, integrada y medible, con deuda tecnica identificada y plan de mejora.

## 2. Estado Actual Del Pipeline

El pipeline ya llega a:

```text
Finished: SUCCESS
```

Esto significa que Jenkins pudo ejecutar el flujo completo sin cortar el proceso.

Quedo OK:

- Backend CI: `49 passed`.
- Frontend CI/build: paso.
- SonarQube SAST: paso correctamente.
- Quality Gate: `OK`.
- ZAP API DAST: corrio contra `http://api:8000/openapi.json`.
- Jenkins ya usa el token correcto de SonarQube.
- SonarQube esta conectado y procesando el proyecto `vuln-app`.

Lo mas importante: ya no falla por SonarQube. El flujo `CI -> SAST -> Quality Gate -> DAST` quedo operativo.

## 3. Ojo Con Esto

Hay una deuda importante en DAST frontend:

```text
Job spider failed to access URL http://frontend:80
frontend: Temporary failure in name resolution
```

El pipeline termino en `SUCCESS` porque el script permite que ZAP no corte el build cuando encuentra advertencias o cuando la fase frontend falla de forma controlada:

```bash
-I || echo "ZAP Frontend finalizo"
```

Entonces:

- ZAP backend si escaneo.
- ZAP frontend no fue realmente escaneado.
- El pipeline es funcional, pero el DAST frontend queda como deuda tecnica.

Estimacion honesta:

```text
Validez del pipeline actual: 80-85%
Validez CI + SonarQube + Quality Gate: 95%
Validez DAST completo: 65-70%, porque frontend no resuelve DNS
```

## 4. Como Funciona El Pipeline

El pipeline esta definido en:

```text
dev-tools/jenkins/Jenkinsfile
```

Flujo general:

1. Jenkins clona el repo desde GitHub.
2. Levanta backend en Docker y corre `pytest`.
3. Construye frontend y ejecuta coverage.
4. Levanta SonarQube si no esta arriba.
5. Ejecuta `sonar-scanner` contra `http://sonarqube:9000`.
6. Espera el resultado del Quality Gate via API.
7. Levanta una app temporal `jenkins-dast`.
8. Ejecuta OWASP ZAP contra la API.
9. Intenta escanear frontend, pero ahi esta fallando la resolucion `frontend`.

## 5. Conceptos Clave Para Defender

### Commit

Un commit es un punto de control del codigo fuente. Representa un cambio versionado, con autor, fecha y mensaje.

En este proyecto, el commit es importante porque Jenkins obtiene el `Jenkinsfile` y el codigo desde GitHub. Si un cambio no esta commiteado y pusheado, Jenkins no lo ejecuta.

Respuesta corta para el profesor:

> El commit deja trazabilidad de los cambios y permite que el pipeline ejecute exactamente una version conocida del proyecto.

### Push

El push envia los commits locales al repositorio remoto, en este caso GitHub.

Jenkins esta configurado para leer desde:

```text
https://github.com/Je4nnnn/devsecops
```

Por eso, para que Jenkins use cambios nuevos, esos cambios deben estar en GitHub.

### Build

Build es el proceso de construir una version ejecutable o desplegable de la aplicacion.

En este proyecto incluye:

- instalar dependencias,
- correr pruebas,
- generar cobertura,
- construir imagenes Docker,
- compilar el frontend Vue,
- preparar contenedores para pruebas.

Respuesta corta:

> El build confirma que el codigo puede transformarse en una aplicacion ejecutable y reproducible.

### Gate

Un gate es una compuerta de control. Decide si el pipeline puede continuar o debe detenerse.

En este proyecto el gate principal es el Quality Gate de SonarQube.

Ejemplo:

```text
Quality Gate: OK
```

Significa que el codigo cumplio las reglas minimas configuradas en SonarQube.

Respuesta corta:

> Un gate es una validacion automatica que protege la rama o el despliegue. Si no se cumple, el pipeline falla.

### Quality Gate

El Quality Gate es una politica de calidad. SonarQube evalua metricas como:

- bugs,
- vulnerabilidades,
- code smells,
- duplicacion,
- cobertura,
- deuda tecnica,
- mantenibilidad.

En este proyecto, Jenkins espera el resultado del Quality Gate antes de avanzar a DAST.

### Jenkins

Jenkins es el orquestador del pipeline.

No hace todo por si mismo. Su funcion es coordinar herramientas:

- Docker,
- pytest,
- npm,
- SonarQube,
- OWASP ZAP,
- scripts del proyecto.

Respuesta corta:

> Jenkins automatiza el flujo DevSecOps. Permite que cada cambio pase por pruebas, analisis y controles de seguridad antes de considerarse valido.

### SonarQube

SonarQube es una herramienta de analisis estatico de codigo, tambien conocida como SAST.

SAST significa:

```text
Static Application Security Testing
```

Analiza el codigo sin ejecutarlo. Busca problemas como:

- bugs,
- vulnerabilidades,
- malas practicas,
- duplicacion,
- deuda tecnica,
- problemas de mantenibilidad.

En este proyecto se uso para analizar backend Python y frontend JavaScript/Vue.

### SAST

SAST es seguridad en etapa temprana. Se alinea con el modelo `shift-left`, porque revisa el codigo antes de produccion.

Respuesta corta:

> SAST permite encontrar problemas de seguridad y calidad antes de ejecutar o desplegar la aplicacion.

### OWASP ZAP

OWASP ZAP es una herramienta DAST.

DAST significa:

```text
Dynamic Application Security Testing
```

A diferencia de SAST, DAST analiza la aplicacion en ejecucion. Hace peticiones HTTP y busca problemas desde fuera, como lo haria un atacante o scanner web.

En este proyecto:

- ZAP escaneo la API usando el OpenAPI de FastAPI.
- Detecto 2 advertencias informativas:
  - `X-Content-Type-Options Header Missing`.
  - `Cross-Origin-Resource-Policy Header Missing or Invalid`.
- No detecto fallos criticos en la API.

### Trivy

Trivy es una herramienta para escanear contenedores, imagenes Docker, dependencias, IaC y vulnerabilidades conocidas.

Actualmente no esta integrado. Queda como deuda tecnica y mejora futura.

Uso futuro propuesto:

```text
Jenkins -> Trivy -> escaneo de imagen backend/frontend -> gate de severidad
```

Ejemplo de regla futura:

> Si Trivy encuentra vulnerabilidades Critical o High sin justificar, el pipeline falla.

### SCA

SCA significa:

```text
Software Composition Analysis
```

Analiza dependencias de terceros, por ejemplo paquetes de `npm` o `pip`.

Herramientas posibles:

- Snyk.
- OWASP Dependency-Check.
- npm audit.
- pip-audit.

Actualmente no esta integrado formalmente. Es deuda tecnica.

## 6. Base De Datos

La app tiene dos capas:

### 6.1. Capa Legacy / Operativa

Tablas principales:

- `wazuh_connections`: conexiones al Wazuh Indexer.
- `wazuh_vulnerabilities`: estado actual de vulnerabilidades.
- `vulnerability_history`: historial de cambios como `DETECTED`, `RESOLVED`, `REOPENED`.

Esta capa permite operar la aplicacion actual:

- guardar conexiones Wazuh,
- sincronizar vulnerabilidades,
- saber si una vulnerabilidad esta activa o resuelta,
- consultar historial.

### 6.2. Capa Evolutiva Nueva

Tablas principales:

- `managers`: representa servidores Wazuh.
- `assets`: agentes/servidores monitoreados.
- `vulnerability_catalog`: catalogo CVE sin duplicar descripciones.
- `vulnerability_detections`: eventos temporales con `timestamp`, `asset_id`, `cve_id`, `status`, paquete y version.

Esto calza con el diseno del PDF: infraestructura, catalogo de vulnerabilidades y eventos de deteccion.

La tabla clave es:

```text
vulnerability_detections
```

Porque permite ver evolucion temporal.

## 7. Justificacion Del Diseno De Base De Datos

El profesor pidio que la aplicacion no sea solo una foto fija. Debe permitir observar el ciclo de vida de las vulnerabilidades.

Por eso el diseno separa:

1. Infraestructura:
   - managers,
   - assets.

2. Catalogo:
   - vulnerability_catalog.

3. Eventos:
   - vulnerability_detections.

Esta separacion evita duplicar informacion y permite consultar evolucion historica.

Ejemplo:

Una misma CVE puede aparecer en muchos servidores. Si se guardara la descripcion completa en cada registro, la base se inflaria innecesariamente. Por eso se guarda una vez en `vulnerability_catalog` y luego se referencia desde los eventos.

El campo `timestamp` permite responder:

- cuando aparecio una vulnerabilidad,
- si sigue activa,
- cuando desaparecio,
- si reaparecio,
- cuanto tiempo permanecio activa.

Respuesta corta:

> El diseno de la base separa infraestructura, catalogo y eventos de deteccion. Esto permite historizar vulnerabilidades sin duplicar datos innecesarios y habilita consultas de evolucion temporal.

## 8. Cumplimiento Segun Los Documentos

### Entrega 1: Capa De Integracion

Cumple bastante bien.

Requisitos:

- Autenticacion con API de Wazuh.
- Consumo de endpoint de vulnerabilidades.
- Persistencia local.
- Middleware API funcional.

Estado:

- Hay conexion con Wazuh Indexer.
- Hay prueba de conexion.
- Hay persistencia local en PostgreSQL/TimescaleDB.
- Hay backend FastAPI.
- Las credenciales de Wazuh se guardan cifradas en la aplicacion.

### Entrega 2: Analisis De Evolucion

Cumple parcialmente/bien, aunque no es la entrega principal actual.

Ya detecta:

- vulnerabilidades nuevas,
- persistentes,
- resueltas,
- re-aparecidas,
- cambios de severidad.

Endpoints:

```text
/vulns/evolution/summary
/vulns/evolution/weekly
/vulns/evolution/top-assets
```

### Entrega 3: Visualizacion Y Despliegue

Cumple parcialmente/bien.

Existe:

- frontend Vue,
- dashboard,
- timeline,
- Docker Compose,
- Jenkins pipeline.

Falta fortalecer:

- heatmaps,
- graficos de areas apiladas,
- DAST frontend,
- escaneo de contenedores con Trivy,
- SCA de dependencias.

## 9. Modelo DevSecOps Del Proyecto

DevSecOps integra desarrollo, operaciones y seguridad.

La idea central es que la seguridad no se agrega al final, sino que se incorpora desde el pipeline.

En este proyecto:

- Desarrollo: codigo backend/frontend.
- Operaciones: Docker, Docker Compose, Jenkins.
- Seguridad: SonarQube, OWASP ZAP, manejo de tokens, autenticacion.

### Shift-Left

Antes se usaba seguridad reactiva: se desplegaba y despues se buscaban problemas.

Con `shift-left`, se revisa antes:

- durante el commit,
- durante el build,
- durante el pipeline,
- antes de llegar a produccion.

Ejemplo del proyecto:

SonarQube revisa el codigo antes de que el sistema sea considerado valido.

### Responsabilidad Compartida

En DevSecOps la seguridad no es solo responsabilidad de un equipo.

Participan:

- desarrolladores,
- operaciones,
- seguridad,
- lider de proyecto,
- usuarios que definen requisitos.

Respuesta corta:

> DevSecOps distribuye la responsabilidad. Si una vulnerabilidad llega a produccion, no es solo culpa de seguridad; tambien falla el proceso, el pipeline, las revisiones y las decisiones tecnicas.

## 10. Como Se Usa La Aplicacion

Flujo normal:

1. El usuario entra al frontend.
2. Inicia sesion.
3. Configura una conexion Wazuh.
4. Prueba la conexion.
5. Sincroniza vulnerabilidades.
6. El backend consulta Wazuh Indexer.
7. La aplicacion normaliza los datos.
8. Se guardan vulnerabilidades actuales e historicas.
9. El dashboard muestra resumen, filtros y timeline.

### Conexion Wazuh

La aplicacion no lee desde el dashboard visual de Wazuh.

Consulta el Wazuh Indexer, que es donde Wazuh almacena documentos de vulnerabilidades.

Flujo:

```text
Frontend -> Backend FastAPI -> Wazuh Indexer -> Base local -> Dashboard
```

## 11. Como Funciona La Sincronizacion

Cuando se ejecuta una sincronizacion:

1. El backend llama a Wazuh.
2. Recibe vulnerabilidades.
3. Por cada vulnerabilidad:
   - identifica agente,
   - identifica paquete,
   - identifica CVE,
   - normaliza severidad,
   - guarda o actualiza la vulnerabilidad.
4. Si una vulnerabilidad ya no viene en la respuesta de Wazuh, se marca como `RESOLVED`.
5. Si una vulnerabilidad resuelta vuelve a aparecer, se marca como `REOPENED` o `Re-emerged`.
6. Se registra un evento temporal en `vulnerability_detections`.

Esto permite saber no solo que existe una vulnerabilidad, sino tambien como evoluciona.

## 12. Deuda Tecnica Actual

Deuda tecnica principal:

- ZAP frontend no escanea realmente por error DNS interno.
- No hay Trivy todavia para contenedores.
- No hay SCA tipo Snyk/Dependency-Check.
- `vulnerability_detections` usa timestamp, pero no se confirmo una migracion explicita para convertirla en hypertable TimescaleDB.
- No hay RBAC fuerte por roles/grupos; hay autenticacion, pero no permisos finos.
- `api_key_vault_ref` existe como concepto, pero no hay Vault real.
- El frontend todavia calcula bastante para timeline; idealmente mas procesamiento deberia quedar en backend.
- La contrasena admin inicial y algunas credenciales operativas todavia dependen de configuracion manual.

## 13. Comparativa De Deuda Tecnica Por Presentacion

### Primera Entrega

Objetivo: demostrar integracion funcional.

Estado:

- Conexion Wazuh funcional.
- Persistencia local funcional.
- Pipeline Jenkins funcional.
- SonarQube funcional.
- Quality Gate funcional.
- DAST API funcional.

Deuda aceptable:

- DAST frontend.
- Trivy.
- SCA.
- RBAC avanzado.
- Vault real.
- automatizacion completa de despliegue.

Porcentaje estimado de madurez:

```text
80-85%
```

### Segunda Entrega

Objetivo esperado: evolucion y filtros mas fuertes.

Se deberia mejorar:

- filtros por criticidad,
- filtros por red,
- filtros por CVE,
- filtros por sistema operativo,
- dwell time,
- metricas de tendencia,
- endpoints mas especificos para visualizacion.

Porcentaje objetivo:

```text
88-92%
```

### Tercera Entrega

Objetivo esperado: visualizacion, despliegue y seguridad mas completa.

Se deberia agregar:

- Trivy,
- SCA,
- DAST frontend corregido,
- heatmaps,
- graficos mas robustos,
- RBAC,
- hardening de headers,
- documentacion de despliegue,
- posible pipeline de herramientas.

Porcentaje objetivo:

```text
92-96%
```

## 14. Que Es Un Pipeline Solo De Herramientas

Un pipeline solo de herramientas seria un flujo separado que no necesariamente despliega la app, sino que ejecuta validaciones de seguridad.

Ejemplo futuro:

```text
Checkout
-> SonarQube
-> Trivy
-> Dependency-Check / Snyk
-> OWASP ZAP
-> Reporte consolidado
```

Ventaja:

- separa validacion de seguridad del build principal,
- permite correr auditorias bajo demanda,
- facilita comparar deuda tecnica entre entregas,
- permite presentar avances de seguridad por herramienta.

## 15. Microservicios Y Arquitectura

Por ahora el proyecto corre localmente con Docker Compose.

No esta subido a nube y no necesita estarlo para esta primera entrega.

La arquitectura actual separa servicios:

- `frontend`: Vue servido por Nginx.
- `api`: FastAPI.
- `db-api`: PostgreSQL/TimescaleDB.
- `sonarqube`: analisis estatico.
- `db-sonar`: base de datos de SonarQube.
- Jenkins como orquestador local.

Esto no es una arquitectura de microservicios completa orientada a eventos, pero si esta contenedorizada y separada por responsabilidades.

Evolucion futura hacia microservicios:

- servicio de ingesta Wazuh,
- servicio de procesamiento historico,
- servicio de visualizacion/API,
- eventos cuando una vulnerabilidad cambia de estado.

Respuesta corta:

> Hoy usamos una arquitectura local contenedorizada. La evolucion natural seria separar ingesta, procesamiento y visualizacion como microservicios orientados a eventos.

## 16. Arquitectura Utilizada Y Justificacion

### 16.1. Vista General

La arquitectura actual es una aplicacion web contenedorizada, con separacion clara entre frontend, backend, base de datos, herramientas de calidad y herramientas de seguridad.

Diagrama logico:

```text
Usuario
  |
  v
Frontend Vue/Nginx
  |
  v
Backend FastAPI
  |
  +---------------------> Wazuh Indexer/API
  |
  v
PostgreSQL/TimescaleDB

Pipeline:

GitHub -> Jenkins -> Tests -> Build -> SonarQube -> Quality Gate -> OWASP ZAP
```

Componentes principales:

- `frontend`: interfaz web en Vue.
- `api`: backend en FastAPI.
- `db-api`: PostgreSQL/TimescaleDB para persistencia historica.
- `sonarqube`: plataforma de analisis estatico.
- `db-sonar`: base de datos propia de SonarQube.
- `jenkins`: orquestador CI/CD.
- `zap`: scanner DAST ejecutado desde contenedores.

### 16.2. Por Que FastAPI

Se eligio FastAPI porque:

- es liviano,
- permite crear APIs REST rapidamente,
- genera documentacion OpenAPI automaticamente,
- se integra bien con OWASP ZAP para escanear endpoints,
- tiene buen soporte para autenticacion JWT,
- funciona bien en contenedores.

Justificacion para el profesor:

> FastAPI permite construir un middleware claro entre Wazuh y el dashboard. Ademas, su OpenAPI facilita pruebas, documentacion y escaneo DAST.

### 16.3. Por Que Vue

Se uso Vue para el frontend porque:

- permite construir dashboards interactivos,
- separa componentes visuales,
- es adecuado para filtros, tablas y timeline,
- se puede servir como sitio estatico desde Nginx,
- se integra bien con APIs REST.

Justificacion:

> Vue permite construir una experiencia de visualizacion dinamica sin acoplar la interfaz a la logica de ingesta o procesamiento.

### 16.4. Por Que PostgreSQL/TimescaleDB

El proyecto necesita historizar vulnerabilidades. No basta con almacenar el ultimo estado.

PostgreSQL da:

- confiabilidad relacional,
- integridad referencial,
- consultas SQL,
- soporte para indices,
- tipos utiles como `INET`.

TimescaleDB agrega:

- manejo eficiente de series de tiempo,
- `time_bucket`,
- mejor rendimiento para eventos historicos,
- posibilidad de convertir `vulnerability_detections` en hypertable.

Justificacion:

> Como el problema es temporal, necesitamos registrar eventos de deteccion en el tiempo. PostgreSQL/TimescaleDB permite modelar infraestructura, catalogo CVE y eventos historicos de forma ordenada.

### 16.5. Por Que Docker Compose

Docker Compose permite levantar el sistema localmente con servicios reproducibles.

Ventajas:

- todos ejecutan la misma configuracion,
- se reduce el "en mi maquina funciona",
- facilita Jenkins porque el pipeline puede crear servicios temporales,
- permite aislar base de datos, API y frontend.

Justificacion:

> Para una primera entrega local, Docker Compose es suficiente y pragmatico. Permite reproducibilidad sin necesidad de Kubernetes o nube.

### 16.6. Por Que Jenkins

Jenkins se usa para orquestar el pipeline.

Ventajas:

- ejecuta pasos en orden,
- automatiza pruebas,
- ejecuta herramientas de seguridad,
- permite gates,
- deja historial de builds,
- se integra con Docker.

Justificacion:

> Jenkins no es la herramienta de seguridad, sino el orquestador que une build, pruebas y controles DevSecOps.

### 16.7. Por Que SonarQube

SonarQube se usa porque permite SAST y medicion de calidad.

Facilita:

- detectar bugs,
- detectar vulnerabilidades,
- medir deuda tecnica,
- evaluar mantenibilidad,
- aplicar Quality Gate.

Justificacion:

> SonarQube implementa el control de calidad automatizado. Permite que el pipeline no dependa solo de que el codigo compile, sino tambien de que tenga un nivel minimo de calidad.

### 16.8. Por Que OWASP ZAP

ZAP se usa para DAST.

Facilita:

- probar la aplicacion ejecutandose,
- detectar problemas HTTP,
- revisar headers,
- escanear API usando OpenAPI,
- simular una mirada externa sobre la aplicacion.

Justificacion:

> ZAP complementa SonarQube. SonarQube mira codigo; ZAP mira comportamiento de la aplicacion en ejecucion.

### 16.9. Por Que No Nube Todavia

No se subio a nube porque la primera entrega se enfoca en:

- integracion,
- normalizacion,
- persistencia,
- pipeline basico,
- demostracion local reproducible.

Subir a nube agrega complejidad:

- redes,
- dominios,
- certificados,
- costos,
- seguridad perimetral,
- gestion de secretos,
- despliegue automatizado.

Decision:

> Para esta etapa se priorizo una arquitectura local contenedorizada. La nube queda como evolucion, no como requisito de la primera entrega.

### 16.10. Como Evolucionaria A Microservicios

La app actual esta separada por servicios Docker, pero no es todavia una arquitectura de microservicios orientada a eventos completa.

Evolucion propuesta:

```text
Servicio de ingesta Wazuh
  -> Evento: vulnerability.detected
  -> Evento: vulnerability.resolved
  -> Evento: vulnerability.reemerged

Servicio de procesamiento historico
  -> calcula dwell time
  -> calcula tendencias
  -> prepara datos para dashboard

Servicio API/visualizacion
  -> expone endpoints al frontend
```

Esto permitiria:

- escalar ingesta separada del frontend,
- procesar multiples Wazuh Managers,
- tolerar caidas de un manager,
- procesar eventos en cola,
- separar responsabilidades.

Para esta entrega no se implemento porque habria aumentado demasiado la complejidad.

## 17. Conexion Con El Wazuh Del Profesor

### 17.1. Que Se Necesita Saber

Para conectar la app al Wazuh del profesor se necesitan datos concretos:

- URL o IP del Wazuh Indexer.
- Puerto del Indexer, normalmente `9200`.
- Protocolo: normalmente `https`.
- Usuario y contrasena o token autorizado.
- Certificado CA si usa TLS con certificado interno.
- Si la red requiere VPN.
- Si el servidor permite conexiones desde la IP del equipo del alumno.
- Que indices se pueden consultar.

La app actualmente espera una URL tipo:

```text
https://IP_O_HOST_DEL_WAZUH:9200
```

### 17.2. Que Significa Lo De VPN

VPN significa Virtual Private Network.

En terminos simples:

> Una VPN permite que tu computador entre logicamente a una red privada donde esta el servidor Wazuh del profesor.

Si Wazuh esta dentro de una red universitaria o de laboratorio, probablemente no es accesible desde Internet directamente. La VPN crea un tunel seguro para que tu equipo pueda llegar a esa IP privada.

Ejemplo:

```text
Notebook alumno
  |
  | VPN
  v
Red interna del profesor
  |
  v
Servidor Wazuh
```

Sin VPN, puede pasar esto:

```bash
curl https://IP_WAZUH:9200
```

y fallar por:

- timeout,
- host unreachable,
- connection refused,
- DNS no resuelve.

Con VPN, esa misma IP podria responder.

### 17.3. Pruebas Manuales Antes De Configurar La App

Primero probar conectividad desde la maquina donde corre Docker:

```bash
ping IP_DEL_WAZUH
```

Luego probar puerto:

```bash
nc -vz IP_DEL_WAZUH 9200
```

Si `nc` no esta instalado:

```bash
curl -k https://IP_DEL_WAZUH:9200
```

Probar autenticacion:

```bash
curl -k -u usuario:password https://IP_DEL_WAZUH:9200
```

Si responde JSON del cluster, hay conectividad.

Luego probar el indice de vulnerabilidades:

```bash
curl -k -u usuario:password \
  "https://IP_DEL_WAZUH:9200/wazuh-states-vulnerabilities-*/_search?size=1"
```

### 17.4. Configuracion En La App

En el frontend:

1. Entrar a la app.
2. Ir a configuracion Wazuh.
3. Crear una conexion.
4. Usar:

```text
Nombre: Wazuh Profesor
Indexer URL: https://IP_DEL_WAZUH:9200
Usuario: usuario_entregado
Password: password_entregado
```

5. Presionar probar conexion.
6. Si funciona, sincronizar.

### 17.5. Ajustes Que Podrian Ser Necesarios En Codigo

#### Certificados TLS

Actualmente la app puede funcionar con `verify=False` si el cliente Wazuh esta configurado asi, pero para una conexion seria deberia soportar CA configurable.

Mejora recomendada:

- agregar campo `ca_cert_path` o `verify_tls`,
- permitir subir/usar certificado CA,
- evitar desactivar TLS en produccion.

#### Timeout Y Reintentos

Si el Wazuh del profesor esta en VPN, puede haber latencia.

Mejora recomendada:

- timeout configurable,
- reintentos controlados,
- mensajes de error claros.

#### Paginacion

El profesor hablo de muchos registros. Si hay 150.000 vulnerabilidades, no conviene traer todo sin control.

Mejora recomendada:

- usar `scroll` o `search_after` en Wazuh Indexer,
- procesar por lotes,
- guardar progreso de sincronizacion,
- evitar timeouts.

#### Permisos Del Usuario Wazuh

No conviene usar usuario admin general.

Mejora recomendada:

- crear usuario de solo lectura,
- limitarlo a indices de vulnerabilidades,
- rotar credenciales.

#### VPN Dentro De Docker

Aunque el host tenga VPN, a veces los contenedores no enrutan igual.

Prueba:

```bash
docker run --rm curlimages/curl:8.12.1 -k https://IP_DEL_WAZUH:9200
```

Si desde el host funciona pero desde Docker no, hay que revisar:

- DNS,
- rutas,
- firewall,
- modo de red Docker,
- si la VPN bloquea trafico de contenedores.

Soluciones posibles:

- usar `network_mode: host` para la API en entorno local controlado,
- configurar rutas de Docker,
- exponer proxy local en el host,
- pedir al profesor habilitar acceso desde la red Docker/host.

#### Variables De Entorno

Para evitar hardcodear datos:

```text
WAZUH_INDEXER_URL
WAZUH_USER
WAZUH_PASSWORD
WAZUH_CA_CERT
WAZUH_VERIFY_TLS
```

La app hoy permite guardar conexion desde UI, pero para despliegue formal conviene permitir configuracion por variables o secrets.

### 17.6. Checklist Para Conectar Al Wazuh Del Profesor

Preguntar al profesor:

- Cual es la IP o DNS del Wazuh Indexer?
- Que puerto se debe usar?
- Requiere VPN?
- Que cliente VPN se usa?
- Entregara usuario/password o token?
- El usuario tiene permisos sobre `wazuh-states-vulnerabilities-*`?
- Hay certificado CA?
- Desde que red/IP permitira conexiones?

Validar en terminal:

```bash
curl -k https://IP_DEL_WAZUH:9200
curl -k -u usuario:password https://IP_DEL_WAZUH:9200
curl -k -u usuario:password "https://IP_DEL_WAZUH:9200/wazuh-states-vulnerabilities-*/_search?size=1"
```

Validar desde Docker:

```bash
docker run --rm curlimages/curl:8.12.1 -k https://IP_DEL_WAZUH:9200
```

Configurar en app:

```text
Indexer URL: https://IP_DEL_WAZUH:9200
Usuario: usuario_entregado
Password: password_entregado
```

Probar conexion y sincronizar.

### 17.7. Respuesta Corta Si Preguntan Por La VPN

> Si el Wazuh del profesor esta en una red privada, necesitamos conectarnos por VPN para que nuestra maquina tenga ruta hacia ese servidor. Primero validamos conectividad desde el host, luego desde Docker, y finalmente configuramos la URL del Indexer en la app.

## 18. Preguntas Probables Del Profesor

### Que hace SonarQube en su pipeline?

Analiza codigo estatico de backend y frontend. Busca bugs, vulnerabilidades, code smells y deuda tecnica. Jenkins no avanza al Quality Gate hasta que SonarQube termina el analisis.

### Que es el Quality Gate?

Es una compuerta de calidad. Si el proyecto no cumple las reglas configuradas, el pipeline falla.

### Que hace OWASP ZAP?

Hace DAST. Escanea la aplicacion en ejecucion desde fuera. En este proyecto escanea la API usando OpenAPI.

### Por que el pipeline dice SUCCESS si ZAP frontend fallo?

Porque el script maneja esa etapa como no bloqueante. Eso se hizo para no cortar la primera entrega por una deuda tecnica conocida. Se declara como deuda: el backend DAST si corre, el frontend DAST debe corregirse.

### Que hace Jenkins?

Orquesta todas las herramientas. Jenkins no reemplaza SonarQube ni ZAP; los ejecuta en orden y decide si el pipeline continua.

### Que hace Docker Compose?

Levanta servicios necesarios de forma reproducible: API, base de datos, frontend, SonarQube y servicios temporales para DAST.

### Por que usan base local si Wazuh ya tiene datos?

Porque el proyecto necesita historizar, normalizar y analizar evolucion. Wazuh entrega datos, pero la app necesita su propio modelo para calcular ciclo de vida, filtros y visualizaciones.

### Por que se necesita timestamp?

Porque sin timestamp solo se sabe el estado actual. Con timestamp se puede saber cuando aparecio, cuando desaparecio y cuanto tiempo estuvo activa una vulnerabilidad.

### Que significa deuda tecnica?

Son decisiones o pendientes tecnicos que permiten avanzar ahora, pero deben resolverse para mejorar seguridad, mantenibilidad o completitud.

### Que falta para produccion?

RBAC fuerte, secrets manager real, Trivy, SCA, DAST frontend corregido, hardening de headers, migraciones robustas, respaldos y despliegue automatizado.

## 19. Resumen Para Defender

Tu app ya no es una foto fija. Ahora toma datos desde Wazuh, los normaliza, los persiste y registra eventos con timestamp para reconstruir evolucion: detectada, resuelta o reaparecida. Ademas, el pipeline valida codigo, tests, cobertura, analisis estatico con SonarQube, Quality Gate y DAST basico con ZAP.

La respuesta honesta es:

> Funciona y cumple la base del proyecto, con deuda tecnica controlada en DAST frontend, escaneo de contenedores/SCA y endurecimiento de permisos/secretos.

## 20. Checklist Para La Presentacion

Antes de presentar:

- Verificar que Jenkins este en `http://localhost:8081`.
- Verificar SonarQube en `http://localhost:9000`.
- Confirmar credencial Jenkins `sonar-token`.
- Correr pipeline y mostrar `Finished: SUCCESS`.
- Mostrar `Quality Gate: OK`.
- Mostrar que backend y frontend tests pasan.
- Mostrar dashboard de SonarQube.
- Mostrar app funcionando.
- Explicar deuda tecnica sin esconderla.

Comandos utiles:

```bash
curl http://localhost:9000/api/system/status
docker ps
git log --oneline -5
```

Validacion esperada de SonarQube:

```json
{"status":"UP"}
```

## 21. Frase Final Recomendada

> Para la primera entrega, dejamos implementada una capa funcional de integracion con Wazuh, persistencia historica, visualizacion inicial y un pipeline DevSecOps operativo. La solucion aun tiene deuda tecnica, pero esa deuda esta identificada, medida y alineada con las siguientes entregas.
