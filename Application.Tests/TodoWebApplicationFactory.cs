using System.Collections.Concurrent;
using System.Net;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using todo;
using todo.Models;

namespace Application.Tests;

public sealed class TodoWebApplicationFactory : WebApplicationFactory<Program>
{
    public InMemoryCosmosDbService Store { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureTestServices(services =>
        {
            services
                .AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = TestAuthenticationHandler.AuthenticationScheme;
                    options.DefaultChallengeScheme = TestAuthenticationHandler.AuthenticationScheme;
                    options.DefaultForbidScheme = TestAuthenticationHandler.AuthenticationScheme;
                })
                .AddScheme<AuthenticationSchemeOptions, TestAuthenticationHandler>(
                    TestAuthenticationHandler.AuthenticationScheme,
                    _ => { });

            services.RemoveAll<ICosmosDbService>();
            services.AddSingleton<ICosmosDbService>(Store);
        });
    }

    public HttpClient CreateAuthenticatedClient(string? ownerId)
    {
        var client = CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false,
            BaseAddress = new Uri("https://localhost")
        });
        client.DefaultRequestHeaders.Add(TestAuthenticationHandler.UserHeader, "test-user");
        if (ownerId is not null)
        {
            client.DefaultRequestHeaders.Add(TestAuthenticationHandler.OwnerHeader, ownerId);
        }

        return client;
    }
}

public sealed class TestAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string AuthenticationScheme = "Test";
    public const string UserHeader = "X-Test-User";
    public const string OwnerHeader = "X-Test-Oid";

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(UserHeader, out var userName))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userName.ToString()),
            new(ClaimTypes.Name, userName.ToString())
        };
        if (Request.Headers.TryGetValue(OwnerHeader, out var ownerId))
        {
            claims.Add(new Claim("oid", ownerId.ToString()));
        }

        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, AuthenticationScheme));
        return Task.FromResult(
            AuthenticateResult.Success(
                new AuthenticationTicket(principal, AuthenticationScheme)));
    }

    protected override Task HandleChallengeAsync(AuthenticationProperties properties)
    {
        Response.StatusCode = StatusCodes.Status401Unauthorized;
        return Task.CompletedTask;
    }

    protected override Task HandleForbiddenAsync(AuthenticationProperties properties)
    {
        Response.StatusCode = StatusCodes.Status403Forbidden;
        return Task.CompletedTask;
    }
}

public sealed class InMemoryCosmosDbService : ICosmosDbService
{
    private readonly ConcurrentDictionary<string, Item> _items = new();

    public int Count => _items.Count;

    public Item Seed(string ownerId, string name, string? id = null)
    {
        var item = new Item
        {
            Id = id ?? Guid.NewGuid().ToString("D"),
            Name = name,
            Description = $"{name} description",
            OwnerId = ownerId
        };
        _items[item.Id] = item;
        return item;
    }

    public Task<IReadOnlyList<Item>> GetItemsAsync(string ownerId)
    {
        IReadOnlyList<Item> items = _items.Values
            .Where(item => item.OwnerId == ownerId)
            .OrderBy(item => item.Name)
            .ToList();
        return Task.FromResult(items);
    }

    public Task<Item?> GetItemAsync(string id, string ownerId)
    {
        _items.TryGetValue(id, out var item);
        return Task.FromResult(item?.OwnerId == ownerId ? item : null);
    }

    public Task<Item> CreateItemAsync(
        string ownerId,
        string name,
        string? description,
        bool completed)
    {
        var item = new Item
        {
            Id = Guid.NewGuid().ToString("D"),
            Name = name,
            Description = description,
            Completed = completed,
            OwnerId = ownerId
        };
        _items[item.Id] = item;
        return Task.FromResult(item);
    }

    public Task<bool> UpdateItemAsync(
        string id,
        string ownerId,
        string name,
        string? description,
        bool completed)
    {
        if (!_items.TryGetValue(id, out var item) || item.OwnerId != ownerId)
        {
            return Task.FromResult(false);
        }

        item.Name = name;
        item.Description = description;
        item.Completed = completed;
        return Task.FromResult(true);
    }

    public Task<bool> DeleteItemAsync(string id, string ownerId)
    {
        if (!_items.TryGetValue(id, out var item) || item.OwnerId != ownerId)
        {
            return Task.FromResult(false);
        }

        return Task.FromResult(_items.TryRemove(id, out _));
    }
}
