FROM maven:3.9.15-eclipse-temurin-26 AS build
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
RUN mvn --batch-mode --no-transfer-progress verify
# CA oficial de RDS para verificar identidad del servidor PostgreSQL.
RUN curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
    https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /workspace/rds-ca.pem \
    && test -s /workspace/rds-ca.pem
RUN mkdir -p /workspace/tmp && chmod 1777 /workspace/tmp
FROM gcr.io/distroless/java21-debian13:nonroot
WORKDIR /app
COPY --from=build --chown=nonroot:nonroot /workspace/target/solicitudes.jar /app/app.jar
COPY --from=build /workspace/rds-ca.pem /app/rds-ca.pem
COPY --from=build --chown=65532:65532 /workspace/tmp /tmp
VOLUME ["/tmp"]
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75.0","-Djava.io.tmpdir=/tmp","-jar","/app/app.jar"]
