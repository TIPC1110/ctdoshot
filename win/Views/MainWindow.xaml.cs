using System.Windows;
using System.Windows.Media.Imaging;
using CtdoShotWin.Engine;

namespace CtdoShotWin.Views
{
    public partial class MainWindow : Window
    {
        private BitmapSource? _currentImage;

        public MainWindow(BitmapSource? initialImage = null)
        {
            InitializeComponent();
            if (initialImage != null)
            {
                SetImage(initialImage);
            }
        }

        public void SetImage(BitmapSource image)
        {
            _currentImage = image;
            CapturedImage.Source = image;
            DrawingCanvas.Width = image.PixelWidth;
            DrawingCanvas.Height = image.PixelHeight;
        }

        private void CopyButton_Click(object sender, RoutedEventArgs e)
        {
            if (_currentImage != null)
            {
                Clipboard.SetImage(_currentImage);
                MessageBox.Show("Image copied to clipboard!", "ctdoshot-win", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            MessageBox.Show("Save file dialog stub", "ctdoshot-win");
        }

        private async void OcrButton_Click(object sender, RoutedEventArgs e)
        {
            if (_currentImage != null)
            {
                var text = await OcrEngineWin.RecognizeTextAsync(_currentImage);
                if (!string.IsNullOrEmpty(text))
                {
                    Clipboard.SetText(text);
                    MessageBox.Show($"OCR Text copied to clipboard:\n\n{text}", "ctdoshot-win OCR");
                }
                else
                {
                    MessageBox.Show("No text recognized.", "ctdoshot-win OCR");
                }
            }
        }

        private void Tool_Click(object sender, RoutedEventArgs e)
        {
            if (sender is System.Windows.Controls.Button btn)
            {
                System.Diagnostics.Debug.WriteLine($"Selected tool: {btn.Tag}");
            }
        }
    }
}
