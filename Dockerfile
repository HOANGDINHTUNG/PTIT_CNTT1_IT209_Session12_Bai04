# ==========================================
# Stage 1: Build application using Gradle
# ==========================================
FROM gradle:8.8-jdk17-alpine AS builder

WORKDIR /app

# Copy Gradle wrapper and project definition files
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./

# Grant execution rights and fetch dependencies
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon || true

# Copy source code and build executable JAR
COPY src src
RUN ./gradlew bootJar -x test --no-daemon

# ==========================================
# Stage 2: Runtime image (Alpine JRE)
# ==========================================
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Security: Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy built JAR from builder stage
COPY --from=builder --chown=appuser:appgroup /app/build/libs/*.jar app.jar

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 8080

# Execute Spring Boot application
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
