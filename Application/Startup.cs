namespace todo
{
    using System;
    using System.Collections.Generic;
    using System.Linq.Expressions;
    using System.Threading.Tasks;
    using Azure.Identity;
    using Microsoft.AspNetCore;
    using Microsoft.AspNetCore.Builder;
    using Microsoft.AspNetCore.Hosting;
    using Microsoft.AspNetCore.Http;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.Logging;
    using Microsoft.Extensions.Logging.ApplicationInsights;

    public class Startup
    {
        private ILogger _logger;

        public Startup(IConfiguration configuration)
        {

            Configuration = configuration;
            //_logger = logger;

        }

        public IConfiguration Configuration { get; }

        // <ConfigureServices> 
        public void ConfigureServices(IServiceCollection services)
        {
            // The following line enables Application Insights telemetry collection.
            services.AddApplicationInsightsTelemetry(Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]);
           // services.AddApplicationInsightsTelemetry();

            services.AddControllersWithViews();


            //services.AddSingleton<ICosmosDbService>(InitializeCosmosClientInstanceAsync(Configuration.GetSection("CosmosDb")).GetAwaiter().GetResult());

            services.AddSingleton<ICosmosDbService>(InitializeCosmosClientInstanceAsync(Configuration).GetAwaiter().GetResult());
            //services.AddSingleton<ICosmosDbService>(InitializeCosmosClientInstanceAsync().GetAwaiter().GetResult());
        }
        // </ConfigureServices> 

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env, ILogger<Startup> logger)     
        {
            _logger = logger;

            _logger.LogError(
                $"Running in {env.EnvironmentName} environment");

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {              
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
             }   
            app.UseHttpsRedirection();
            app.UseStaticFiles();

            app.UseRouting();

            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Item}/{action=Index}/{id?}");
            });


        }


        // <InitializeCosmosClientInstanceAsync>        
        /// <summary>
        /// Creates a Cosmos DB database and a container with the specified partition key. 
        /// </summary>
        /// <returns></returns>
        private static async Task<CosmosDbService> InitializeCosmosClientInstanceAsync(IConfiguration configuration)
        {
   
            string endpoint = configuration["CosmosEndpoint"];

            string databaseName = configuration.GetSection("CosmosDb").GetSection("DatabaseName").Value;
            string containerName = configuration.GetSection("CosmosDb").GetSection("ContainerName").Value;


            //Microsoft.Azure.Cosmos.CosmosClient client = new Microsoft.Azure.Cosmos.CosmosClient(endpoint, key);

            var credential = new DefaultAzureCredential();

            Microsoft.Azure.Cosmos.CosmosClient client = new Microsoft.Azure.Cosmos.CosmosClient(endpoint, credential);

            CosmosDbService cosmosDbService = new CosmosDbService(client, databaseName, containerName);

            Microsoft.Azure.Cosmos.DatabaseResponse database = await client.CreateDatabaseIfNotExistsAsync(databaseName);
     
            await database.Database.CreateContainerIfNotExistsAsync(containerName, "/id");

            return cosmosDbService;
   
        }
        // </InitializeCosmosClientInstanceAsync>
    }
}
