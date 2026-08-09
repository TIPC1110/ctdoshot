using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace CtdoShotWin.Helpers
{
    public class GlobalHotkey : IDisposable
    {
        private const int WM_HOTKEY = 0x0312;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        public const uint MOD_ALT = 0x0001;
        public const uint MOD_CONTROL = 0x0002;
        public const uint MOD_SHIFT = 0x0004;
        public const uint MOD_WIN = 0x0008;

        private readonly IntPtr _hWnd;
        private readonly int _id;
        private readonly Action _action;
        private HwndSource? _source;

        public GlobalHotkey(IntPtr hWnd, int id, uint modifiers, uint key, Action action)
        {
            _hWnd = hWnd;
            _id = id;
            _action = action;

            if (!RegisterHotKey(hWnd, id, modifiers, key))
            {
                throw new InvalidOperationException($"Failed to register global hotkey id {id}");
            }

            _source = HwndSource.FromHwnd(hWnd);
            _source?.AddHook(HwndHook);
        }

        private IntPtr HwndHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (msg == WM_HOTKEY && wParam.ToInt32() == _id)
            {
                _action?.Invoke();
                handled = true;
            }
            return IntPtr.Zero;
        }

        public void Dispose()
        {
            _source?.RemoveHook(HwndHook);
            UnregisterHotKey(_hWnd, _id);
            GC.SuppressFinalize(this);
        }
    }
}
