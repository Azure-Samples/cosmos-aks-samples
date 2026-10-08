namespace todo
{
    using System.Collections.Generic;
    using System.Threading.Tasks;
    using todo.Models;

    public interface ICosmosDbService
    {
        Task<IReadOnlyList<Item>> GetItemsAsync(string ownerId);
        Task<Item?> GetItemAsync(string id, string ownerId);
        Task<Item> CreateItemAsync(
            string ownerId,
            string name,
            string? description,
            bool completed);
        Task<bool> UpdateItemAsync(
            string id,
            string ownerId,
            string name,
            string? description,
            bool completed);
        Task<bool> DeleteItemAsync(string id, string ownerId);
    }
}
