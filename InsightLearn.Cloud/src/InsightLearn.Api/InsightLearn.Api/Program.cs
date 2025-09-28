using InsightLearn.Infrastructure.DependencyInjection;
using InsightLearn.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();

// Add Infrastructure Services
builder.Services.AddInfrastructureServices(builder.Configuration);

// Add JWT Authentication
builder.Services.AddJwtAuthentication(builder.Configuration);

// Add OAuth Authentication
builder.Services.AddOAuthAuthentication(builder.Configuration);

// Add Custom Authorization Policies
builder.Services.AddCustomAuthorization();

// Add CORS
builder.Services.AddCorsPolicy(builder.Configuration);

// Add Email Configuration Validation
builder.Services.AddEmailConfiguration(builder.Configuration);

// Add Background Services
builder.Services.AddBackgroundServices();

// Add Swagger with Authentication
builder.Services.AddSwaggerConfiguration();

var app = builder.Build();

// Run database migrations on startup
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    try
    {
        await context.Database.MigrateAsync();
    }
    catch (Exception ex)
    {
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred while migrating the database.");
    }
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "InsightLearn.Cloud API V1");
        c.RoutePrefix = "swagger";
    });

    app.UseCors("DevelopmentPolicy");
}
else
{
    app.UseCors("DefaultPolicy");
}

app.UseHttpsRedirection();

// Authentication & Authorization middleware (order matters!)
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
