using System.Net;
using System.Text.RegularExpressions;
using Xunit;

namespace Application.Tests;

public sealed class ApplicationSecurityTests
{
    private const string OwnerA = "11111111-1111-1111-1111-111111111111";
    private const string OwnerB = "22222222-2222-2222-2222-222222222222";

    [Fact]
    public async Task HealthEndpointIsAnonymousAndIndependentOfAzureConfiguration()
    {
        await using var factory = new TodoWebApplicationFactory();
        using var client = factory.CreateClient(new()
        {
            AllowAutoRedirect = false,
            BaseAddress = new Uri("http://localhost")
        });

        var response = await client.GetAsync("/healthz");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task AnonymousMvcRequestIsChallenged()
    {
        await using var factory = new TodoWebApplicationFactory();
        using var client = factory.CreateClient(new()
        {
            AllowAutoRedirect = false,
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.GetAsync("/Item");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task AuthenticatedListIsScopedToOid()
    {
        await using var factory = new TodoWebApplicationFactory();
        factory.Store.Seed(OwnerA, "owner-a-item");
        factory.Store.Seed(OwnerB, "owner-b-item");
        using var client = factory.CreateAuthenticatedClient(OwnerA);

        var response = await client.GetAsync("/Item");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("owner-a-item", body);
        Assert.DoesNotContain("owner-b-item", body);
    }

    [Fact]
    public async Task RenderedFormsUseCurrentCssWithoutDeletedScriptDependencies()
    {
        await using var factory = new TodoWebApplicationFactory();
        using var client = factory.CreateAuthenticatedClient(OwnerA);

        var response = await client.GetAsync("/Item/Create");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("bootstrap@5.3.8/dist/css/bootstrap.min.css", body);
        Assert.DoesNotContain("/lib/", body);
        Assert.DoesNotContain("jquery", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("bundles/jqueryval", body);
    }

    [Fact]
    public async Task AuthenticatedRequestWithoutOidIsForbidden()
    {
        await using var factory = new TodoWebApplicationFactory();
        using var client = factory.CreateAuthenticatedClient(null);

        var response = await client.GetAsync("/Item");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateIgnoresPostedIdentityAndGeneratesServerIdentity()
    {
        await using var factory = new TodoWebApplicationFactory();
        using var client = factory.CreateAuthenticatedClient(OwnerA);
        var token = await GetAntiforgeryTokenAsync(client);

        var response = await client.PostAsync("/Item/Create", Form(
            token,
            ("Id", "attacker-id"),
            ("OwnerId", OwnerB),
            ("Name", "created-item"),
            ("Description", "created description"),
            ("Completed", "true")));

        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        var created = Assert.Single(await factory.Store.GetItemsAsync(OwnerA));
        Assert.NotEqual("attacker-id", created.Id);
        Assert.Equal(OwnerA, created.OwnerId);
        Assert.Equal("created-item", created.Name);
        Assert.Empty(await factory.Store.GetItemsAsync(OwnerB));
    }

    [Fact]
    public async Task CrossOwnerReadEditAndDeleteReturnNotFoundWithoutMutation()
    {
        await using var factory = new TodoWebApplicationFactory();
        var foreignItem = factory.Store.Seed(OwnerB, "foreign-item");
        using var client = factory.CreateAuthenticatedClient(OwnerA);
        var token = await GetAntiforgeryTokenAsync(client);

        var details = await client.GetAsync($"/Item/Details/{foreignItem.Id}");
        var editGet = await client.GetAsync($"/Item/Edit/{foreignItem.Id}");
        var editPost = await client.PostAsync($"/Item/Edit/{foreignItem.Id}", Form(
            token,
            ("Name", "changed"),
            ("Description", "changed"),
            ("Completed", "true")));
        var deleteGet = await client.GetAsync($"/Item/Delete/{foreignItem.Id}");
        var deletePost = await client.PostAsync($"/Item/Delete/{foreignItem.Id}", Form(token));

        Assert.Equal(HttpStatusCode.NotFound, details.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, editGet.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, editPost.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, deleteGet.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, deletePost.StatusCode);
        var unchanged = await factory.Store.GetItemAsync(foreignItem.Id, OwnerB);
        Assert.NotNull(unchanged);
        Assert.Equal("foreign-item", unchanged.Name);
    }

    [Fact]
    public async Task EditReplacesExistingItemAndNeverCreatesMissingItem()
    {
        await using var factory = new TodoWebApplicationFactory();
        var existing = factory.Store.Seed(OwnerA, "before");
        using var client = factory.CreateAuthenticatedClient(OwnerA);
        var token = await GetAntiforgeryTokenAsync(client);
        var countBefore = factory.Store.Count;

        var existingResponse = await client.PostAsync($"/Item/Edit/{existing.Id}", Form(
            token,
            ("Id", "attacker-id"),
            ("Name", "after"),
            ("Description", "updated"),
            ("Completed", "true")));
        var missingResponse = await client.PostAsync($"/Item/Edit/{Guid.NewGuid():D}", Form(
            token,
            ("Name", "must-not-exist"),
            ("Description", "must-not-exist"),
            ("Completed", "false")));

        Assert.Equal(HttpStatusCode.Redirect, existingResponse.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, missingResponse.StatusCode);
        Assert.Equal(countBefore, factory.Store.Count);
        var updated = await factory.Store.GetItemAsync(existing.Id, OwnerA);
        Assert.NotNull(updated);
        Assert.Equal("after", updated.Name);
        Assert.Equal(existing.Id, updated.Id);
    }

    [Fact]
    public async Task PostWithoutAntiforgeryTokenIsRejected()
    {
        await using var factory = new TodoWebApplicationFactory();
        using var client = factory.CreateAuthenticatedClient(OwnerA);

        var response = await client.PostAsync("/Item/Create", Form(
            null,
            ("Name", "rejected"),
            ("Description", "missing token"),
            ("Completed", "false")));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, factory.Store.Count);
    }

    private static async Task<string> GetAntiforgeryTokenAsync(HttpClient client)
    {
        var response = await client.GetAsync("/Item/Create");
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadAsStringAsync();
        var match = Regex.Match(
            body,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)\"");
        Assert.True(match.Success, "The antiforgery token was not rendered.");
        return WebUtility.HtmlDecode(match.Groups[1].Value);
    }

    private static FormUrlEncodedContent Form(
        string? token,
        params (string Key, string Value)[] values)
    {
        var fields = values
            .Select(value => new KeyValuePair<string, string>(value.Key, value.Value))
            .ToList();
        if (token is not null)
        {
            fields.Add(new KeyValuePair<string, string>("__RequestVerificationToken", token));
        }

        return new FormUrlEncodedContent(fields);
    }
}
