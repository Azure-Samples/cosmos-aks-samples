using System.Security.Claims;

namespace todo;

public sealed class CurrentUser(IHttpContextAccessor httpContextAccessor) : ICurrentUser
{
    public string OwnerId
    {
        get
        {
            var user = httpContextAccessor.HttpContext?.User;
            var ownerId = user?.FindFirstValue("oid")
                ?? user?.FindFirstValue(
                    "http://schemas.microsoft.com/identity/claims/objectidentifier");

            if (string.IsNullOrWhiteSpace(ownerId))
            {
                throw new UnauthorizedAccessException(
                    "The authenticated identity is missing the required oid claim.");
            }

            return ownerId;
        }
    }
}
