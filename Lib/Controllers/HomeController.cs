using System;
using System.IO;
using System.Security.Cryptography;
using System.Web.Mvc;

namespace Lib.Controllers;

public class HomeController : Controller
{
    [HttpGet]
    public ActionResult Index()
    {
        return View();
    }

    [HttpGet]
    public JsonResult Ping()
    {
        var loadedLibFileInfo = new FileInfo(typeof(HomeController).Assembly.Location);
        var builtLibFileInfo = new FileInfo(@$"{AppDomain.CurrentDomain.BaseDirectory}..\..\Lib.dll");
        var builtFileHash = GetFileHash(builtLibFileInfo.FullName);
        var loadedFileHash = GetFileHash(loadedLibFileInfo.FullName);
        return Json(new
        {
            Same = builtFileHash == loadedFileHash,
            Built = new
            {
                builtLibFileInfo.FullName,
                LastWriteTime = builtLibFileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"),
                FileHash = builtFileHash
            },
            Loaded = new
            {
                FullName = loadedLibFileInfo.FullName.Replace(Environment.GetEnvironmentVariable("TEMP"), "$env:TEMP"),
                LastWriteTime = loadedLibFileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"),
                FileHash = loadedFileHash
            }
        }, JsonRequestBehavior.AllowGet);

        static string GetFileHash(string filePath)
        {
            using var sha256 = SHA256.Create();
            using var stream = System.IO.File.OpenRead(filePath);
            var hash = sha256.ComputeHash(stream);
            return BitConverter.ToString(hash).Replace("-", "");
        }
    }
}
