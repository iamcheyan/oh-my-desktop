package backend

import (
	"bytes"
	"os/exec"
	"path/filepath"
	"strings"
)

type Backend struct {
	Root string
}

type Result struct {
	Lines []string
	Err   error
}

func New(root string) Backend {
	return Backend{Root: root}
}

func (b Backend) Bin(name string) string {
	return filepath.Join(b.Root, "bin", name)
}

func (b Backend) Run(name string, args ...string) Result {
	cmd := exec.Command(b.Bin(name), args...)
	cmd.Dir = b.Root

	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &out
	err := cmd.Run()

	return Result{
		Lines: splitLines(out.String()),
		Err:   err,
	}
}

func ParseKV(lines []string) map[string]string {
	values := make(map[string]string)
	for _, line := range lines {
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		values[strings.TrimSpace(key)] = strings.TrimSpace(value)
	}
	return values
}

func splitLines(text string) []string {
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = strings.TrimRight(text, "\n")
	if text == "" {
		return nil
	}
	return strings.Split(text, "\n")
}
