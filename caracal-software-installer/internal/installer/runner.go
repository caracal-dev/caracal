package installer

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/caracal-os/caracal-software-installer/internal/catalog"
)

type PackageState struct {
	Installed          bool
	InstallAvailable   bool
	UninstallAvailable bool
}

type Mode string

const (
	ModeInstall   Mode = "install"
	ModeUninstall Mode = "uninstall"
)

type Job struct {
	Package *catalog.Package
	Mode    Mode
}

type Result struct {
	PackageID   string
	PackageName string
	Mode        Mode
	Success     bool
	Error       error
}

func Detect(pkg *catalog.Package) PackageState {
	state := PackageState{}

	for _, marker := range pkg.InstalledMarkers {
		if markerExists(marker) {
			state.Installed = true
			break
		}
	}

	state.InstallAvailable = actionsAvailable(pkg.InstallActions)
	state.UninstallAvailable = actionsAvailable(pkg.UninstallActions)

	return state
}

func Run(jobs []Job) []Result {
	results := make([]Result, 0, len(jobs))

	fmt.Println("Caracal Software Installer")
	fmt.Println("==========================")
	fmt.Println()

	for index, job := range jobs {
		pkg := job.Package
		fmt.Printf("[%d/%d] %s (%s)\n", index+1, len(jobs), pkg.Name, strings.ToUpper(string(job.Mode)))

		actions := pkg.InstallActions
		if job.Mode == ModeUninstall {
			actions = pkg.UninstallActions
		}

		var runErr error
		for _, action := range actions {
			fmt.Printf("  -> %s\n", action.Title)
			if err := runAction(action); err != nil {
				runErr = err
				break
			}
		}

		result := Result{
			PackageID:   pkg.ID,
			PackageName: pkg.Name,
			Mode:        job.Mode,
			Success:     runErr == nil,
			Error:       runErr,
		}
		results = append(results, result)

		if runErr != nil {
			fmt.Printf("  !! %v\n", runErr)
		} else {
			fmt.Println("  OK")
		}

		fmt.Println()
	}

	return results
}

func runAction(action catalog.Action) error {
	cmd := exec.Command(action.Exec[0], action.Exec[1:]...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%s failed: %w", action.Title, err)
	}

	return nil
}

func actionsAvailable(actions []catalog.Action) bool {
	if len(actions) == 0 {
		return false
	}

	for _, action := range actions {
		if len(action.Exec) == 0 {
			return false
		}

		if !commandExists(action.Exec[0]) {
			return false
		}

		for _, arg := range action.Exec[1:] {
			if looksLikePath(arg) {
				if _, err := os.Stat(arg); err != nil {
					return false
				}
			}
		}
	}

	return true
}

func markerExists(marker string) bool {
	if strings.ContainsAny(marker, "*?[") {
		matches, err := filepath.Glob(marker)
		return err == nil && len(matches) > 0
	}

	target := marker
	if !filepath.IsAbs(marker) {
		home, err := os.UserHomeDir()
		if err != nil {
			return false
		}
		target = filepath.Join(home, marker)
	}

	if strings.ContainsAny(target, "*?[") {
		matches, err := filepath.Glob(target)
		return err == nil && len(matches) > 0
	}

	_, err := os.Stat(target)
	return err == nil
}

func commandExists(command string) bool {
	if looksLikePath(command) {
		_, err := os.Stat(command)
		return err == nil
	}

	_, err := exec.LookPath(command)
	return err == nil
}

func looksLikePath(value string) bool {
	return strings.Contains(value, string(os.PathSeparator)) || strings.HasPrefix(value, ".")
}
