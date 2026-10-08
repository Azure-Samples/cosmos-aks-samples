namespace todo.Models
{
    using System.ComponentModel.DataAnnotations;
    using Microsoft.AspNetCore.Mvc.ModelBinding;
    using Newtonsoft.Json;

    public class Item
    {
        [BindNever]
        [JsonProperty(PropertyName = "id")]
        public string Id { get; internal set; } = string.Empty;

        [Required]
        [StringLength(100)]
        [JsonProperty(PropertyName = "name")]
        public string Name { get; set; } = string.Empty;

        [StringLength(1000)]
        [JsonProperty(PropertyName = "description")]
        public string? Description { get; set; }

        [JsonProperty(PropertyName = "isComplete")]
        public bool Completed { get; set; }

        [BindNever]
        [JsonProperty(PropertyName = "ownerId")]
        public string OwnerId { get; internal set; } = string.Empty;

        [BindNever]
        [JsonProperty(PropertyName = "_etag")]
        public string ETag { get; internal set; } = string.Empty;
    }
}
