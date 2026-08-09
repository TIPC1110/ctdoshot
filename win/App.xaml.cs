using System;
using CtdoShotWin.Engine;
using CtdoShotWin.Helpers;
using CtdoShotWin.Views;

namespace CtdoShotWin
{
    public partial class App : System.Windows.Application
    {
        private GlobalHotkey? _hotkeyArea;

        private void Application_Startup(object sender, System.Windows.StartupEventArgs e)
        {
            // Hidden anchor window for Win32 message loop & hotkey binding
            var hiddenWindow = new System.Windows.Window
            {
                Width = 0, Height = 0,
                WindowStyle = System.Windows.WindowStyle.None,
                ShowInTaskbar = false
            };
            hiddenWindow.Show();
            hiddenWindow.Hide();

            var helper = new System.Windows.Interop.WindowInteropHelper(hiddenWindow);

            try
            {
                // Ctrl+Shift+S (VK_S = 0x53)
                _hotkeyArea = new GlobalHotkey(
                    helper.Handle, 1,
                    GlobalHotkey.MOD_CONTROL | GlobalHotkey.MOD_SHIFT,
                    0x53,
                    TriggerCaptureArea
                );
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Hotkey setup warning: {ex.Message}");
            }
        }

        private void TriggerCaptureArea()
        {
            Dispatcher.Invoke(() =>
            {
                var image = CaptureEngineWin.CaptureFullScreen();
                var editor = new MainWindow(image);
                editor.Show();
            });
        }

        protected override void OnExit(System.Windows.ExitEventArgs e)
        {
            _hotkeyArea?.Dispose();
            base.OnExit(e);
        }
    }
}
