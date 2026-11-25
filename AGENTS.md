# DIRECTIVAS DE DESARROLLO Y SEGURIDAD - PROYECTO FARMASIS

## 🚨 REGLA CRÍTICA DE BASE DE DATOS (MONGODB ATLAS)
1. **Base de Datos Compartida en Vivo:** La base de datos `l_farma` alojada en MongoDB Atlas es compartida en tiempo real para la exposición del proyecto de aula entre los integrantes del equipo.
2. **PROHIBICIÓN ESTRICTA DE MODIFICAR CREDENCIALES:**
   - Queda estrictamente **PROHIBIDO** ejecutar scripts, comandos o consultas que alteren, reseteen o sobrescriban las contraseñas en la colección `usuarios` de MongoDB Atlas.
   - Las contraseñas de los usuarios no son "semillas de prueba" ni deben cambiarse a valores por defecto (como `Admin123!` o similares).
   - Cualquier creación o modificación de usuarios debe hacerse exclusivamente a través de los módulos oficiales de la interfaz:
     - Web: *Gestión de Usuarios* (`/owner/gestionar-usuarios`).
     - Móvil: *Gestión de Personal* en Flutter.
3. **No Ejecutar Operaciones Destructivas:**
   - Nunca hacer `dropDatabase()`, `drop()` ni eliminar colecciones (`FACTURA`, `PRODUCTOS`, `usuarios`, `proveedores`).
   - La siembra automática está deliberadamente desactivada (`farmasis.database.seed.enabled=false`).

