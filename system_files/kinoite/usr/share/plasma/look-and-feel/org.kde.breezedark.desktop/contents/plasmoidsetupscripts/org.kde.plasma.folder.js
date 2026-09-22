/* global applet */

applet.wallpaperPlugin = "org.kde.image"
applet.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]
applet.writeConfig("Image", "file:///usr/share/wallpapers/caracal/caracal-mist.png")
applet.writeConfig("PreviewImage", "file:///usr/share/wallpapers/caracal/caracal-mist.png")
applet.reloadConfig()
