# Enronda Backoffice

Aplicación backoffice para la gestión de profesionales y eventos de Calendly en Enronda. Permite centralizar la administración de múltiples profesionales, sus tokens de acceso, y la exportación de eventos en diferentes formatos.

## 🚀 Características

- **Gestión de Profesionales**: CRUD completo para profesionales con integración a Calendly
- **Eventos de Calendly**: Visualización y exportación de eventos por profesional o global
- **Autenticación segura**: Sistema de acceso restringido con Devise
- **Exportación CSV**: Descarga de eventos en formato CSV con filtros personalizados
- **Interfaz moderna**: UI con Tailwind CSS y componentes responsivos

## 📋 Requisitos del Sistema

- **Ruby**: 3.1.0
- **Rails**: ~> 7.0.0
- **Node.js**: 22.5.1 (para assets)
- **PostgreSQL**: 9.3+
- **Redis**: Para caché en producción

## ⚙️ Variables de Entorno

Crea un archivo `.env` en la raíz del proyecto con las siguientes variables:

```bash
# Configuración de Calendly OAuth
CALENDLY_CLIENT_ID=tu_client_id_aqui
CALENDLY_CLIENT_SECRET=tu_client_secret_aqui  
CALENDLY_REDIRECT_URI=http://localhost:3000/calendly/callback

# Base de datos (solo producción)
ENRONDA_BACKOFFICE_DATABASE_PASSWORD=tu_password_aqui

# Redis (producción)
REDIS_URL=redis://localhost:6379/0

# Rails (producción)
RAILS_MASTER_KEY=tu_master_key_aqui
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

## 🛠️ Instalación y Configuración

### 1. Clonar el repositorio
```bash
git clone https://github.com/quequeo/enronda-backoffice #[URL_DEL_REPOSITORIO]
cd enronda-backoffice
```

### 2. Instalar dependencias
```bash
# Instalar gems de Ruby
bundle install

# Instalar dependencias de Node.js  
npm install
```

### 3. Configurar la base de datos
```bash
# Crear y configurar la base de datos
rails db:create
rails db:migrate
rails db:seed
```

### 4. Configurar Calendly OAuth

1. Crea una aplicación OAuth en [Calendly Developer Console](https://developer.calendly.com/)
2. Configura la URL de callback: `http://localhost:3000/calendly/callback`
3. Añade las credenciales al archivo `.env`

## 🚦 Desarrollo

### Iniciar el servidor de desarrollo
```bash
# Opción 1: Con Foreman (recomendado)
foreman start -f Procfile.dev

# Opción 2: Manualmente
# Terminal 1 - Servidor Rails
rails server

# Terminal 2 - Watcher de Tailwind CSS
rails tailwindcss:watch
```

La aplicación estará disponible en `http://localhost:3000`

### Credenciales de acceso por defecto
- **Email**: hola@enronda.com
- **Password**: Se configura durante el primer registro

## 🧪 Testing

La aplicación utiliza **RSpec** como framework principal de testing, con soporte para **FactoryBot**, **Shoulda Matchers** y **Database Cleaner**.

### Ejecutar todos los tests
```bash
# Ejecutar toda la suite de tests
bundle exec rspec

# Con formato detallado
bundle exec rspec --format documentation
```

### Ejecutar tests específicos
```bash
# Tests de modelos únicamente
bundle exec rspec spec/models/

# Test de un modelo específico
bundle exec rspec spec/models/user_spec.rb

# Tests de controladores
bundle exec rspec spec/controllers/

# Tests de un archivo específico con número de línea
bundle exec rspec spec/models/user_spec.rb:15
```

### Cobertura de tests actuales
- ✅ **User model**: Validaciones de email restringido, Devise modules, factory
- ✅ **Professional model**: Validaciones de name/token, attributes, factory traits
- ✅ **CalendlyOAuth model**: Atributos, token management, find_or_create_by behavior

### Herramientas de testing configuradas
- **RSpec**: Framework principal de testing
- **FactoryBot**: Para crear objetos de test con datos válidos
- **Shoulda Matchers**: Matchers para validaciones de ActiveRecord y más
- **Database Cleaner**: Limpieza de la base de datos entre tests

### Tests legacy (Minitest)
Los tests originales en formato Minitest siguen disponibles en la carpeta `test/`:
```bash
# Ejecutar tests de Minitest (legacy)
rails test
```

### Smoke Tests y Health Checks
```bash
# Tests de verificación post-deploy
rails smoke_tests:all                 # Verificación completa del sistema
rails smoke_tests:user_flows         # Test de flujos críticos de usuario  
rails smoke_tests:calendly_api       # Test de conectividad con Calendly API
rails health:check                   # Health check para monitoreo
```

## 📊 Uso de la Aplicación

### 1. Gestión de Profesionales
- Navega a `/professionals` para ver la lista de profesionales
- Añade nuevos profesionales con sus tokens de Calendly
- Edita información existente o elimina profesionales

### 2. Integración con Calendly
- Cada profesional necesita un token válido de Calendly
- El sistema actualiza automáticamente la información de organización
- Los tokens se validan en cada consulta

### 3. Visualización de Eventos
- `/calendly/all` - Ver todos los eventos de todos los profesionales
- `/professionals/:id/events` - Ver eventos de un profesional específico
- Filtros disponibles: fecha inicial, fecha final, estado del evento

### 4. Exportación
- `/calendly/all_csv` - Exportar todos los eventos en CSV
- `/professionals/:id/events_csv` - Exportar eventos de un profesional en CSV

## 🐳 Docker

### Desarrollo
```bash
docker build -t enronda-backoffice .
docker run -p 3000:3000 enronda-backoffice
```

## 📁 Estructura del Proyecto

```
app/
├── controllers/           # Controladores de la aplicación
│   ├── calendly_controller.rb
│   └── professionals_controller.rb
├── models/               # Modelos de datos
│   ├── professional.rb
│   ├── user.rb
│   └── calendly_o_auth.rb
├── services/            # Lógica de negocio
│   └── CalendlyService.rb
└── views/               # Plantillas ERB
    ├── professionals/
    ├── calendly/
    └── layouts/

config/                  # Configuración de Rails
├── routes.rb
├── database.yml
└── environments/

test/                    # Tests de la aplicación
├── models/
├── controllers/
└── fixtures/
```

## 🚀 Deployment

### Heroku (Configuración actual)
El proyecto está configurado para deployment en Heroku:

#### Preparación inicial
```bash
# Instalar Heroku CLI
# https://devcenter.heroku.com/articles/heroku-cli

# Login en Heroku
heroku login

# Crear aplicación (si es nueva)
heroku create nombre-de-tu-app

# Configurar Git remote (si no se creó automáticamente)
heroku git:remote -a nombre-de-tu-app
```

#### Configurar variables de entorno
```bash
# Configuración de Calendly
heroku config:set CALENDLY_CLIENT_ID=tu_client_id_aqui
heroku config:set CALENDLY_CLIENT_SECRET=tu_client_secret_aqui
heroku config:set CALENDLY_REDIRECT_URI=https://tu-app.herokuapp.com/calendly/callback

# Base de datos (se configura automáticamente con Heroku Postgres)
# ENRONDA_BACKOFFICE_DATABASE_PASSWORD no es necesario con Heroku Postgres

# Configuración de Rails
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
heroku config:set RAILS_ENV=production
```

#### Configurar add-ons
```bash
# PostgreSQL (si no se ha agregado automáticamente)
heroku addons:create heroku-postgresql:mini

# Redis para caché (opcional)
heroku addons:create heroku-redis:mini
```

#### Deployment Seguro

**⚠️ IMPORTANTE**: Siempre deploy a staging primero

```bash
# 1. Verificar tests localmente
bundle exec rspec
rails smoke_tests:all

# 2. Deploy a staging
git push heroku-staging main
heroku run rails db:migrate --app your-staging-app

# 3. Verificar staging
heroku run rails smoke_tests:all --app your-staging-app
heroku run rails health:check --app your-staging-app

# 4. Testing manual en staging (ver DEPLOY_CHECKLIST.md)

# 5. Solo entonces, deploy a producción
git push heroku main
heroku run rails db:migrate
heroku run rails smoke_tests:all
```

#### Comandos útiles
```bash
# Health check y monitoreo
heroku run rails health:check
heroku run rails smoke_tests:calendly_api

# Administración
heroku open
heroku run rails console
heroku restart

# Debugging
heroku logs --tail
heroku ps

# Rollback si hay problemas
heroku rollback
```

#### Verificación Post-Deploy

**📊 Comandos de Verificación (ejecutar en orden):**
```bash
# 1. Verificar que la aplicación carga
heroku open

# 2. Monitorear logs en tiempo real (dejar corriendo en terminal)
heroku logs --tail

# 3. Ejecutar smoke tests automáticos
heroku run rails smoke_tests:all

# 4. Verificar health check
heroku run rails health:check

# 5. Tests adicionales
heroku run rails smoke_tests:user_flows
heroku run rails smoke_tests:calendly_api  # Solo si hay tokens
```

**👤 Verificación Manual Crítica:**
- ✅ **Login**: Acceder con `hola@enronda.com`
- ✅ **CRUD Profesionales**: Crear/editar/eliminar professional
- ✅ **Listado**: Ver lista de professionals funciona
- ✅ **Eventos**: Cargar events (puede mostrar errores sin tokens - normal)
- ✅ **Export**: Descargar CSV funciona
- ✅ **Logs**: Sin errores críticos en `heroku logs --tail`

**🚨 Si Algo Sale Mal - Rollback Inmediato:**
```bash
# Rollback rápido a versión anterior
heroku rollback

# Verificar que rollback funcionó
heroku open
heroku logs --tail

# Ver historial de releases si necesitas versión específica
heroku releases
heroku rollback v41  # Ejemplo: rollback a release específico
```

**⏰ Timeline de Verificación Recomendado:**
```bash
# Inmediatamente después del deploy (0-2 min)
heroku logs --tail              # Buscar errores inmediatos
heroku open                     # Verificar que carga

# Si hay errores críticos → heroku rollback INMEDIATAMENTE

# Verificación completa (2-10 min) - Solo si no hay errores inmediatos
heroku run rails smoke_tests:all    # Tests automáticos
heroku run rails health:check       # Health status
# + Testing manual básico

# Si encuentras problemas → heroku rollback
```

#### Archivos de Deployment
- 📋 **`DEPLOY_CHECKLIST.md`**: Checklist detallado para deployments seguros
- 🔧 **`lib/tasks/smoke_tests.rake`**: Tasks para verificación post-deploy  
- ❤️ **`lib/tasks/health_check.rake`**: Health checks para monitoreo
- 🧪 **`spec/integration/`**: Tests de integración con APIs reales

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📝 Notas Técnicas

### Limitaciones Actuales
- Acceso restringido a un solo email (`hola@enronda.com`)
- Tokens de Calendly requieren renovación manual
- Sin paginación en listados grandes de eventos

### Mejoras Futuras
- Sistema de roles y permisos más flexible
- Renovación automática de tokens OAuth
- Cache de eventos para mejor rendimiento
- Notificaciones de eventos próximos

## 📞 Soporte

Para soporte técnico o preguntas sobre la aplicación, contacta al equipo de desarrollo de Enronda.
