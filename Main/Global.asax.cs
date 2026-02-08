using Main.App_Start;
using System.Web;
using System.Web.Routing;

namespace Main;

public class Global : HttpApplication
{
    protected void Application_Start()
    {
        RouteConfig.RegisterRoutes(RouteTable.Routes);
    }

    protected void Application_End()
    {
    }
}
