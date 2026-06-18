# ============================================================
# Stage 1: Build frontend (Vue 3 / Vite)
# ============================================================
FROM node:22-slim AS frontend-build

WORKDIR /workspace/frontend
COPY frontend/package.json frontend/package-lock.json* ./
RUN npm ci --prefer-offline

COPY frontend/ ./
RUN npm run build-only


# ============================================================
# Stage 2: Build backend (Gradle / Spring Boot)
# ============================================================
FROM eclipse-temurin:17-jdk-jammy AS backend-build

WORKDIR /workspace

COPY gradlew gradlew.bat settings.gradle jifa.gradle version ./
COPY gradle/ gradle/

COPY common/ common/
COPY analysis/ analysis/
COPY server/ server/
COPY frontend/frontend.gradle frontend/frontend.gradle

COPY --from=frontend-build /workspace/frontend/dist \
     server/src/main/resources/static/

RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew :server:bootJar \
        -x :frontend:npmInstall \
        -x :frontend:buildFrontend \
        -x test \
        --no-daemon \
    && mkdir -p server/build/dependency \
    && (cd server/build/dependency && jar -xf ../libs/jifa.jar)


# ============================================================
# Stage 3: Minimal runtime image
# ============================================================
FROM eclipse-temurin:17-jre-jammy

LABEL org.opencontainers.image.title="Eclipse Jifa" \
      org.opencontainers.image.description="Java heap dump, GC log, thread dump analyser" \
      org.opencontainers.image.source="https://github.com/eclipse-jifa/jifa"

RUN groupadd -r jifa && useradd -r -g jifa -d /jifa -s /bin/false jifa

WORKDIR /jifa

ARG DEPENDENCY=/workspace/server/build/dependency
COPY --from=backend-build ${DEPENDENCY}/BOOT-INF/lib     /jifa/lib
COPY --from=backend-build ${DEPENDENCY}/META-INF         /jifa/META-INF
COPY --from=backend-build ${DEPENDENCY}/BOOT-INF/classes /jifa

# chown before VOLUME – changes after VOLUME declaration are discarded
RUN mkdir -p /jifa-storage && chown jifa:jifa /jifa-storage
VOLUME /jifa-storage

USER jifa

EXPOSE 8102

ENTRYPOINT ["java", \
  "--add-opens=java.base/java.lang=ALL-UNNAMED", \
  "--add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED", \
  "-Djdk.util.zip.disableZip64ExtraFieldValidation=true", \
  "-cp", "/jifa:/jifa/lib/*", \
  "org.eclipse.jifa.server.Launcher"]

# Override at runtime, e.g.:
#   -e JIFA_ALLOW_LOGIN=true
#   -e SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_KEYCLOAK_CLIENT_ID=jifa
#   -e SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_KEYCLOAK_CLIENT_SECRET=secret
#   -e SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_KEYCLOAK_ISSUER_URI=https://kc.example.com/realms/myrealm
CMD ["--jifa.storage-path=/jifa-storage", "--server.port=8102"]
