FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/InsightLearn.Web/InsightLearn.Web/InsightLearn.Web.csproj", "InsightLearn.Web/"]
RUN dotnet restore "InsightLearn.Web/InsightLearn.Web.csproj"
COPY src/ .
WORKDIR "/src/InsightLearn.Web/InsightLearn.Web"
RUN dotnet build "InsightLearn.Web.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "InsightLearn.Web.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "InsightLearn.Web.dll"]
