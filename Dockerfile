# Etapa 1: Compilación del JAR con Maven y Java 17
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app

# Copiar archivo de configuración de dependencias
COPY pom.xml .

# Descargar dependencias para aprovechar la caché de capas de Docker
RUN mvn dependency:go-offline -B || true

# Copiar el código fuente y compilar el paquete sin pruebas
COPY src ./src
RUN mvn clean package -DskipTests

# Etapa 2: Entorno de ejecución ligero y optimizado
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Copiar el artefacto generado desde la etapa de construcción
COPY --from=builder /app/target/app.jar app.jar

# Render inyecta la variable de entorno PORT en tiempo de ejecución
ENV PORT=8092
EXPOSE 8092

# Comando de arranque optimizado para bajo consumo de RAM en la nube (Render 512MB)
# -Xms192m -Xmx320m: tope estricto de memoria para evitar OutOfMemory (error 502)
# -XX:+UseSerialGC: recolector ligero sin sobrecarga de memoria
# -XX:+TieredCompilation -XX:TieredStopAtLevel=1: reduce uso de CPU y acelera el arranque
ENTRYPOINT ["sh", "-c", "java -Xms192m -Xmx320m -Xss512k -XX:+UseSerialGC -XX:+TieredCompilation -XX:TieredStopAtLevel=1 -Dserver.port=${PORT} -jar app.jar"]

