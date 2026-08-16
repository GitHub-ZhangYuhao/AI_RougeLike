param(
  [string]$Output = "night_meadow_ground_1024.png",
  [int]$Seed = 260815
)

Add-Type -AssemblyName System.Drawing

$source = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class CartoonNightGroundGenerator
{
    const int Size = 1024;

    static double Smooth(double t) { return t * t * (3.0 - 2.0 * t); }
    static double Lerp(double a, double b, double t) { return a + (b - a) * t; }
    static double Clamp(double v, double lo, double hi) { return v < lo ? lo : (v > hi ? hi : v); }

    sealed class PeriodicNoise
    {
        readonly double[,] values;
        readonly int cells;

        public PeriodicNoise(int cellCount, int seed)
        {
            cells = cellCount;
            values = new double[cells, cells];
            Random random = new Random(seed);
            for (int y = 0; y < cells; y++)
                for (int x = 0; x < cells; x++)
                    values[x, y] = random.NextDouble();
        }

        public double Sample(double x, double y)
        {
            double gx = x * cells / Size;
            double gy = y * cells / Size;
            int x0 = (int)Math.Floor(gx);
            int y0 = (int)Math.Floor(gy);
            double tx = Smooth(gx - Math.Floor(gx));
            double ty = Smooth(gy - Math.Floor(gy));
            int ax = ((x0 % cells) + cells) % cells;
            int ay = ((y0 % cells) + cells) % cells;
            int bx = (ax + 1) % cells;
            int by = (ay + 1) % cells;
            double a = Lerp(values[ax, ay], values[bx, ay], tx);
            double b = Lerp(values[ax, by], values[bx, by], tx);
            return Lerp(a, b, ty);
        }
    }

    static Color Mix(Color a, Color b, double t)
    {
        t = Clamp(t, 0.0, 1.0);
        return Color.FromArgb(255,
            (int)Math.Round(Lerp(a.R, b.R, t)),
            (int)Math.Round(Lerp(a.G, b.G, t)),
            (int)Math.Round(Lerp(a.B, b.B, t)));
    }

    static void ForWrapped(float x, float y, float margin, Action<float, float> draw)
    {
        int minX = x < margin ? -1 : 0;
        int maxX = x > Size - margin ? 1 : 0;
        int minY = y < margin ? -1 : 0;
        int maxY = y > Size - margin ? 1 : 0;
        for (int oy = minY; oy <= maxY; oy++)
            for (int ox = minX; ox <= maxX; ox++)
                draw(x + ox * Size, y + oy * Size);
    }

    static PointF[] MakeBlob(float cx, float cy, float rx, float ry, int points, Random random)
    {
        PointF[] result = new PointF[points];
        for (int i = 0; i < points; i++)
        {
            double angle = Math.PI * 2.0 * i / points;
            float wobble = 0.78f + (float)random.NextDouble() * 0.38f;
            result[i] = new PointF(
                cx + (float)Math.Cos(angle) * rx * wobble,
                cy + (float)Math.Sin(angle) * ry * wobble);
        }
        return result;
    }

    static PointF[] OffsetPoints(PointF[] points, float dx, float dy)
    {
        PointF[] copy = new PointF[points.Length];
        for (int i = 0; i < points.Length; i++)
            copy[i] = new PointF(points[i].X + dx, points[i].Y + dy);
        return copy;
    }

    static void DrawWrappedBlob(Graphics g, PointF[] points, float cx, float cy, float margin, Color fill, Color outline, float outlineWidth)
    {
        using (Brush brush = new SolidBrush(fill))
        using (Pen pen = new Pen(outline, outlineWidth))
        {
            pen.LineJoin = LineJoin.Round;
            ForWrapped(cx, cy, margin, (dx, dy) =>
            {
                PointF[] moved = OffsetPoints(points, dx - cx, dy - cy);
                g.FillClosedCurve(brush, moved, FillMode.Winding, 0.42f);
                g.DrawClosedCurve(pen, moved, 0.42f, FillMode.Winding);
            });
        }
    }

    static void DrawGrassTuft(Graphics g, float x, float y, float scale, float rotation, Color body, Color highlight)
    {
        ForWrapped(x, y, 42f * scale, (cx, cy) =>
        {
            GraphicsState state = g.Save();
            g.TranslateTransform(cx, cy);
            g.RotateTransform(rotation);
            using (Brush shadow = new SolidBrush(Color.FromArgb(74, 10, 17, 40)))
                g.FillEllipse(shadow, -18f * scale, -2f * scale, 36f * scale, 12f * scale);

            float[] offsets = { -13f, -7f, 0f, 7f, 13f };
            float[] heights = { 20f, 31f, 38f, 29f, 19f };
            for (int i = 0; i < offsets.Length; i++)
            {
                float lean = (i - 2) * 6.5f;
                PointF p0 = new PointF(offsets[i] * scale, 4f * scale);
                PointF p1 = new PointF((offsets[i] + lean * 0.2f) * scale, -heights[i] * 0.38f * scale);
                PointF p2 = new PointF((offsets[i] + lean) * scale, -heights[i] * scale);
                using (GraphicsPath path = new GraphicsPath())
                {
                    path.AddBezier(p0, p1, p1, p2);
                    using (Pen outer = new Pen(Color.FromArgb(220, 12, 25, 51), 6.8f * scale))
                    using (Pen inner = new Pen(body, 4.0f * scale))
                    {
                        outer.StartCap = outer.EndCap = LineCap.Round;
                        inner.StartCap = inner.EndCap = LineCap.Round;
                        g.DrawPath(outer, path);
                        g.DrawPath(inner, path);
                    }
                }
            }
            using (Pen glint = new Pen(Color.FromArgb(125, highlight), 1.4f * scale))
            {
                glint.StartCap = glint.EndCap = LineCap.Round;
                g.DrawLine(glint, -1f * scale, -2f * scale, -2f * scale, -25f * scale);
            }
            g.Restore(state);
        });
    }

    static void DrawStone(Graphics g, float x, float y, float scale, float rotation, Random random)
    {
        ForWrapped(x, y, 38f * scale, (cx, cy) =>
        {
            GraphicsState state = g.Save();
            g.TranslateTransform(cx, cy);
            g.RotateTransform(rotation);
            PointF[] stone = MakeBlob(0f, 0f, 22f * scale, 14f * scale, 7, random);
            using (Brush shadow = new SolidBrush(Color.FromArgb(95, 8, 13, 34)))
                g.FillEllipse(shadow, -24f * scale, 5f * scale, 49f * scale, 15f * scale);
            using (Brush fill = new SolidBrush(Color.FromArgb(255, 66, 78, 116)))
            using (Pen outline = new Pen(Color.FromArgb(235, 15, 22, 52), 4.5f * scale))
            {
                outline.LineJoin = LineJoin.Round;
                g.FillClosedCurve(fill, stone, FillMode.Winding, 0.45f);
                g.DrawClosedCurve(outline, stone, 0.45f, FillMode.Winding);
            }
            using (Pen light = new Pen(Color.FromArgb(180, 112, 131, 164), 3f * scale))
            {
                light.StartCap = light.EndCap = LineCap.Round;
                g.DrawBezier(light,
                    -12f * scale, -4f * scale,
                    -5f * scale, -10f * scale,
                    4f * scale, -10f * scale,
                    10f * scale, -6f * scale);
            }
            g.Restore(state);
        });
    }

    static void DrawPetal(Graphics g, float x, float y, float scale, float rotation, bool bright)
    {
        ForWrapped(x, y, 22f * scale, (cx, cy) =>
        {
            GraphicsState state = g.Save();
            g.TranslateTransform(cx, cy);
            g.RotateTransform(rotation);
            using (GraphicsPath petal = new GraphicsPath())
            {
                petal.AddBezier(-10f * scale, 0f, -7f * scale, -9f * scale, 6f * scale, -8f * scale, 10f * scale, -1f * scale);
                petal.AddBezier(10f * scale, -1f * scale, 6f * scale, 8f * scale, -5f * scale, 7f * scale, -10f * scale, 0f);
                Color fill = bright ? Color.FromArgb(235, 244, 151, 189) : Color.FromArgb(205, 203, 112, 169);
                using (Brush brush = new SolidBrush(fill))
                using (Pen outline = new Pen(Color.FromArgb(175, 57, 43, 91), 2.2f * scale))
                {
                    g.FillPath(brush, petal);
                    g.DrawPath(outline, petal);
                }
                using (Pen shine = new Pen(Color.FromArgb(150, 255, 202, 221), 1.2f * scale))
                    g.DrawLine(shine, -3f * scale, -3f * scale, 4f * scale, -3f * scale);
            }
            g.Restore(state);
        });
    }

    static void DrawClover(Graphics g, float x, float y, float scale, float rotation)
    {
        ForWrapped(x, y, 28f * scale, (cx, cy) =>
        {
            GraphicsState state = g.Save();
            g.TranslateTransform(cx, cy);
            g.RotateTransform(rotation);
            using (Pen stem = new Pen(Color.FromArgb(210, 24, 66, 78), 3.2f * scale))
            {
                stem.StartCap = stem.EndCap = LineCap.Round;
                g.DrawLine(stem, 0f, 8f * scale, 0f, -7f * scale);
            }
            using (Brush leaf = new SolidBrush(Color.FromArgb(235, 46, 106, 111)))
            using (Pen edge = new Pen(Color.FromArgb(210, 13, 38, 59), 2.2f * scale))
            {
                RectangleF[] leaves = {
                    new RectangleF(-11f * scale, -14f * scale, 11f * scale, 9f * scale),
                    new RectangleF(0f, -15f * scale, 11f * scale, 9f * scale),
                    new RectangleF(-5.5f * scale, -23f * scale, 11f * scale, 10f * scale)
                };
                foreach (RectangleF r in leaves) { g.FillEllipse(leaf, r); g.DrawEllipse(edge, r); }
            }
            g.Restore(state);
        });
    }

    public static void Generate(string outputPath, int seed)
    {
        Random random = new Random(seed);
        PeriodicNoise broad = new PeriodicNoise(4, seed + 31);
        PeriodicNoise fine = new PeriodicNoise(16, seed + 79);
        Color baseDark = Color.FromArgb(255, 34, 39, 72);
        Color baseMid = Color.FromArgb(255, 48, 50, 86);
        Color baseLight = Color.FromArgb(255, 58, 61, 98);
        Color baseViolet = Color.FromArgb(255, 67, 54, 96);

        using (Bitmap bitmap = new Bitmap(Size, Size, PixelFormat.Format32bppArgb))
        {
            Rectangle rect = new Rectangle(0, 0, Size, Size);
            BitmapData data = bitmap.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            byte[] pixels = new byte[data.Stride * Size];
            for (int y = 0; y < Size; y++)
            {
                for (int x = 0; x < Size; x++)
                {
                    double n = broad.Sample(x, y);
                    double f = fine.Sample(x + 87.0, y + 29.0);
                    double band = Math.Round(Clamp((n - 0.18) / 0.68, 0.0, 1.0) * 5.0) / 5.0;
                    Color c = band < 0.38 ? Mix(baseDark, baseMid, band / 0.38) : Mix(baseMid, baseLight, (band - 0.38) / 0.62);
                    if (n > 0.66) c = Mix(c, baseViolet, (n - 0.66) * 0.55);
                    int brushGrain = (int)Math.Round((f - 0.5) * 7.0);
                    int index = y * data.Stride + x * 4;
                    pixels[index + 0] = (byte)Clamp(c.B + brushGrain, 0, 255);
                    pixels[index + 1] = (byte)Clamp(c.G + brushGrain, 0, 255);
                    pixels[index + 2] = (byte)Clamp(c.R + brushGrain, 0, 255);
                    pixels[index + 3] = 255;
                }
            }
            Marshal.Copy(pixels, 0, data.Scan0, pixels.Length);
            bitmap.UnlockBits(data);

            using (Graphics g = Graphics.FromImage(bitmap))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.CompositingQuality = CompositingQuality.HighQuality;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;

                // Large, intentional hand-painted ground islands replace the previous noise-only look.
                Color[] patchFills = {
                    Color.FromArgb(92, 24, 69, 82),
                    Color.FromArgb(82, 31, 79, 88),
                    Color.FromArgb(72, 80, 57, 103),
                    Color.FromArgb(68, 25, 53, 78)
                };
                for (int i = 0; i < 15; i++)
                {
                    float cx = (float)(random.NextDouble() * Size);
                    float cy = (float)(random.NextDouble() * Size);
                    float rx = 70f + (float)random.NextDouble() * 100f;
                    float ry = 42f + (float)random.NextDouble() * 72f;
                    PointF[] blob = MakeBlob(cx, cy, rx, ry, 10 + random.Next(4), random);
                    DrawWrappedBlob(g, blob, cx, cy, Math.Max(rx, ry) + 10f,
                        patchFills[i % patchFills.Length], Color.FromArgb(34, 13, 24, 51), 3f);
                }

                // Painterly short strokes, kept broad and sparse so they read as brushwork rather than noise.
                for (int i = 0; i < 150; i++)
                {
                    float x = (float)(random.NextDouble() * Size);
                    float y = (float)(random.NextDouble() * Size);
                    float len = 8f + (float)random.NextDouble() * 18f;
                    float angle = (float)(random.NextDouble() * Math.PI);
                    Color c = (i % 3 == 0) ? Color.FromArgb(38, 112, 103, 143) : Color.FromArgb(31, 32, 86, 102);
                    using (Pen pen = new Pen(c, 2.2f + (float)random.NextDouble() * 2.8f))
                    {
                        pen.StartCap = pen.EndCap = LineCap.Round;
                        ForWrapped(x, y, 28f, (cx, cy) =>
                            g.DrawLine(pen, cx, cy, cx + (float)Math.Cos(angle) * len, cy + (float)Math.Sin(angle) * len * 0.35f));
                    }
                }

                Color[] grassColors = {
                    Color.FromArgb(255, 36, 101, 112),
                    Color.FromArgb(255, 43, 111, 119),
                    Color.FromArgb(255, 50, 91, 112),
                    Color.FromArgb(255, 58, 104, 116)
                };
                for (int i = 0; i < 40; i++)
                {
                    float x = (float)(random.NextDouble() * Size);
                    float y = (float)(random.NextDouble() * Size);
                    float scale = 0.62f + (float)random.NextDouble() * 0.58f;
                    DrawGrassTuft(g, x, y, scale, -22f + (float)random.NextDouble() * 44f,
                        grassColors[i % grassColors.Length], Color.FromArgb(118, 167, 164));
                }

                for (int i = 0; i < 17; i++)
                    DrawStone(g,
                        (float)(random.NextDouble() * Size),
                        (float)(random.NextDouble() * Size),
                        0.58f + (float)random.NextDouble() * 0.55f,
                        -28f + (float)random.NextDouble() * 56f,
                        random);

                for (int i = 0; i < 24; i++)
                    DrawClover(g,
                        (float)(random.NextDouble() * Size),
                        (float)(random.NextDouble() * Size),
                        0.48f + (float)random.NextDouble() * 0.5f,
                        (float)(random.NextDouble() * 360.0));

                for (int i = 0; i < 46; i++)
                    DrawPetal(g,
                        (float)(random.NextDouble() * Size),
                        (float)(random.NextDouble() * Size),
                        0.42f + (float)random.NextDouble() * 0.55f,
                        (float)(random.NextDouble() * 360.0),
                        i % 4 == 0);

                // Small moonlit dots tie the surface to the magical nighttime palette.
                for (int i = 0; i < 65; i++)
                {
                    float x = (float)(random.NextDouble() * Size);
                    float y = (float)(random.NextDouble() * Size);
                    float r = 1.2f + (float)random.NextDouble() * 2.3f;
                    using (Brush glow = new SolidBrush(i % 3 == 0
                        ? Color.FromArgb(90, 105, 170, 174)
                        : Color.FromArgb(64, 112, 119, 166)))
                        ForWrapped(x, y, 5f, (cx, cy) => g.FillEllipse(glow, cx - r, cy - r, r * 2f, r * 1.3f));
                }
            }

            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath)));
            bitmap.Save(outputPath, ImageFormat.Png);
        }
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies System.Drawing
[CartoonNightGroundGenerator]::Generate($Output, $Seed)
Write-Host "Generated cartoon seamless 1024x1024 night ground texture: $Output"
