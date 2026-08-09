using System;
using System.Windows;
using CtdoShotWin.Engine;
using CtdoShotWin.Helpers;
using CtdoShotWin.Views;

namespace CtdoShotWin
{
    public partial class App : Application
    {
        private GlobalHotkey? _hotkeyArea;

        private void Application_Startup(object sender, StartupEventArgs e)
        {
            // Hidden anchor window for Win32 message loop & hotkey binding
            var hiddenWindow = new Window
            {
                Width = 0, Height = 0,
                WindowStyle = WindowStyle.None,
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

        protected override void OnExit(ExitEventArgs e)
        {
            _hotkeyArea?.Dispose();
            base.OnExit(e);
        }
    }
}
