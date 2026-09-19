using Microsoft.UI.Xaml;
using OfflineReShade.WinUI.Views;

namespace OfflineReShade.WinUI;

public partial class App : Application
{
    private static readonly string CrashLogPath = Path.Combine(AppContext.BaseDirectory, "OfflineReShadeWinUI.crash.log");

    private Window? _window;

    public App()
    {
        InitializeComponent();

        // Without these an exception on the UI thread tears the process down with nothing but a
        // stowed-exception code in the event log, which says nothing about what actually failed.
        UnhandledException += (_, e) =>
        {
            Log("UI thread", e.Exception);
            e.Handled = true;
        };
        AppDomain.CurrentDomain.UnhandledException += (_, e) => Log("AppDomain", e.ExceptionObject as Exception);
        TaskScheduler.UnobservedTaskException += (_, e) =>
        {
            Log("Unobserved task", e.Exception);
            e.SetObserved();
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.Activate();
    }

    private static void Log(string source, Exception? exception)
    {
        var text = $"[{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss.fff}] {source}: {exception}{Environment.NewLine}{Environment.NewLine}";
        System.Diagnostics.Debug.WriteLine(text);
        try
        {
            File.AppendAllText(CrashLogPath, text);
        }
        catch (Exception)
        {
            // Nothing useful to do if even the log cannot be written
        }
    }
}
