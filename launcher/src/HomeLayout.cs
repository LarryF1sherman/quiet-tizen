using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;

public sealed class HomeCard
{
 public string Label {get;set;}
 public string Action {get;set;}
 public string Description {get;set;}="";
 public string Image {get;set;}
 public string Icon {get;set;}
 public string Kicker {get;set;}
 public string Headline {get;set;}
 public string Subline {get;set;}
 public string Fallback {get;set;}="apps";
}

// Home page arrangement: one wide card, two portrait cards and a dock of up to six.
// Actions: app:APP_ID, hdmi:SOURCE_TYPE (13-16 observed as HDMI 1-4) or page:0-2.
public sealed class HomeLayout
{
 public string Theme {get;set;}="light";
 public string Clock {get;set;}="h:mm tt";
 public HomeCard Hero {get;set;}
 public List<HomeCard> Portraits {get;set;}
 public List<HomeCard> Dock {get;set;}
 // Optional action for the remote's microphone key; null leaves the key to the TV.
 public string VoiceKey {get;set;}
 public const int DockSlots=6;
 static readonly Regex ActionPattern=new Regex(@"^(app:[A-Za-z0-9][A-Za-z0-9._-]*|hdmi:1[3-6]|page:[0-2])$");
 static readonly Regex FallbackPattern=new Regex(@"^[a-z0-9-]+$");

 public static HomeLayout Load(string path)
 {
  var layout=JsonSerializer.Deserialize<HomeLayout>(File.ReadAllText(path));
  if(layout==null||layout.Hero==null||layout.Portraits==null||layout.Portraits.Count!=2
     ||layout.Dock==null||layout.Dock.Count<1||layout.Dock.Count>DockSlots
     ||(layout.Theme!="light"&&layout.Theme!="dark")||string.IsNullOrWhiteSpace(layout.Clock))
   throw new InvalidDataException("Invalid home layout.");
  try{DateTime.Now.ToString(layout.Clock);}catch(FormatException){throw new InvalidDataException("Invalid clock format.");}
  if(layout.VoiceKey!=null&&!ActionPattern.IsMatch(layout.VoiceKey))throw new InvalidDataException("Invalid microphone key action.");
  var cards=new List<HomeCard>{layout.Hero};cards.AddRange(layout.Portraits);cards.AddRange(layout.Dock);
  foreach(var card in cards)
  {
   if(card==null||string.IsNullOrWhiteSpace(card.Label)||card.Action==null||!ActionPattern.IsMatch(card.Action)
      ||!SafeAsset(card.Image)||!SafeAsset(card.Icon)||card.Fallback==null||!FallbackPattern.IsMatch(card.Fallback))
    throw new InvalidDataException("Invalid home card.");
  }
  if(layout.Hero.Image==null)throw new InvalidDataException("The wide card needs an image.");
  return layout;
 }
 // Used when home.json is missing or invalid, so Home still reaches apps and settings.
 public static HomeLayout Fallback()=>new HomeLayout{
  Hero=new HomeCard{Label="Your Apps",Action="page:1",Description="Home layout could not be loaded",Image="feature-hdmi.svg",Headline="Your Apps"},
  Portraits=new List<HomeCard>{new HomeCard{Label="Settings",Action="page:2",Image="feature-hdmi.svg"},new HomeCard{Label="Apps",Action="page:1",Image="feature-hdmi.svg"}},
  Dock=new List<HomeCard>{new HomeCard{Label="Your Apps",Action="page:1"}}};
 static bool SafeAsset(string asset)=>asset==null||(asset.Length>0&&!Path.IsPathRooted(asset)&&!asset.Contains("..")&&!asset.Contains("\\"));
 public static string AppId(string action)=>action.StartsWith("app:")?action.Substring(4):null;
 public static int Source(string action)=>action.StartsWith("hdmi:")?int.Parse(action.Substring(5)):-1;
}
