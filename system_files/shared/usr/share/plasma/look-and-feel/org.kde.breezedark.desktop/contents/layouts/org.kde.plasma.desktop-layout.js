loadTemplate("org.kde.plasma.desktop.defaultPanel")

const allPanels = panels();

for (let i = 0; i < allPanels.length; ++i) {
    const panel = allPanels[i];
    panel.floating = false;

    const widgets = panel.widgets();

    for (let j = 0; j < widgets.length; ++j) {
        const widget = widgets[j];

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
