package catalog

import "path/filepath"

type Action struct {
	Title string
	Exec  []string
}

type Package struct {
	ID               string
	Name             string
	Vendor           string
	Summary          string
	Description      string
	Notes            []string
	AvailabilityNote string
	InstalledMarkers []string
	InstallActions   []Action
	UninstallActions []Action
}

type Subcategory struct {
	ID          string
	Name        string
	Description string
	Packages    []*Package
}

type Category struct {
	ID            string
	Name          string
	Description   string
	Accent        string
	Subcategories []*Subcategory
}

func Build(scriptDir string) []*Category {
	script := func(name string) []string {
		return []string{"bash", filepath.Join(scriptDir, name)}
	}
	sudoScript := func(name string) []string {
		return []string{"sudo", "bash", filepath.Join(scriptDir, name)}
	}

	return []*Category{
		{
			ID:          "daws",
			Name:        "DAWs",
			Description: "Commercial workstation installs that complement the default Caracal toolset.",
			Accent:      "#7dd3fc",
			Subcategories: []*Subcategory{
				{
					ID:          "commercial-daws",
					Name:        "Commercial DAWs",
					Description: "Optional workstation installs that currently live in Caracal's post-install flow.",
					Packages: []*Package{
						{
							ID:          "reaper",
							Name:        "REAPER",
							Vendor:      "Cockos",
							Summary:     "Fast commercial DAW with unrestricted evaluation.",
							Description: "Installs REAPER into /opt/REAPER and publishes a system desktop entry and icon in /usr/local. The installer also seeds plugin search paths in the target user's REAPER config when sudo is used.",
							Notes: []string{
								"Requires sudo because it writes to /opt and /usr/local.",
								"Preserves compatibility with Caracal's existing REAPER install approach.",
							},
							InstalledMarkers: []string{
								"/opt/REAPER/reaper",
								"/usr/local/share/applications/cockos-reaper.desktop",
							},
							InstallActions: []Action{
								{Title: "Install REAPER", Exec: sudoScript("install-reaper.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall REAPER", Exec: sudoScript("uninstall-reaper.sh")},
							},
						},
						{
							ID:          "renoise",
							Name:        "Renoise",
							Vendor:      "Renoise",
							Summary:     "Tracker-style DAW with demo-mode installer.",
							Description: "Installs the current Renoise demo into /opt/renoise, adds a wrapper command, desktop integration, MIME metadata, and icons in /usr/local.",
							Notes: []string{
								"Requires sudo because it writes to /opt and /usr/local.",
								"The shipped installer targets the demo build until license activation happens inside Renoise.",
							},
							InstalledMarkers: []string{
								"/opt/renoise/renoise",
								"/usr/local/share/applications/renoise.desktop",
							},
							InstallActions: []Action{
								{Title: "Install Renoise", Exec: sudoScript("install-renoise.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Renoise", Exec: sudoScript("uninstall-renoise.sh")},
							},
						},
						{
							ID:          "bitwig-studio",
							Name:        "Bitwig Studio",
							Vendor:      "Bitwig",
							Summary:     "Commercial DAW with native Linux support.",
							Description: "Downloads the official Bitwig .deb, extracts it into /opt/bitwig-studio, and publishes desktop integration through /usr/local so it survives immutable image updates.",
							Notes: []string{
								"Requires sudo because it writes to /opt and /usr/local.",
								"Bitwig itself still requires a valid upstream license.",
							},
							InstalledMarkers: []string{
								"/opt/bitwig-studio/bitwig-studio",
								"/usr/local/share/applications/bitwig-studio.desktop",
							},
							InstallActions: []Action{
								{Title: "Install Bitwig Studio", Exec: sudoScript("install-bitwig.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Bitwig Studio", Exec: sudoScript("uninstall-bitwig.sh")},
							},
						},
					},
				},
			},
		},
		{
			ID:          "virtual-instruments",
			Name:        "Virtual Instruments",
			Description: "Synths, modular environments, and sample players available as optional installs.",
			Accent:      "#f59e0b",
			Subcategories: []*Subcategory{
				{
					ID:          "warmplace",
					Name:        "Warmplace",
					Description: "Portable desktop synths and experimental tools from Alexander Zolotov.",
					Packages: []*Package{
						{
							ID:          "sunvox",
							Name:        "SunVox",
							Vendor:      "Warmplace",
							Summary:     "Modular tracker and synth studio distributed as a portable ZIP archive.",
							Description: "Downloads the official SunVox Linux ZIP, installs it under /opt/caracal/warmplace/sunvox, and creates a wrapper plus desktop entry in /usr/local.",
							Notes: []string{
								"Requires sudo because it writes to /opt and /usr/local.",
								"SunVox uses a portable archive layout rather than a distro-native package.",
							},
							InstalledMarkers: []string{
								"/usr/local/bin/sunvox",
								"/usr/local/share/applications/sunvox.desktop",
							},
							InstallActions: []Action{
								{Title: "Install SunVox", Exec: sudoScript("install-sunvox.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall SunVox", Exec: sudoScript("uninstall-sunvox.sh")},
							},
						},
						{
							ID:          "virtual-ans",
							Name:        "Virtual ANS",
							Vendor:      "Warmplace",
							Summary:     "Spectral drawing synthesizer distributed as a portable ZIP archive.",
							Description: "Downloads the official Virtual ANS Linux ZIP, installs it under /opt/caracal/warmplace/virtual-ans, and creates a wrapper plus desktop entry in /usr/local.",
							Notes: []string{
								"Requires sudo because it writes to /opt and /usr/local.",
								"Distributed upstream as a portable archive with the Linux launcher inside the extracted folder.",
							},
							InstalledMarkers: []string{
								"/usr/local/bin/virtual-ans",
								"/usr/local/share/applications/virtual-ans.desktop",
							},
							InstallActions: []Action{
								{Title: "Install Virtual ANS", Exec: sudoScript("install-virtual-ans.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Virtual ANS", Exec: sudoScript("uninstall-virtual-ans.sh")},
							},
						},
						{
							ID:          "fractal-bits",
							Name:        "Fractal Bits",
							Vendor:      "Warmplace",
							Summary:     "Fractal drum synth desktop build currently distributed through a paid upstream post.",
							Description: "The desktop Linux build is listed by Warmplace, but the current upstream download is a purchase-gated Boosty post rather than a direct public ZIP archive.",
							Notes: []string{
								"Listed here so the Warmplace section reflects the broader brand lineup.",
								"Once a stable public ZIP URL or a purchase flow is defined, this can be turned into a first-class installer entry.",
							},
							AvailabilityNote: "Current desktop download is purchase-gated upstream, so there is no unattended installer script yet.",
						},
					},
				},
				{
					ID:          "tal",
					Name:        "TAL",
					Description: "User-local TAL plugin installs distributed as Linux ZIP archives.",
					Packages: []*Package{
						{
							ID:          "tal-noisemaker",
							Name:        "TAL-Noisemaker",
							Vendor:      "TAL Software",
							Summary:     "Free virtual analog synth installed from TAL's Linux ZIP archive.",
							Description: "Downloads TAL-Noisemaker and installs the contained CLAP, VST3, and VST2 plugin payloads into the current user's ~/.clap, ~/.vst3, and ~/.vst directories. This specific archive does not currently ship an LV2 bundle.",
							Notes: []string{
								"Does not require sudo.",
								"Installed as a user-local plugin set so it works cleanly on immutable systems.",
								"Built on a reusable TAL ZIP installer so additional TAL plugins can be added with minimal metadata changes.",
							},
							InstalledMarkers: []string{
								".clap/TAL-NoiseMaker.clap",
								".vst3/TAL-NoiseMaker.vst3",
								".vst/libTAL-NoiseMaker.so",
							},
							InstallActions: []Action{
								{Title: "Install TAL-Noisemaker", Exec: script("install-tal-noisemaker.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall TAL-Noisemaker", Exec: script("uninstall-tal-noisemaker.sh")},
							},
						},
					},
				},
				{
					ID:          "open-synths",
					Name:        "Open Synths",
					Description: "Native instruments that fit well into the Caracal plugin path layout.",
					Packages: []*Package{
						{
							ID:          "cardinal",
							Name:        "Cardinal",
							Vendor:      "DISTRHO",
							Summary:     "VCV Rack-derived modular environment with standalone and plugin targets.",
							Description: "Downloads the official Cardinal Linux bundle and installs the standalone binaries plus VST, VST3, LV2, and CLAP targets into /usr/local for immutable-system compatibility.",
							Notes: []string{
								"Requires sudo because it writes to /usr/local/bin and /usr/local/lib64.",
								"This replaces the previous image-baked Cardinal install path.",
							},
							InstalledMarkers: []string{
								"/usr/local/bin/Cardinal",
								"/usr/local/lib64/vst3/Cardinal.vst3",
							},
							InstallActions: []Action{
								{Title: "Install Cardinal", Exec: sudoScript("install-cardinal.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Cardinal", Exec: sudoScript("uninstall-cardinal.sh")},
							},
						},
						{
							ID:          "surge-xt",
							Name:        "Surge XT",
							Vendor:      "Surge Synth Team",
							Summary:     "Open-source hybrid synthesizer installed from the upstream RPM payload.",
							Description: "Downloads the upstream Surge XT RPM, extracts its payload without layering the OS image, and mirrors the relevant binaries, plugins, and desktop files into /usr/local.",
							Notes: []string{
								"Requires sudo because it writes into /usr/local.",
								"Uses archive extraction rather than dnf layering so it works as a post-install action on Caracal.",
							},
							InstalledMarkers: []string{
								"/usr/local/bin/*surge*",
								"/usr/local/lib64/vst3/*Surge*",
							},
							InstallActions: []Action{
								{Title: "Install Surge XT", Exec: sudoScript("install-surge-xt.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Surge XT", Exec: sudoScript("uninstall-surge-xt.sh")},
							},
						},
						{
							ID:          "wavetable",
							Name:        "Wavetable",
							Vendor:      "FigBug",
							Summary:     "A 2 oscillator wavetable synthesizer with flexible modulation options.",
							Description: "Downloads the upstream Wabetable synth, extracts its payload without layering the OS image, and mirrors the relevant binaries, plugins, and desktop files into /usr/local.",
							Notes: []string{
								"Does not require sudo.",
								"Uses archive extraction rather than dnf layering so it works as a post-install action on Caracal.",
							},
							InstalledMarkers: []string{
								".vst/Wavetable.so",
								".vst3/Wavetable.vst3",
								".lv2/Wavetable.lv2",
							},
							InstallActions: []Action{
								{Title: "Install Wavetable", Exec: script("install-wavetable.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Wavetable", Exec: script("uninstall-wavetable.sh")},
							},
						},
					},
				},
				{
					ID:          "samplers-and-players",
					Name:        "Samplers & Players",
					Description: "Sample playback tools that round out the base system.",
					Packages: []*Package{
						{
							ID:          "loopino",
							Name:        "Loopino",
							Vendor:      "brummer10",
							Summary:     "Live looper instrument built from source as user-local CLAP and VST2 plugins.",
							Description: "Clones the Loopino repository, initializes submodules, builds the CLAP and VST2 plugin targets from source, and installs them into the current user's plugin directories. The standalone target is intentionally skipped.",
							Notes: []string{
								"Does not require sudo.",
								"Builds from source, so git, make, and a working native build toolchain are required on the target system.",
								"Installs only CLAP and VST2, matching the current Caracal post-install preference for Loopino.",
							},
							InstalledMarkers: []string{
								".clap/*Loopino*",
								".vst/*Loopino*",
							},
							InstallActions: []Action{
								{Title: "Install Loopino", Exec: script("install-loopino.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Loopino", Exec: script("uninstall-loopino.sh")},
							},
						},
						{
							ID:          "decent-sampler",
							Name:        "Decent Sampler",
							Vendor:      "Decent Samples",
							Summary:     "Lightweight standalone and plugin sample player.",
							Description: "Downloads the static Decent Sampler bundle and installs the standalone binary plus VST and VST3 targets into /usr/local.",
							Notes: []string{
								"Requires sudo because it writes into /usr/local.",
								"This replaces the previous image-baked Decent Sampler install path.",
							},
							InstalledMarkers: []string{
								"/usr/local/bin/DecentSampler",
								"/usr/local/lib64/vst3/DecentSampler.vst3",
							},
							InstallActions: []Action{
								{Title: "Install Decent Sampler", Exec: sudoScript("install-decent-sampler.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Decent Sampler", Exec: sudoScript("uninstall-decent-sampler.sh")},
							},
						},
					},
				},
			},
		},
		{
			ID:          "effects",
			Name:        "Effects",
			Description: "Optional processor installs grouped by vendor as the catalog grows.",
			Accent:      "#34d399",
			Subcategories: []*Subcategory{
				{
					ID:          "audio-assault",
					Name:        "Audio Assault",
					Description: "User-local VST3 and LV2 installs from Audio Assault's Linux plugin archives.",
					Packages: []*Package{
						{
							ID:          "audio-assault-drum-locker",
							Name:        "Drum Locker",
							Vendor:      "Audio Assault",
							Summary:     "Drum and groove production plugin installed from the official Linux archive.",
							Description: "Downloads Drum Locker and installs its VST3 and LV2 bundles into the current user's ~/.vst3 and ~/.lv2 directories.",
							Notes: []string{
								"Does not require sudo.",
								"Installed as a user-local plugin so it works cleanly on immutable systems.",
							},
							InstalledMarkers: []string{
								".vst3/Drum Locker.vst3",
								".lv2/Drum Locker.lv2",
							},
							InstallActions: []Action{
								{Title: "Install Drum Locker", Exec: script("install-audio-assault-drumlocker.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Drum Locker", Exec: script("uninstall-audio-assault-drumlocker.sh")},
							},
						},
						{
							ID:          "audio-assault-amp-locker",
							Name:        "Amp Locker",
							Vendor:      "Audio Assault",
							Summary:     "Amp sim platform installed from the official Linux archive.",
							Description: "Downloads Amp Locker and installs its VST3 and LV2 bundles into the current user's ~/.vst3 and ~/.lv2 directories.",
							Notes: []string{
								"Does not require sudo.",
								"Installed as a user-local plugin so it works cleanly on immutable systems.",
							},
							InstalledMarkers: []string{
								".vst3/Amp Locker.vst3",
								".lv2/Amp Locker.lv2",
							},
							InstallActions: []Action{
								{Title: "Install Amp Locker", Exec: script("install-audio-assault-amplocker.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Amp Locker", Exec: script("uninstall-audio-assault-amplocker.sh")},
							},
						},
						{
							ID:          "audio-assault-mix-locker",
							Name:        "Mix Locker",
							Vendor:      "Audio Assault",
							Summary:     "Channel-strip and mix processing platform installed from the official Linux archive.",
							Description: "Downloads Mix Locker and installs its VST3 and LV2 bundles into the current user's ~/.vst3 and ~/.lv2 directories.",
							Notes: []string{
								"Does not require sudo.",
								"Installed as a user-local plugin so it works cleanly on immutable systems.",
							},
							InstalledMarkers: []string{
								".vst3/Mix Locker.vst3",
								".lv2/Mix Locker.lv2",
							},
							InstallActions: []Action{
								{Title: "Install Mix Locker", Exec: script("install-audio-assault-mixlocker.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall Mix Locker", Exec: script("uninstall-audio-assault-mixlocker.sh")},
							},
						},
					},
				},
				{
					ID:          "tal",
					Name:        "TAL Effects",
					Description: "TAL Effects such as chorus, reverb etc.",
					Packages:    []*Package{},
				},
				{
					ID:          "general-effects",
					Name:        "General Effects",
					Description: "For vendors that do not have a large catelog of available effects",
					Packages: []*Package{
						{
							ID:          "intersect",
							Name:        "INTERSECT",
							Vendor:      "tucktuckg00se",
							Summary:     "INTERSECT is a sample slicer instrument plugin.",
							Description: "Downloads INTERSECT and installs its VST3 bundle into the current user's ~/.vst3 directory.",
							Notes: []string{
								"Does not require sudo.",
								"Installed as a user-local plugin so it works cleanly on immutable systems.",
							},
							InstalledMarkers: []string{
								".vst3/INTERSECT.vst3",
							},
							InstallActions: []Action{
								{Title: "Install INTERSECT", Exec: script("install-intersect.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall INTERSECT", Exec: script("uninstall-intersect.sh")},
							},
						},
					},
				},
			},
		},
		{
			ID:          "utilities",
			Name:        "Utilities",
			Description: "Audio-adjacent helpers and diagnostics.",
			Accent:      "#c084fc",
			Subcategories: []*Subcategory{
				{
					ID:          "system-tuning",
					Name:        "System Tuning",
					Description: "Checks and helpers for realtime audio setup.",
					Packages: []*Package{
						{
							ID:          "rtcqs",
							Name:        "RTCQS",
							Vendor:      "rtcqs",
							Summary:     "Realtime Configuration Quick Scan CLI and GUI.",
							Description: "Creates a user-local virtualenv under ~/.local/share/caracal-os/rtcqs, publishes wrapper commands in ~/.local/bin, and adds a desktop launcher for rtcqs_gui.",
							Notes: []string{
								"Does not require sudo.",
								"Installs into the current user's home directory.",
							},
							InstalledMarkers: []string{
								".local/bin/rtcqs",
								".local/share/applications/rtcqs-gui.desktop",
							},
							InstallActions: []Action{
								{Title: "Install RTCQS", Exec: script("install-rtcqs.sh")},
							},
							UninstallActions: []Action{
								{Title: "Uninstall RTCQS", Exec: script("uninstall-rtcqs.sh")},
							},
						},
					},
				},
			},
		},
	}
}

func CountPackages(categories []*Category) int {
	total := 0
	for _, category := range categories {
		for _, subcategory := range category.Subcategories {
			total += len(subcategory.Packages)
		}
	}
	return total
}
