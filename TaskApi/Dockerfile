# Этап 1: сборка. В образе SDK восстанавливаем пакеты и публикуем Release-сборку.
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Сначала только .csproj — слой с NuGet-пакетами кешируется, пока не меняются зависимости.
COPY TaskApi.csproj ./
RUN dotnet restore

COPY . ./
RUN dotnet publish -c Release -o /app/publish --no-restore /p:UseAppHost=false

# Этап 2: запуск. Лёгкий runtime-образ ASP.NET без SDK.
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish ./

ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "TaskApi.dll"]
