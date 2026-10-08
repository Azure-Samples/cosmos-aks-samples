namespace todo.Controllers
{
    using System.Threading.Tasks;
    using Microsoft.AspNetCore.Authorization;
    using Microsoft.AspNetCore.Mvc;
    using todo.Models;

    [Authorize]
    public class ItemController : Controller
    {
        private readonly ICosmosDbService _cosmosDbService;
        private readonly ICurrentUser _currentUser;

        public ItemController(ICosmosDbService cosmosDbService, ICurrentUser currentUser)
        {
            _cosmosDbService = cosmosDbService;
            _currentUser = currentUser;
        }

        public async Task<IActionResult> Index()
        {
            return View(await _cosmosDbService.GetItemsAsync(_currentUser.OwnerId));
        }

        public IActionResult Create()
        {
            return View(new Item());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create([Bind("Name,Description,Completed")] Item item)
        {
            if (!ModelState.IsValid)
            {
                return View(item);
            }

            await _cosmosDbService.CreateItemAsync(
                _currentUser.OwnerId,
                item.Name,
                item.Description,
                item.Completed);
            return RedirectToAction(nameof(Index));
        }

        public async Task<IActionResult> Edit(string id)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                return NotFound();
            }

            var item = await _cosmosDbService.GetItemAsync(id, _currentUser.OwnerId);
            if (item is null)
            {
                return NotFound();
            }

            return View(item);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(
            [FromRoute] string id,
            [Bind("Name,Description,Completed")] Item item)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                return NotFound();
            }

            var existingItem = await _cosmosDbService.GetItemAsync(id, _currentUser.OwnerId);
            if (existingItem is null)
            {
                return NotFound();
            }

            if (!ModelState.IsValid)
            {
                item.Id = id;
                return View(item);
            }

            var updated = await _cosmosDbService.UpdateItemAsync(
                id,
                _currentUser.OwnerId,
                item.Name,
                item.Description,
                item.Completed);
            return updated ? RedirectToAction(nameof(Index)) : NotFound();
        }

        public async Task<IActionResult> Delete(string id)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                return NotFound();
            }

            var item = await _cosmosDbService.GetItemAsync(id, _currentUser.OwnerId);
            if (item is null)
            {
                return NotFound();
            }

            return View(item);
        }

        [HttpPost]
        [ActionName(nameof(Delete))]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed([FromRoute] string id)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                return NotFound();
            }

            var deleted = await _cosmosDbService.DeleteItemAsync(id, _currentUser.OwnerId);
            return deleted ? RedirectToAction(nameof(Index)) : NotFound();
        }

        public async Task<IActionResult> Details(string id)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                return NotFound();
            }

            var item = await _cosmosDbService.GetItemAsync(id, _currentUser.OwnerId);
            return item is null ? NotFound() : View(item);
        }
    }
}
