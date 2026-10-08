using System.Net;
using Azure.Extensions.AspNetCore.Configuration.Secrets;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Azure.Cosmos;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;
using todo;

var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsProduction())
{
    var keyVaultUri = builder.Configuration["KeyVaultUri"];
    var keyVaultName = builder.Configuration["KeyVaultName"];

    if (string.IsNullOrWhiteSpace(keyVaultUri) && !string.IsNullOrWhiteSpace(keyVaultName))
    {
        keyVaultUri = $"https://{keyVaultName}.vault.azure.net/";
    }

    if (!string.IsNullOrWhiteSpace(keyVaultUri))
    {
        var secretClient = new SecretClient(new Uri(keyVaultUri), new DefaultAzureCredential());
        builder.Configuration.AddAzureKeyVault(secretClient, new KeyVaultSecretManager());
    }
}

var tenantId = builder.Configuration["AzureAd:TenantId"];
if (string.Equals(tenantId, "common", StringComparison.OrdinalIgnoreCase)
    || string.Equals(tenantId, "organizations", StringComparison.OrdinalIgnoreCase)
    || string.Equals(tenantId, "consumers", StringComparison.OrdinalIgnoreCase))
{
    throw new InvalidOperationException("AzureAd:TenantId must identify a single tenant.");
}

var applicationInsightsConnectionString =
    builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]
    ?? builder.Configuration["ApplicationInsights:ConnectionString"];
if (!string.IsNullOrWhiteSpace(applicationInsightsConnectionString))
{
    builder.Services.AddApplicationInsightsTelemetry(options =>
        options.ConnectionString = applicationInsightsConnectionString);
}
builder.Services
    .AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApp(builder.Configuration.GetSection("AzureAd"));
builder.Services.Configure<CookieAuthenticationOptions>(
    CookieAuthenticationDefaults.AuthenticationScheme,
    options =>
    {
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    });
builder.Services.AddAuthorization(options =>
{
    var ownerPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .RequireAssertion(context =>
            context.User.HasClaim(claim => claim.Type == "oid" && !string.IsNullOrWhiteSpace(claim.Value))
            || context.User.HasClaim(claim =>
                claim.Type == "http://schemas.microsoft.com/identity/claims/objectidentifier"
                && !string.IsNullOrWhiteSpace(claim.Value)))
        .Build();
    options.DefaultPolicy = ownerPolicy;
    options.FallbackPolicy = ownerPolicy;
});
builder.Services
    .AddControllersWithViews()
    .AddMicrosoftIdentityUI();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();
builder.Services.AddSingleton(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var endpoint = configuration["CosmosEndpoint"];

    if (string.IsNullOrWhiteSpace(endpoint))
    {
        throw new InvalidOperationException("CosmosEndpoint configuration is required.");
    }

    return new CosmosClient(endpoint, new DefaultAzureCredential());
});
builder.Services.AddSingleton<ICosmosDbService>(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var databaseName = configuration["CosmosDb:DatabaseName"];
    var containerName = configuration["CosmosDb:ContainerName"];

    if (string.IsNullOrWhiteSpace(databaseName) || string.IsNullOrWhiteSpace(containerName))
    {
        throw new InvalidOperationException(
            "CosmosDb:DatabaseName and CosmosDb:ContainerName configuration are required.");
    }

    return new CosmosDbService(
        serviceProvider.GetRequiredService<CosmosClient>(),
        databaseName,
        containerName);
});
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.ForwardLimit = 1;

    foreach (var configuredProxy in
             builder.Configuration.GetSection("ForwardedHeaders:KnownProxies").Get<string[]>() ?? [])
    {
        if (!IPAddress.TryParse(configuredProxy, out var proxyAddress))
        {
            throw new InvalidOperationException(
                $"ForwardedHeaders:KnownProxies contains invalid IP address '{configuredProxy}'.");
        }

        options.KnownProxies.Add(proxyAddress);
    }
});

var app = builder.Build();

app.UseForwardedHeaders();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
}

app.UseWhen(
    context => !context.Request.Path.StartsWithSegments("/healthz"),
    branch => branch.UseHttpsRedirection());
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/healthz", () => Results.Ok(new { status = "Healthy" }))
    .AllowAnonymous();
app.Map("/error", () => Results.Problem())
    .AllowAnonymous();
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Item}/{action=Index}/{id?}");

app.Run();

public partial class Program;
