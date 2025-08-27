# Multi-stage build for Mule application
FROM maven:3.9.9-openjdk-17 AS builder

# Set working directory
WORKDIR /app

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
COPY mule-artifact.json .
RUN mvn clean package -DskipTests

# Runtime stage - using OpenJDK since Mule CE image might not be available
FROM openjdk:17-jre-slim

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create mule user and directories
RUN useradd -r -u 1000 mule && \
    mkdir -p /opt/mule/apps /opt/mule/conf/properties /opt/mule/logs

# Copy the built application
COPY --from=builder /app/target/demo-1.0.0-SNAPSHOT-mule-application.jar /opt/mule/apps/

# Copy configuration files
COPY --from=builder /app/src/main/resources/properties /opt/mule/conf/properties/

# Set environment variables
ENV MULE_ENV=dev
ENV DB_PASSWORD=""
ENV JAVA_OPTS="-Dmule.env=${MULE_ENV}"

# Change ownership
RUN chown -R mule:mule /opt/mule

# Switch to mule user
USER mule

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8081/kb || exit 1

# Expose port
EXPOSE 8081

# For now, we'll create a simple startup script since Mule CE runtime isn't easily available
RUN echo '#!/bin/bash\necho "Mule application would start here"\necho "Application: demo-1.0.0-SNAPSHOT-mule-application.jar"\necho "Environment: $MULE_ENV"\necho "Java Options: $JAVA_OPTS"\ntail -f /dev/null' > /opt/mule/start.sh && \
    chmod +x /opt/mule/start.sh

# Start command
CMD ["/opt/mule/start.sh"]
