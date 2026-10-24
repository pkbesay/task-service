# Этап 1: сборка. В образе с Maven и JDK 21 собираем исполняемый jar.
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src

# Сначала только pom.xml - слой с зависимостями кешируется, пока они не меняются.
COPY pom.xml ./
RUN mvn -B -ntp dependency:go-offline

COPY src ./src
RUN mvn -B -ntp package -DskipTests

# Этап 2: запуск. Лёгкий образ только с JRE 21, без Maven и исходников.
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/target/task-api.jar ./app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
