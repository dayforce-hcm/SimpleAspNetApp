using System.Web.Mvc;

namespace Main.Controllers;

public class HomeController : Controller
{
    [HttpGet]
    public ActionResult Index()
    {
        return View();
    }

    [HttpGet]
    public ActionResult Ping()
    {
        return Content("Pong");
    }
}
