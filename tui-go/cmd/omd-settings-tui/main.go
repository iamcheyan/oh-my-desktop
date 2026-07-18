package main

import (
	"fmt"
	"os"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/iamcheyan/oh-my-desktop/tui-go/internal/backend"
	themepage "github.com/iamcheyan/oh-my-desktop/tui-go/internal/pages/theme"
	voicepage "github.com/iamcheyan/oh-my-desktop/tui-go/internal/pages/voice"
	windowspage "github.com/iamcheyan/oh-my-desktop/tui-go/internal/pages/windows"
)

func main() {
	route := "windows"
	if len(os.Args) > 1 {
		route = os.Args[1]
	}

	if route == "-h" || route == "--help" || route == "help" {
		printHelp()
		return
	}

	root, err := detectRoot()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	var model tea.Model
	switch route {
	case "windows", "windows-vm", "vm":
		model = windowspage.New(backend.New(root))
	case "theme", "appearance":
		model = themepage.New(backend.New(root))
	case "voice", "voice-input":
		model = voicepage.New(backend.New(root))
	default:
		fmt.Fprintf(os.Stderr, "unknown settings page: %s\n\n", route)
		printHelp()
		os.Exit(2)
	}

	if _, err := tea.NewProgram(model, tea.WithAltScreen(), tea.WithMouseCellMotion()).Run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func printHelp() {
	fmt.Println("Usage: omd-settings-tui [page]")
	fmt.Println()
	fmt.Println("Pages:")
	fmt.Println("  windows    Windows VM settings and connection controls")
	fmt.Println("  theme      Theme picker and active theme info")
	fmt.Println("  voice      Voice input setup, model, and keybindings")
}

func detectRoot() (string, error) {
	if root := os.Getenv("OMD_ROOT"); root != "" {
		return filepath.Clean(root), nil
	}

	wd, _ := os.Getwd()
	candidates := []string{
		wd,
		filepath.Dir(wd),
		filepath.Dir(filepath.Dir(wd)),
	}

	if exe, err := os.Executable(); err == nil {
		exeDir := filepath.Dir(exe)
		candidates = append(candidates, filepath.Dir(exeDir), filepath.Dir(filepath.Dir(exeDir)))
	}

	for _, candidate := range candidates {
		if candidate == "." || candidate == "/" {
			continue
		}
		if exists(filepath.Join(candidate, "bin", "omd-settings-windows-vm")) {
			return filepath.Clean(candidate), nil
		}
	}

	return "", fmt.Errorf("could not find OMD root; set OMD_ROOT")
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
