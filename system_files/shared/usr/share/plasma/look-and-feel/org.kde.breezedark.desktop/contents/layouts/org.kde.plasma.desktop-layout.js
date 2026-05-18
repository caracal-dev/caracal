/* global loadTemplate, panels */

loadTemplate("org.kde.plasma.desktop.defaultPanel")

const allPanels = panels();

for (const panel of allPanels) {
    panel.floating = false;

    const widgets = panel.widgets();

    for (const widget of widgets) {

        if (widget.type === "org.kde.plasma.icontasks") {
            widget.currentConfigGroup = ["General"];
            widget.writeConfig("launchers", [
                "applications:app.zen_browser.zen.desktop",
                "applications:com.mitchellh.ghostty.desktop",
                "applications:io.github.kolunmi.Bazaar.desktop",
                "applications:ardour9.desktop",
                "preferred://filemanager"
            ]);
            widget.reloadConfig();
        }
    }
}
