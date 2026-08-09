using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Media.Imaging;

namespace CtdoShotWin.Engine
{
    public static class OcrEngineWin
    {
        public static async Task<string?> RecognizeTextAsync(BitmapSource bitmapSource)
        {
            try
            {
                var engine = Windows.Media.Ocr.OcrEngine.TryCreateFromUserProfileLanguages();
                if (engine == null) return null;

                // Convert BitmapSource -> SoftwareBitmap
                using var stream = new MemoryStream();
                var encoder = new PngBitmapEncoder();
                encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(bitmapSource));
                encoder.Save(stream);
                stream.Position = 0;

                var decoder = await Windows.Graphics.Imaging.BitmapDecoder.CreateAsync(stream.AsRandomAccessStream());
                using var softwareBitmap = await decoder.GetSoftwareBitmapAsync();

                var ocrResult = await engine.RecognizeAsync(softwareBitmap);
                return ocrResult.Text;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Windows OCR Exception: {ex.Message}");
                return null;
            }
        }
    }
}
