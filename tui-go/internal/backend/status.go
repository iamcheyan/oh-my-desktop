package backend

import "strings"

// Status is the parsed key=value output shared by every settings page. It
// keeps the raw output under "__raw__" so pages can pull multi-line records
// (bindings, devices, log lines) that do not fit the flat key=value model.
type Status map[string]string

// StatusMsg is the common tea.Msg emitted by FetchStatus.
type StatusMsg struct {
	Values Status
	Err    error
}

// ActionMsg is the common tea.Msg emitted by RunAction.
// Lines is optional command output for page activity logs.
type ActionMsg struct {
	Action string
	Err    error
	Lines  []string
}

// ParseStatus parses key=value lines into a Status and stashes the raw output
// under "__raw__" for pages that need multi-line records.
func ParseStatus(lines []string) Status {
	values := ParseKV(lines)
	values["__raw__"] = strings.Join(lines, "\n")
	return values
}

// Value returns the entry for key, or fallback when missing/empty.
func (s Status) Value(key, fallback string) string {
	if s == nil {
		return fallback
	}
	if v := s[key]; v != "" {
		return v
	}
	return fallback
}

// Bool returns true when the entry equals "true".
func (s Status) Bool(key string) bool {
	return s.Value(key, "false") == "true"
}

// Raw returns the original command output stashed by ParseStatus.
func (s Status) Raw() string {
	return s["__raw__"]
}