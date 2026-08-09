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
                System.Windows.Clipboard.SetImage(_currentImage);
                System.Windows.MessageBox.Show("Image copied to clipboard!", "ctdoshot-win", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            System.Windows.MessageBox.Show("Save file dialog stub", "ctdoshot-win");
        }

        private async void OcrButton_Click(object sender, RoutedEventArgs e)
        {
            if (_currentImage != null)
            {
                var text = await OcrEngineWin.RecognizeTextAsync(_currentImage);
                if (!string.IsNullOrEmpty(text))
                {
                    System.Windows.Clipboard.SetText(text);
                    System.Windows.MessageBox.Show($"OCR Text copied to clipboard:\n\n{text}", "ctdoshot-win OCR");
                }
                else
                {
                    System.Windows.MessageBox.Show("No text recognized.", "ctdoshot-win OCR");
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
