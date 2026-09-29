using AzureDevOpsDemo.Web.Models;
using AzureDevOpsDemo.Web.Services;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace AzureDevOpsDemo.Web.Controllers
{
    public class HomeController : Controller
    {
        private readonly ProtectedSettingsReader _protectedSettingsReader;

        public HomeController(ProtectedSettingsReader protectedSettingsReader)
        {
            _protectedSettingsReader = protectedSettingsReader;
        }

        public IActionResult Index()
        {
            bool keyVaultConnected = _protectedSettingsReader.TryGetDemoValue(out string? keyVaultValue);

            return View(new KeyVaultStatusViewModel
            {
                KeyVaultConnected = keyVaultConnected,
                KeyVaultValue = keyVaultValue
            });
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
