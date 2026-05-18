/* global panels */

const desiredLaunchers = [
    "applications:app.zen_browser.zen.desktop",
    "applications:com.mitchellh.ghostty.desktop",
    "applications:io.github.kolunmi.Bazaar.desktop",
    "applications:ardour9.desktop",
    "preferred://filemanager"
];

const legacyLaunchers = [
    "applications:Alacritty.desktop,applications:app.zen_browser.zen.desktop,applications:org.kde.dolphin.desktop,applications:io.github.kolunmi.Bazaar.desktop",
    "applications:Alacritty.desktop,applications:io.github.kolunmi.Bazaar.desktop,applications:app.zen_browser.zen.desktop,applications:ardour9.desktop",
    "applications:org.alacritty.Alacritty.desktop,applications:app.zen_browser.zen.desktop,applications:io.github.kolunmi.Bazaar.desktop,applications:ardour9.desktop,preferred://filemanager"
];

const allPanels = panels();

for (const panel of allPanels) {
    panel.floating = false;

    const widgets = panel.widgets();
    for (const widget of widgets) {

        if (widget.type === "org.kde.plasma.kickoff") {
            widget.currentConfigGroup = ["General"];
            widget.writeConfig("icon", "distributor-logo");
            widget.reloadConfig();
        }

        if (widget.type === "org.kde.plasma.icontasks") {
            widget.currentConfigGroup = ["General"];
            const currentLaunchers = widget.readConfig("launchers", "");

            if (!currentLaunchers || legacyLaunchers.indexOf(currentLaunchers.trim()) !== -1) {
                widget.writeConfig("launchers", desiredLaunchers);
                widget.reloadConfig();
            }
        }
    }
}
