namespace todo
{
    using System;
    using System.Collections.Generic;
    using System.Net;
    using System.Threading.Tasks;
    using Microsoft.Azure.Cosmos;
    using todo.Models;

    public class CosmosDbService : ICosmosDbService
    {
        private readonly Container _container;

        public CosmosDbService(
            CosmosClient dbClient,
            string databaseName,
            string containerName)
        {
            _container = dbClient.GetContainer(databaseName, containerName);
        }

        public async Task<IReadOnlyList<Item>> GetItemsAsync(string ownerId)
        {
            var queryDefinition = new QueryDefinition(
                    "SELECT * FROM c WHERE c.ownerId = @ownerId")
                .WithParameter("@ownerId", ownerId);
            var query = _container.GetItemQueryIterator<Item>(queryDefinition);
            var results = new List<Item>();

            while (query.HasMoreResults)
            {
                var response = await query.ReadNextAsync();
                results.AddRange(response);
            }

            return results;
        }

        public async Task<Item?> GetItemAsync(string id, string ownerId)
        {
            var item = await ReadItemAsync(id);
            return item is not null && string.Equals(item.OwnerId, ownerId, StringComparison.Ordinal)
                ? item
                : null;
        }

        public async Task<Item> CreateItemAsync(
            string ownerId,
            string name,
            string? description,
            bool completed)
        {
            var item = new Item
            {
                Id = Guid.NewGuid().ToString("D"),
                OwnerId = ownerId,
                Name = name,
                Description = description,
                Completed = completed
            };

            var response = await _container.CreateItemAsync(item, new PartitionKey(item.Id));
            return response.Resource;
        }

        public async Task<bool> UpdateItemAsync(
            string id,
            string ownerId,
            string name,
            string? description,
            bool completed)
        {
            var item = await GetItemAsync(id, ownerId);
            if (item is null)
            {
                return false;
            }

            item.Name = name;
            item.Description = description;
            item.Completed = completed;

            try
            {
                await _container.ReplaceItemAsync(
                    item,
                    id,
                    new PartitionKey(id),
                    new ItemRequestOptions { IfMatchEtag = item.ETag });
                return true;
            }
            catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.NotFound)
            {
                return false;
            }
        }

        public async Task<bool> DeleteItemAsync(string id, string ownerId)
        {
            var item = await GetItemAsync(id, ownerId);
            if (item is null)
            {
                return false;
            }

            try
            {
                await _container.DeleteItemAsync<Item>(
                    id,
                    new PartitionKey(id),
                    new ItemRequestOptions { IfMatchEtag = item.ETag });
                return true;
            }
            catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.NotFound)
            {
                return false;
            }
        }

        private async Task<Item?> ReadItemAsync(string id)
        {
            try
            {
                var response = await _container.ReadItemAsync<Item>(id, new PartitionKey(id));
                return response.Resource;
            }
            catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.NotFound)
            {
                return null;
            }
        }
    }
}
