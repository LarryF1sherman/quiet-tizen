using System;
using System.IO;

static class CatalogTests
{
    static void Equal(int expected, int actual, string context)
    {
        if (expected != actual) throw new Exception(context + ": expected " + expected + ", got " + actual);
    }
    public static int Main(string[] args)
    {
        var catalog = AppLibrary.Load(args[0]);
        if (catalog.Count < 2) throw new Exception("Catalog unexpectedly small");
        Equal(-1, AppLibrary.Move(31, 0, "Up"), "top row returns to tabs");
        Equal(15, AppLibrary.Move(31, 10, "Down"), "last row enters next page");
        Equal(25, AppLibrary.Move(31, 30, "Up"), "partial page returns to matching previous column");
        Equal(30, AppLibrary.Move(31, 29, "Down"), "last partial page clamps column");
        Equal(11, AppLibrary.Move(12, 9, "Down"), "partial bottom row clamps column");
        Equal(11, AppLibrary.Move(12, 11, "Right"), "last item remains selected");
        Equal(-1, AppLibrary.Move(0, 0, "Down"), "empty catalog");
        for (int count = 1; count < 48; count++)
            for (int item = 0; item < count; item++)
                foreach (var key in new[] {"Left", "Right", "Up", "Down"})
                {
                    int next = AppLibrary.Move(count, item, key);
                    if (next < -1 || next >= count) throw new Exception("Out of bounds navigation");
                }
        string tmp = Path.GetTempFileName();
        try
        {
            foreach (string json in new[] {
                "[{\"Name\":\"Bad\",\"Id\":\"one\",\"Asset\":\"../escape.svg\",\"Width\":100,\"Height\":50}]",
                "[{\"Name\":\"Bad\",\"Id\":\"one\",\"Asset\":\"ok.svg\",\"Width\":100,\"Height\":50,\"Crop\":[0.8,0,0.4,1]}]",
                "[{\"Name\":\"A\",\"Id\":\"one\",\"Asset\":\"ok.svg\",\"Width\":100,\"Height\":50},{\"Name\":\"B\",\"Id\":\"one\",\"Asset\":\"ok.svg\",\"Width\":100,\"Height\":50}]"
            })
            {
                File.WriteAllText(tmp, json);
                bool rejected = false;
                try { AppLibrary.Load(tmp); } catch (InvalidDataException) { rejected = true; }
                if (!rejected) throw new Exception("Invalid catalog accepted");
            }
        }
        finally { File.Delete(tmp); }
        string layoutPath = args.Length > 1 ? args[1] : Path.Combine(Path.GetDirectoryName(Path.GetFullPath(args[0])), "home.json");
        var layout = HomeLayout.Load(layoutPath);
        var cards = new System.Collections.Generic.List<HomeCard> { layout.Hero };
        cards.AddRange(layout.Portraits); cards.AddRange(layout.Dock);
        foreach (var card in cards)
        {
            string id = HomeLayout.AppId(card.Action);
            if (id != null && catalog.Find(a => a.Id == id) == null) throw new Exception("Layout app missing from catalog: " + id);
        }
        tmp = Path.GetTempFileName();
        try
        {
            string valid = File.ReadAllText(layoutPath);
            foreach (string json in new[] {
                valid.Replace("\"Portraits\"", "\"Unused\""),
                valid.Replace(layout.Hero.Action, "hdmi:99"),
                valid.Replace(layout.Hero.Action, "app:../escape"),
                valid.Replace("\"" + layout.Hero.Image + "\"", "\"../escape.svg\""),
                valid.Replace("\"" + layout.Theme + "\"", "\"neon\""),
                valid.Replace("\"" + layout.Clock + "\"", "\"%\""),
                layout.VoiceKey != null
                    ? valid.Replace("\"" + layout.VoiceKey + "\"", "\"shell:reboot\"")
                    : "{\"VoiceKey\":\"shell:reboot\"," + valid.Substring(valid.IndexOf('{') + 1)
            })
            {
                if (json == valid) throw new Exception("Layout mutation did not apply");
                File.WriteAllText(tmp, json);
                bool rejected = false;
                try { HomeLayout.Load(tmp); } catch (InvalidDataException) { rejected = true; } catch (System.Text.Json.JsonException) { rejected = true; }
                if (!rejected) throw new Exception("Invalid layout accepted");
            }
        }
        finally { File.Delete(tmp); }
        Console.WriteLine("Catalog, home layout, invalid-input and navigation checks passed.");
        return 0;
    }
}
