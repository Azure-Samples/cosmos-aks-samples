using System;

namespace todo.Models
{
    public class ErrorViewModel
    {
        public string RequestId { get; set; }

        public bool ShowRequestId => !string.IsNullOrEmpty(RequestId);

        public void OnGet()
        {
            //RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier;

            //var exceptionHandlerPathFeature =
            //    HttpContext.Features.Get<IExceptionHandlerPathFeature>();

            //if (exceptionHandlerPathFeature?.Error is FileNotFoundException)
            //{
            //    ExceptionMessage = "The file was not found.";
            //}

            //if (exceptionHandlerPathFeature?.Path == "/")
            //{
            //    ExceptionMessage ??= string.Empty;
            //    ExceptionMessage += " Page: Home.";
            //}
        }
    }
}