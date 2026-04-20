package ui

import (
	"fmt"
	"strings"

	"github.com/caracal-os/caracal-software-installer/internal/catalog"
	"github.com/caracal-os/caracal-software-installer/internal/installer"
	"github.com/gdamore/tcell/v2"
	"github.com/rivo/tview"
)

var theme = struct {
	Background tcell.Color
	Panel      tcell.Color
	Accent     tcell.Color
	AccentWarm tcell.Color
	Text       tcell.Color
	Muted      tcell.Color
	Success    tcell.Color
	Warning    tcell.Color
	Danger     tcell.Color
	FocusMute  tcell.Color
}{
	Background: tcell.NewHexColor(0x181616),
	Panel:      tcell.NewHexColor(0x1d1c19),
	Accent:     tcell.NewHexColor(0x8ba4b0),
	AccentWarm: tcell.NewHexColor(0xff9e3b),
	Text:       tcell.NewHexColor(0xc5c9c5),
	Muted:      tcell.NewHexColor(0x7a8382),
	Success:    tcell.NewHexColor(0x8a9a7b),
	Warning:    tcell.NewHexColor(0xe46876),
	Danger:     tcell.NewHexColor(0xc4746e),
	FocusMute:  tcell.NewHexColor(0x2d3139),
}

const (
	paneLibrary = "library"
	paneQueue   = "queue"
)

type nodeRef struct {
	Category    *catalog.Category
	Subcategory *catalog.Subcategory
}

type App struct {
	app              *tview.Application
	pages            *tview.Pages
	categories       []*catalog.Category
	logo             string
	activePane       string
	currentCategory  *catalog.Category
	currentSubcat    *catalog.Subcategory
	selected         map[string]bool
	states           map[string]installer.PackageState
	tree             *tview.TreeView
	packageTable     *tview.Table
	details          *tview.TextView
	header           *tview.TextView
	status           *tview.TextView
	selectedRowIndex int
}

func New(categories []*catalog.Category, logo string) *App {
	ui := &App{
		app:          tview.NewApplication(),
		pages:        tview.NewPages(),
		categories:   categories,
		logo:         logo,
		activePane:   paneLibrary,
		selected:     make(map[string]bool),
		states:       make(map[string]installer.PackageState),
		header:       tview.NewTextView(),
		status:       tview.NewTextView(),
		tree:         tview.NewTreeView(),
		packageTable: tview.NewTable(),
		details:      tview.NewTextView(),
	}

	ui.refreshStates()
	ui.buildLayout()
	ui.populateTree()

	if len(categories) > 0 {
		ui.setCurrentCategory(categories[0])
	}

	return ui
}

func (a *App) Run() error {
	return a.app.SetRoot(a.pages, true).EnableMouse(true).Run()
}

func (a *App) buildLayout() {
	a.app.SetInputCapture(a.handleGlobalKeys)

	a.header.
		SetDynamicColors(true).
		SetRegions(false).
		SetWrap(false).
		SetTextAlign(tview.AlignLeft).
		SetText(a.renderHeader()).
		SetBorderPadding(1, 0, 2, 2)
	a.header.SetBackgroundColor(theme.Background)

	a.status.
		SetDynamicColors(true).
		SetTextAlign(tview.AlignLeft).
		SetWrap(false).
		SetBorderPadding(0, 0, 2, 2)
	a.status.SetBackgroundColor(theme.Background)

	a.tree.SetBorder(true)
	a.tree.SetTitle(" Library ")
	a.tree.SetGraphics(true)
	a.tree.SetTopLevel(1)
	a.tree.SetBackgroundColor(theme.Panel)
	a.tree.SetBorderColor(theme.Accent)
	a.tree.SetChangedFunc(func(node *tview.TreeNode) {
		ref, _ := node.GetReference().(*nodeRef)
		if ref == nil {
			return
		}
		if ref.Subcategory != nil {
			a.currentCategory = ref.Category
			a.currentSubcat = ref.Subcategory
			a.selectedRowIndex = 0
			a.refreshPackageTable()
			return
		}
		if ref.Category != nil {
			a.setCurrentCategory(ref.Category)
		}
	})
	a.tree.SetSelectedFunc(func(node *tview.TreeNode) {
		node.SetExpanded(!node.IsExpanded())
	})
	a.tree.SetInputCapture(func(event *tcell.EventKey) *tcell.EventKey {
		a.activePane = paneLibrary
		a.refreshChrome()
		if event.Key() == tcell.KeyTAB {
			a.setActivePane(paneQueue)
			return nil
		}
		return event
	})

	a.packageTable.SetBorder(true)
	a.packageTable.SetTitle(" Queue ")
	a.packageTable.SetSelectable(true, false)
	a.packageTable.SetFixed(1, 0)
	a.packageTable.SetBackgroundColor(theme.Panel)
	a.packageTable.SetBorderColor(theme.AccentWarm)
	a.packageTable.SetSelectedStyle(tcell.StyleDefault.Background(theme.AccentWarm).Foreground(theme.Background))
	a.packageTable.SetSelectionChangedFunc(func(row, _ int) {
		if row <= 0 {
			a.selectedRowIndex = 0
		} else {
			a.selectedRowIndex = row - 1
		}
		a.refreshDetails()
	})
	a.packageTable.SetSelectedFunc(func(row, _ int) {
		if row > 0 {
			a.toggleSelected(row - 1)
		}
	})
	a.packageTable.SetMouseCapture(func(action tview.MouseAction, event *tcell.EventMouse) (tview.MouseAction, *tcell.EventMouse) {
		if action != tview.MouseLeftDoubleClick {
			return action, event
		}

		x, y := event.Position()
		row, _ := a.packageTable.CellAt(x, y)
		if row > 0 {
			a.setActivePane(paneQueue)
			a.packageTable.Select(row, 0)
			a.toggleSelected(row - 1)
			return tview.MouseConsumed, nil
		}

		return action, event
	})
	a.packageTable.SetInputCapture(func(event *tcell.EventKey) *tcell.EventKey {
		a.activePane = paneQueue
		a.refreshChrome()
		switch event.Key() {
		case tcell.KeyTAB:
			a.setActivePane(paneLibrary)
			return nil
		case tcell.KeyRune:
			if event.Rune() == ' ' {
				row, _ := a.packageTable.GetSelection()
				if row > 0 {
					a.toggleSelected(row - 1)
				}
				return nil
			}
		}
		return event
	})

	a.details.
		SetDynamicColors(true).
		SetWordWrap(true).
		SetWrap(true).
		SetBorder(true).
		SetTitle(" Details ")
	a.details.SetBackgroundColor(theme.Panel)
	a.details.SetBorderColor(theme.Accent)
	a.details.SetTextColor(theme.Text)

	content := tview.NewFlex().
		AddItem(a.tree, 30, 1, true).
		AddItem(
			tview.NewFlex().
				SetDirection(tview.FlexRow).
				AddItem(a.packageTable, 0, 2, false).
				AddItem(a.details, 0, 1, false),
			0,
			3,
			false,
		)

	root := tview.NewFlex().
		SetDirection(tview.FlexRow).
		AddItem(a.header, 5, 0, false).
		AddItem(content, 0, 1, true).
		AddItem(a.status, 2, 0, false)

	root.SetBackgroundColor(theme.Background)
	a.pages.AddPage("main", root, true, true)
	if a.logo != "" {
		a.pages.AddPage("splash", a.buildSplash(), true, true)
	}
	a.refreshChrome()
	a.updateStatus()
}

func (a *App) buildSplash() tview.Primitive {
	logoLines := strings.Count(a.logo, "\n") + 1
	logoView := tview.NewTextView().
		SetTextAlign(tview.AlignCenter).
		SetText(a.renderSplash()).
		SetWrap(false)
	logoView.SetTextColor(theme.Text)
	logoView.SetBackgroundColor(theme.Panel)

	card := tview.NewFrame(logoView)
	card.SetBorders(1, 1, 1, 1, 3, 3)
	card.SetBorder(true)
	card.SetTitle(" Caracal ")
	card.SetBorderColor(theme.Accent)
	card.SetBackgroundColor(theme.Panel)
	card.AddText("Press Enter, Space, or Esc to continue", true, tview.AlignCenter, theme.Muted)

	splash := tview.NewFlex().
		SetDirection(tview.FlexRow).
		AddItem(nil, 0, 1, false).
		AddItem(card, logoLines+8, 0, true).
		AddItem(nil, 0, 1, false)
	splash.SetBackgroundColor(theme.Background)

	return splash
}

func (a *App) populateTree() {
	selectedTreeStyle := tcell.StyleDefault.Background(theme.Accent).Foreground(theme.Background)
	root := tview.NewTreeNode("Software").
		SetColor(theme.Text).
		SetSelectable(false).
		SetSelectedTextStyle(selectedTreeStyle)

	for _, category := range a.categories {
		categoryNode := tview.NewTreeNode(category.Name).
			SetColor(theme.Accent).
			SetReference(&nodeRef{Category: category}).
			SetSelectedTextStyle(selectedTreeStyle)

		for _, subcategory := range category.Subcategories {
			count := len(subcategory.Packages)
			label := fmt.Sprintf("%s [%d]", subcategory.Name, count)
			subNode := tview.NewTreeNode(label).
				SetColor(theme.Text).
				SetReference(&nodeRef{
					Category:    category,
					Subcategory: subcategory,
				}).
				SetSelectedTextStyle(selectedTreeStyle)
			categoryNode.AddChild(subNode)
		}

		categoryNode.SetExpanded(true)
		root.AddChild(categoryNode)
	}

	root.SetExpanded(true)
	a.tree.SetRoot(root).SetCurrentNode(root)
}

func (a *App) setCurrentCategory(category *catalog.Category) {
	if category == nil {
		return
	}

	a.currentCategory = category
	if len(category.Subcategories) == 0 {
		a.currentSubcat = nil
	} else if a.currentSubcat == nil || !subcategoryBelongsTo(category, a.currentSubcat) {
		a.currentSubcat = category.Subcategories[0]
	}

	a.selectedRowIndex = 0
	a.refreshPackageTable()
}

func (a *App) refreshStates() {
	for _, category := range a.categories {
		for _, subcategory := range category.Subcategories {
			for _, pkg := range subcategory.Packages {
				a.states[pkg.ID] = installer.Detect(pkg)
			}
		}
	}
}

func (a *App) refreshPackageTable() {
	a.packageTable.Clear()

	headers := []string{"Sel", "State", "Package", "Summary"}
	for column, value := range headers {
		cell := tview.NewTableCell(value).
			SetTextColor(theme.AccentWarm).
			SetSelectable(false).
			SetExpansion(1)
		a.packageTable.SetCell(0, column, cell)
	}

	if a.currentSubcat == nil || len(a.currentSubcat.Packages) == 0 {
		a.packageTable.SetCell(1, 0, tview.NewTableCell("No installers yet").SetTextColor(theme.Muted).SetSelectable(false))
		a.refreshDetails()
		a.updateStatus()
		return
	}

	for index, pkg := range a.currentSubcat.Packages {
		state := a.states[pkg.ID]
		mark := "[ ]"
		markColor := theme.Muted
		if a.selected[pkg.ID] {
			mark = "[x]"
			markColor = theme.Accent
		}

		statusText := "Available"
		statusColor := theme.Accent
		if state.Installed {
			statusText = "Installed"
			statusColor = theme.Success
		} else if !state.InstallAvailable {
			statusText = "Unavailable"
			statusColor = theme.Danger
		}

		markCell := tview.NewTableCell(mark).
			SetTextColor(markColor).
			SetAlign(tview.AlignCenter).
			SetMaxWidth(5)
		if a.selected[pkg.ID] {
			markCell.SetSelectedStyle(tcell.StyleDefault.Background(theme.Panel).Foreground(theme.Success).Bold(true))
		} else {
			markCell.SetSelectedStyle(tcell.StyleDefault.Background(theme.Panel).Foreground(theme.Muted).Bold(true))
		}

		a.packageTable.SetCell(index+1, 0, markCell)
		a.packageTable.SetCell(index+1, 1, tview.NewTableCell(statusText).SetTextColor(statusColor))
		a.packageTable.SetCell(index+1, 2, tview.NewTableCell(pkg.Name).SetTextColor(theme.Text).SetExpansion(1))
		a.packageTable.SetCell(index+1, 3, tview.NewTableCell(pkg.Summary).SetTextColor(theme.Muted).SetExpansion(4))
	}

	if a.selectedRowIndex >= len(a.currentSubcat.Packages) {
		a.selectedRowIndex = len(a.currentSubcat.Packages) - 1
	}
	if a.selectedRowIndex < 0 {
		a.selectedRowIndex = 0
	}

	a.packageTable.Select(a.selectedRowIndex+1, 0)
	a.refreshDetails()
	a.updateStatus()
}

func (a *App) refreshDetails() {
	if a.currentCategory == nil || a.currentSubcat == nil {
		a.details.SetText("[#94a3b8]Select a category to view installers.")
		return
	}

	if len(a.currentSubcat.Packages) == 0 {
		a.details.SetText(fmt.Sprintf(
			"[#38bdf8]%s[-]\n[#e5eefb]%s[-]\n\n[#94a3b8]%s[-]",
			a.currentSubcat.Name,
			a.currentCategory.Name,
			a.currentSubcat.Description,
		))
		return
	}

	if a.selectedRowIndex < 0 || a.selectedRowIndex >= len(a.currentSubcat.Packages) {
		a.selectedRowIndex = 0
	}

	pkg := a.currentSubcat.Packages[a.selectedRowIndex]
	state := a.states[pkg.ID]

	var builder strings.Builder
	builder.WriteString(fmt.Sprintf("[#38bdf8]%s[-]  [#94a3b8]%s[-]\n", pkg.Name, pkg.Vendor))
	builder.WriteString(fmt.Sprintf("[#e5eefb]%s[-]\n\n", pkg.Description))
	builder.WriteString(fmt.Sprintf("[#f59e0b]Category[-]  %s / %s\n", a.currentCategory.Name, a.currentSubcat.Name))

	stateLine := "[#fbbf24]Ready to install[-]"
	if state.Installed && state.UninstallAvailable {
		stateLine = "[#4ade80]Installed; selecting will queue uninstall[-]"
	} else if state.Installed {
		stateLine = "[#4ade80]Installed[-]"
	} else if !state.InstallAvailable {
		stateLine = "[#fb7185]Not currently installable from the TUI[-]"
	}
	builder.WriteString(fmt.Sprintf("[#f59e0b]Status[-]    %s\n", stateLine))

	if pkg.AvailabilityNote != "" {
		builder.WriteString(fmt.Sprintf("[#f59e0b]Access[-]    [#94a3b8]%s[-]\n", pkg.AvailabilityNote))
	}

	if len(pkg.Notes) > 0 {
		builder.WriteString("\n[#f59e0b]Notes[-]\n")
		for _, note := range pkg.Notes {
			builder.WriteString(fmt.Sprintf(" • %s\n", note))
		}
	}

	builder.WriteString("\n[#f59e0b]Actions[-]\n")
	for _, action := range pkg.InstallActions {
		builder.WriteString(fmt.Sprintf(" • %s\n", action.Title))
	}
	for _, action := range pkg.UninstallActions {
		builder.WriteString(fmt.Sprintf(" • %s\n", action.Title))
	}

	a.details.SetText(builder.String())
}

func (a *App) updateStatus() {
	selectedCount := len(a.selectedPackages())
	totalCount := catalog.CountPackages(a.categories)
	location := "Browse the catalog"
	if a.currentCategory != nil && a.currentSubcat != nil {
		location = fmt.Sprintf("%s / %s", a.currentCategory.Name, a.currentSubcat.Name)
	}

	a.status.SetText(fmt.Sprintf(
		"[#e5eefb]%s[-]    [#94a3b8]%d selected[-]    [#94a3b8]%d packages in catalog[-]\n[#94a3b8]Tab switch panels  Space select  R install/uninstall  C clear  Q quit[-]",
		location,
		selectedCount,
		totalCount,
	))
}

func (a *App) toggleSelected(index int) {
	if a.currentSubcat == nil || index < 0 || index >= len(a.currentSubcat.Packages) {
		return
	}

	pkg := a.currentSubcat.Packages[index]
	state := a.states[pkg.ID]
	if !a.canQueue(state) {
		message := fmt.Sprintf("%s is listed in the catalog, but it is not currently actionable from the TUI.", pkg.Name)
		if pkg.AvailabilityNote != "" {
			message = pkg.AvailabilityNote
		}
		a.showInfoModal("Unavailable", message)
		return
	}

	if a.selected[pkg.ID] {
		delete(a.selected, pkg.ID)
	} else {
		a.selected[pkg.ID] = true
	}

	a.refreshPackageTable()
}

func (a *App) selectedPackages() []*catalog.Package {
	var packages []*catalog.Package
	for _, category := range a.categories {
		for _, subcategory := range category.Subcategories {
			for _, pkg := range subcategory.Packages {
				if a.selected[pkg.ID] {
					packages = append(packages, pkg)
				}
			}
		}
	}
	return packages
}

func (a *App) canQueue(state installer.PackageState) bool {
	if state.Installed {
		return state.UninstallAvailable
	}
	return state.InstallAvailable
}

func (a *App) resolveJobs() ([]installer.Job, []string) {
	selected := a.selectedPackages()
	jobs := make([]installer.Job, 0, len(selected))
	var skipped []string

	for _, pkg := range selected {
		state := a.states[pkg.ID]
		switch {
		case state.Installed && state.UninstallAvailable:
			jobs = append(jobs, installer.Job{Package: pkg, Mode: installer.ModeUninstall})
		case !state.Installed && state.InstallAvailable:
			jobs = append(jobs, installer.Job{Package: pkg, Mode: installer.ModeInstall})
		default:
			skipped = append(skipped, pkg.Name)
		}
	}

	return jobs, skipped
}

func (a *App) reviewAndInstall() {
	jobs, skipped := a.resolveJobs()
	if len(jobs) == 0 {
		a.showInfoModal("Nothing selected", "Select one or more packages before starting an install run.")
		return
	}

	var builder strings.Builder
	builder.WriteString("Queued actions:\n\n")
	for _, job := range jobs {
		builder.WriteString(" • ")
		builder.WriteString(job.Package.Name)
		builder.WriteString(" → ")
		builder.WriteString(strings.ToUpper(string(job.Mode)))
		builder.WriteByte('\n')
	}
	if len(skipped) > 0 {
		builder.WriteString("\nSkipped:\n")
		for _, name := range skipped {
			builder.WriteString(" • ")
			builder.WriteString(name)
			builder.WriteByte('\n')
		}
	}
	builder.WriteString("\nThe TUI will suspend while installers run so sudo prompts and download output can use the terminal directly.")

	modal := tview.NewModal().
		SetText(builder.String()).
		AddButtons([]string{"Run", "Cancel"}).
		SetDoneFunc(func(buttonIndex int, buttonLabel string) {
			a.pages.RemovePage("modal")
			if buttonLabel == "Run" {
				a.executeSelected(jobs)
			}
		})
	modal.SetBackgroundColor(theme.Background)

	a.pages.AddPage("modal", modal, true, true)
}

func (a *App) executeSelected(jobs []installer.Job) {
	var results []installer.Result

	a.app.Suspend(func() {
		results = installer.Run(jobs)
	})

	for _, result := range results {
		if result.Success {
			delete(a.selected, result.PackageID)
		}
	}

	a.refreshStates()
	a.refreshPackageTable()
	a.showResults(results)
}

func (a *App) showResults(results []installer.Result) {
	var successCount int
	var failureCount int
	var builder strings.Builder

	for _, result := range results {
		if result.Success {
			successCount++
			builder.WriteString(" • ")
			builder.WriteString(result.PackageName)
			builder.WriteString(": ")
			builder.WriteString(string(result.Mode))
			builder.WriteString(" complete\n")
			continue
		}

		failureCount++
		builder.WriteString(" • ")
		builder.WriteString(result.PackageName)
		builder.WriteString(": ")
		builder.WriteString(result.Error.Error())
		builder.WriteByte('\n')
	}

	title := "Run summary"
	if failureCount == 0 {
		title = "Run complete"
	}

	a.showInfoModal(
		title,
		fmt.Sprintf("%d succeeded, %d failed.\n\n%s", successCount, failureCount, strings.TrimSpace(builder.String())),
	)
}

func (a *App) showInfoModal(title string, message string) {
	modal := tview.NewModal().
		SetText(fmt.Sprintf("%s\n\n%s", title, message)).
		AddButtons([]string{"Close"}).
		SetDoneFunc(func(buttonIndex int, buttonLabel string) {
			a.pages.RemovePage("modal")
		})
	modal.SetBackgroundColor(theme.Background)
	a.pages.AddPage("modal", modal, true, true)
}

func (a *App) renderHeader() string {
	return "[#38bdf8::b]Caracal Software Installer[-:-:-]\n[#e5eefb]Guided post-install setup for DAWs, plugins, and audio tooling[-:-:-]\n[#94a3b8]Queue multiple installers, move between categories, and run them in a single pass.[-:-:-]"
}

func (a *App) renderSplash() string {
	return fmt.Sprintf(
		"[#38bdf8::b]%s[-:-:-]\n\n[#e5eefb]Caracal Software Installer[-:-:-]\n[#94a3b8]Guided post-install setup for DAWs, plugins, instruments, and audio tooling.[-:-:-]",
		tview.Escape(a.logo),
	)
}

func (a *App) handleGlobalKeys(event *tcell.EventKey) *tcell.EventKey {
	if a.pages.HasPage("splash") {
		switch event.Key() {
		case tcell.KeyEnter, tcell.KeyEsc:
			a.pages.RemovePage("splash")
			a.setActivePane(paneLibrary)
			return nil
		case tcell.KeyRune:
			if event.Rune() == ' ' {
				a.pages.RemovePage("splash")
				a.setActivePane(paneLibrary)
				return nil
			}
		}
	}

	switch event.Key() {
	case tcell.KeyCtrlC:
		a.app.Stop()
		return nil
	case tcell.KeyTAB:
		if a.activePane == paneLibrary {
			a.setActivePane(paneQueue)
		} else {
			a.setActivePane(paneLibrary)
		}
		return nil
	}

	if event.Key() != tcell.KeyRune {
		return event
	}

	switch strings.ToLower(string(event.Rune())) {
	case "q":
		a.app.Stop()
		return nil
	case "c":
		a.selected = make(map[string]bool)
		a.refreshPackageTable()
		return nil
	case "r", "i":
		a.reviewAndInstall()
		return nil
	}

	return event
}

func subcategoryBelongsTo(category *catalog.Category, target *catalog.Subcategory) bool {
	for _, subcategory := range category.Subcategories {
		if subcategory == target {
			return true
		}
	}
	return false
}

func (a *App) setActivePane(pane string) {
	a.activePane = pane
	switch pane {
	case paneQueue:
		a.app.SetFocus(a.packageTable)
	default:
		a.activePane = paneLibrary
		a.app.SetFocus(a.tree)
	}

	a.refreshChrome()
}

func (a *App) refreshChrome() {
	libraryActive := a.activePane == paneLibrary
	queueActive := a.activePane == paneQueue

	if libraryActive {
		a.tree.SetBorderColor(theme.Accent)
		a.tree.SetTitle(" Library • Active ")
		a.setTreeSelectionStyle(tcell.StyleDefault.Background(theme.Accent).Foreground(theme.Background))
	} else {
		a.tree.SetBorderColor(theme.FocusMute)
		a.tree.SetTitle(" Library ")
		a.setTreeSelectionStyle(tcell.StyleDefault.Background(theme.Panel).Foreground(theme.Muted))
	}

	if queueActive {
		a.packageTable.SetBorderColor(theme.AccentWarm)
		a.packageTable.SetTitle(" Queue • Active ")
		a.details.SetBorderColor(theme.AccentWarm)
		a.details.SetTitle(" Details • Active ")
		a.packageTable.SetSelectedStyle(tcell.StyleDefault.Background(theme.AccentWarm).Foreground(theme.Background))
	} else {
		a.packageTable.SetBorderColor(theme.FocusMute)
		a.packageTable.SetTitle(" Queue ")
		a.details.SetBorderColor(theme.FocusMute)
		a.details.SetTitle(" Details ")
		a.packageTable.SetSelectedStyle(tcell.StyleDefault.Background(theme.Background).Foreground(theme.Text))
	}
}

func (a *App) setTreeSelectionStyle(style tcell.Style) {
	root := a.tree.GetRoot()
	if root == nil {
		return
	}

	var walk func(node *tview.TreeNode)
	walk = func(node *tview.TreeNode) {
		node.SetSelectedTextStyle(style)
		for _, child := range node.GetChildren() {
			walk(child)
		}
	}

	walk(root)
}
