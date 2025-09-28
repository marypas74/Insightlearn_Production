using MudBlazor.Services;
using InsightLearn.Web.Client.Pages;
using InsightLearn.Web.Components;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents()
    .AddInteractiveWebAssemblyComponents();

// Add MudBlazor services
builder.Services.AddMudServices();

// Add SignalR services
builder.Services.AddSignalR();

// Add notification service
builder.Services.AddScoped<InsightLearn.Web.Services.INotificationService, InsightLearn.Web.Services.NotificationService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseWebAssemblyDebugging();
}
else
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseAntiforgery();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AddInteractiveWebAssemblyRenderMode()
    .AddAdditionalAssemblies(typeof(InsightLearn.Web.Client._Imports).Assembly);

// Map SignalR hubs
app.MapHub<InsightLearn.Web.Hubs.ChatHub>("/chathub");
app.MapHub<InsightLearn.Web.Hubs.NotificationHub>("/notificationhub");

app.Run();
