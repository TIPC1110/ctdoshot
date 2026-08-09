using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Windows;
using System.Windows.Media.Imaging;

namespace CtdoShotWin.Engine
{
    public static class CaptureEngineWin
    {
        /// <summary>
        /// Captures full virtual screen (all monitors).
        /// </summary>
        public static BitmapSource CaptureFullScreen()
        {
            int left = System.Windows.Forms.SystemInformation.VirtualScreen.Left;
            int top = System.Windows.Forms.SystemInformation.VirtualScreen.Top;
            int width = System.Windows.Forms.SystemInformation.VirtualScreen.Width;
            int height = System.Windows.Forms.SystemInformation.VirtualScreen.Height;

            using var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            using var g = Graphics.FromImage(bmp);
            g.CopyFromScreen(left, top, 0, 0, new System.Drawing.Size(width, height), CopyPixelOperation.SourceCopy);

            return ToBitmapSource(bmp);
        }

        /// <summary>
        /// Captures a specific crop region on screen.
        /// </summary>
        public static BitmapSource CaptureRegion(Int32Rect rect)
        {
            using var bmp = new Bitmap(rect.Width, rect.Height, PixelFormat.Format32bppArgb);
            using var g = Graphics.FromImage(bmp);
            g.CopyFromScreen(rect.X, rect.Y, 0, 0, new System.Drawing.Size(rect.Width, rect.Height), CopyPixelOperation.SourceCopy);

            return ToBitmapSource(bmp);
        }

        private static BitmapSource ToBitmapSource(Bitmap bitmap)
        {
            var rect = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            var bitmapData = bitmap.LockBits(rect, ImageLockMode.ReadOnly, bitmap.PixelFormat);

            try
            {
                var bitmapSource = BitmapSource.Create(
                    bitmapData.Width, bitmapData.Height,
                    96, 96,
                    System.Windows.Media.PixelFormats.Bgra32, null,
                    bitmapData.Scan0, bitmapData.Stride * bitmapData.Height, bitmapData.Stride);
                bitmapSource.Freeze();
                return bitmapSource;
            }
            finally
            {
                bitmap.UnlockBits(bitmapData);
            }
        }
    }
}
