using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Media.Imaging;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;

namespace CtdoShotWin.Engine
{
    public static class OcrEngineWin
    {
        public static async Task<string?> RecognizeTextAsync(BitmapSource bitmapSource)
        {
            try
            {
                var engine = OcrEngine.TryCreateFromUserProfileLanguages();
                if (engine == null) return null;

                // Convert BitmapSource -> SoftwareBitmap
                using var stream = new MemoryStream();
                var encoder = new PngBitmapEncoder();
                encoder.Frames.Add(BitmapFrame.Create(bitmapSource));
                encoder.Save(stream);
                stream.Position = 0;

                var decoder = await BitmapDecoder.CreateAsync(stream.AsRandomAccessStream());
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
