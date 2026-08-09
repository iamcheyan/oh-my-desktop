/*
 * sumika-overview-thumbnaild — labwc-only window thumbnail daemon for the
 * Sumika Shell overview module.
 *
 * Binds three Wayland protocols offered by labwc:
 *   - ext_foreign_toplevel_list_v1          window list + identifier (grim -T key)
 *   - ext_workspace_manager_v1              workspace list + activate (switch)
 *   - zwlr_foreign_toplevel_manager_v1      activated state (focus tracking)
 *
 * Workspace attribution: the Wayland protocol stack has no window→workspace
 * mapping (labwc does not expose it). We approximate it with the activation
 * history: when a window receives ACTIVATED while workspace W is active, it
 * is remembered as belonging to W. Windows with no recorded attribution are
 * reported with an empty workspace and shown by the UI in the current
 * workspace with an "unknown" marker.
 *
 * Thumbnails are captured by shelling out to grim(1) with -T <identifier>.
 * Captures are written to $SUMIKA_SHELL_STATE_HOME/overview-thumbs/ atomically
 * (tmp file + rename) so the QML side never reads a half-written PNG.
 *
 * Clients (the overview QML process) connect to a unix stream socket at
 * $SUMIKA_SHELL_RUNTIME_DIR/overview-thumbnaild.sock and exchange
 * newline-delimited JSON:
 *   out: {"type":"snapshot","seq":N,"activeWorkspace":"1",
 *         "workspaces":[{"name":"1","active":true},...],
 *         "windows":[{"identifier":"...","title":"...","app_id":"...",
 *                     "workspace":"1","active":true,
 *                     "thumb":"/abs/path.png","exists":true},...]}
 *   in:  {"cmd":"activate-workspace","name":"2"}
 *        {"cmd":"activate-window","identifier":"..."}
 *        {"cmd":"send-to-workspace","identifier":"...","workspace":"3",
 *         "follow":true|false}
 *        {"cmd":"refresh"}
 *
 * labwc-only: exits 0 immediately when ext_foreign_toplevel_list_v1 is not
 * advertised (e.g. Hyprland) so it is a no-op outside labwc sessions.
 *
 * License: MIT. Protocol XMLs are vendored alongside this file.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <dirent.h>
#include <sys/file.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include <wayland-client.h>
#include "ext-ftl-client.h"
#include "ext-ws-client.h"
#include "wlr-ftl-client.h"

#define ARRAY_LEN(a) (sizeof(a) / sizeof(a[0]))
#define THUMB_DEBOUNCE_MS 250
#define MAX_CLIENTS 8

/* ---------------- data model ---------------- */

struct window {
	char *identifier;
	char *title;
	char *app_id;
	char *workspace;      /* last workspace where activated, or NULL */
	bool active;          /* currently activated (zwlr matched) */
	struct window *next;
};

struct workspace {
	char *name;
	bool active;
	struct workspace *next;
};

/* wlr toplevel handle mirror (for activated tracking + matching) */
struct wlr_toplevel {
	struct zwlr_foreign_toplevel_handle_v1 *handle;
	char *title;
	char *app_id;
	bool activated;
	bool minimized;
	struct wlr_toplevel *next;
};

/* ---------------- globals ---------------- */

static struct wl_display *display;
static struct ext_foreign_toplevel_list_v1 *ftl_list;
static struct ext_workspace_manager_v1 *ws_mgr;
static struct zwlr_foreign_toplevel_manager_v1 *wlr_mgr;
static struct wl_seat *seat;

static struct window *windows;
static struct workspace *workspaces;
static struct wlr_toplevel *wlr_toplevels;

static char *active_workspace;      /* name of active workspace or NULL */
static bool debounce_pending;
static bool capture_in_flight;
static time_t last_broadcast;
static int seq;

static int listen_fd = -1;
static int clients[MAX_CLIENTS];
static int client_count;
static char sock_path[4096];
static char thumbs_dir[4096];
static bool grim_ok;
static bool quitting;
static volatile sig_atomic_t child_exited;

/* ydotool client socket (YDOTOOL_SOCKET env). Probed at startup: the
 * daemon's socket path varies by distro (systemd ydotoold drop-in here
 * uses /tmp/.ydotool_socket; the default is $XDG_RUNTIME_DIR/.ydotool_socket). */
static char ydotool_sock[128] = "";

/* forward decls (workspace handlers reference socket machinery) */
static void activate_workspace_by_name(const char *name);
static bool activate_window_by_identifier(const char *identifier);
static void synth_move_key(int ws, bool follow);
static void register_ws_handle(struct ext_workspace_handle_v1 *h,
		const char *name);
static bool identity_match(const char *a_app, const char *a_title,
		const char *b_app, const char *b_title);
static int wlr_group_index(const struct wlr_toplevel *t);
static struct window *nth_matching_window(const struct wlr_toplevel *t, int k);
static struct window *find_window_by_identifier(const char *identifier);

/* ---------------- small helpers ---------------- */

static void
json_escape(FILE *f, const char *s)
{
	if (!s) {
		fputs("\"\"", f);
		return;
	}
	fputc('"', f);
	for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
		switch (*p) {
		case '"':  fputs("\\\"", f); break;
		case '\\': fputs("\\\\", f); break;
		case '\n': fputs("\\n", f); break;
		case '\r': fputs("\\r", f); break;
		case '\t': fputs("\\t", f); break;
		default:
			if (*p < 0x20)
				fprintf(f, "\\u%04x", *p);
			else
				fputc(*p, f);
		}
	}
	fputc('"', f);
}

static bool
file_exists(const char *path)
{
	struct stat st;
	return stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

/* ---------------- grim capture ---------------- */

static void
capture_window(struct window *w)
{
	if (!grim_ok || !w->identifier)
		return;

	char out[4600], tmp[4600];
	snprintf(out, sizeof out, "%s/%s.png", thumbs_dir, w->identifier);
	snprintf(tmp, sizeof tmp, "%s/.%s.png.tmp", thumbs_dir, w->identifier);

	pid_t pid = fork();
	if (pid < 0)
		return;
	if (pid == 0) {
		/* child: capture then atomically rename */
		int devnull = open("/dev/null", O_RDWR);
		if (devnull >= 0) {
			dup2(devnull, STDIN_FILENO);
			dup2(devnull, STDOUT_FILENO);
			dup2(devnull, STDERR_FILENO);
			close(devnull);
		}
		execlp("grim", "grim", "-T", w->identifier, tmp, NULL);
		_exit(127);
	}
	/* parent: grim writes tmp; a SIGCHLD handler renames it to out */
	/* (rename happens in reap_children below) */
	capture_in_flight = true;
}

static void
reap_children(void)
{
	int status;
	pid_t pid;
	while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
		(void)pid; (void)status;
	}
	capture_in_flight = false;

	/* Grim was exec'd in the child, so it cannot rename its own output.
	 * Promote any finished .tmp capture to its final name here. */
	DIR *dir = opendir(thumbs_dir);
	if (!dir)
		return;
	struct dirent *e;
	while ((e = readdir(dir)) != NULL) {
		size_t len = strlen(e->d_name);
		if (len < 5 || strcmp(e->d_name + len - 4, ".tmp") != 0)
			continue;
		if (e->d_name[0] != '.')
			continue; /* safety: only our dot-prefixed tmp files */
		char tmp[4600], out[4600];
		snprintf(tmp, sizeof tmp, "%s/%s", thumbs_dir, e->d_name);
		/* .<id>.png.tmp -> <id>.png */
		snprintf(out, sizeof out, "%s/%.*s", thumbs_dir,
				(int)(len - 5), e->d_name + 1);
		rename(tmp, out);
	}
	closedir(dir);
}

/* ---------------- snapshot broadcast ---------------- */

static void
write_snapshot_to(int fd)
{
	FILE *f = fdopen(dup(fd), "w");
	if (!f)
		return;
	fprintf(f, "{\"type\":\"snapshot\",\"seq\":%d,\"activeWorkspace\":", ++seq);
	json_escape(f, active_workspace);
	fprintf(f, ",\"workspaces\":[");
	bool first = true;
	for (struct workspace *ws = workspaces; ws; ws = ws->next) {
		fprintf(f, "%s{\"name\":", first ? "" : ",");
		first = false;
		json_escape(f, ws->name);
		fprintf(f, ",\"active\":%s}", ws->active ? "true" : "false");
	}
	fprintf(f, "],\"windows\":[");
	first = true;
	for (struct window *w = windows; w; w = w->next) {
		/* Only current-workspace windows plus unattributed ones. */
		bool show = !w->workspace || (active_workspace
				&& strcmp(w->workspace, active_workspace) == 0);
		if (!show)
			continue;
		char thumb[4600];
		snprintf(thumb, sizeof thumb, "%s/%s.png", thumbs_dir, w->identifier);
		fprintf(f, "%s{\"identifier\":", first ? "" : ",");
		first = false;
		json_escape(f, w->identifier);
		fprintf(f, ",\"title\":");
		json_escape(f, w->title);
		fprintf(f, ",\"app_id\":");
		json_escape(f, w->app_id);
		fprintf(f, ",\"workspace\":");
		json_escape(f, w->workspace);
		fprintf(f, ",\"active\":%s", w->active ? "true" : "false");
		fprintf(f, ",\"thumb\":");
		json_escape(f, thumb);
		fprintf(f, ",\"exists\":%s}", file_exists(thumb) ? "true" : "false");
	}
	fprintf(f, "]}\n");
	fflush(f);
	fclose(f);
}

static void
broadcast_snapshot(void)
{
	for (int i = 0; i < client_count; i++)
		write_snapshot_to(clients[i]);
	last_broadcast = time(NULL);
}

/* ---------------- capture scheduling ---------------- */

/* Apply activation history: any wlr toplevel that is ACTIVATED right now
 * belongs to the active workspace; a toplevel that was deactivated loses
 * its active flag. Runs on every flush so attribution is independent of
 * event arrival order. */
static void
apply_activation_attribution(void)
{
	if (!active_workspace)
		return;
	for (struct wlr_toplevel *t = wlr_toplevels; t; t = t->next) {
		struct window *w = nth_matching_window(t, wlr_group_index(t));
		if (!w)
			continue;
		if (!t->activated) {
			w->active = false;
			continue;
		}
		w->active = true;
		if (!w->workspace || strcmp(w->workspace, active_workspace) != 0) {
			free(w->workspace);
			w->workspace = strdup(active_workspace);
		}
	}
}

static void
refresh_thumbnails(void)
{
	if (!grim_ok)
		return;
	capture_in_flight = false;
	apply_activation_attribution();
	for (struct window *w = windows; w; w = w->next) {
		bool show = !w->workspace || (active_workspace
				&& strcmp(w->workspace, active_workspace) == 0);
		if (show)
			capture_window(w);
	}
	reap_children();
	broadcast_snapshot();
}

static void
schedule_debounced_refresh(void)
{
	debounce_pending = true;
}

static void
flush_debounced(void)
{
	if (!debounce_pending)
		return;
	debounce_pending = false;
	reap_children();
	refresh_thumbnails();
}

/* ---------------- ext-foreign-toplevel-list ---------------- */

static void
ftl_handle_title(void *data, struct ext_foreign_toplevel_handle_v1 *h,
		const char *title)
{
	(void)h;
	struct window *w = data;
	free(w->title);
	w->title = strdup(title);
	schedule_debounced_refresh();
}

static void
ftl_handle_app_id(void *data, struct ext_foreign_toplevel_handle_v1 *h,
		const char *app_id)
{
	(void)h;
	struct window *w = data;
	free(w->app_id);
	w->app_id = strdup(app_id);
	schedule_debounced_refresh();
}

static void
ftl_handle_identifier(void *data, struct ext_foreign_toplevel_handle_v1 *h,
		const char *identifier)
{
	(void)h;
	struct window *w = data;
	free(w->identifier);
	w->identifier = strdup(identifier);
	schedule_debounced_refresh();
}

static void
ftl_handle_done(void *data, struct ext_foreign_toplevel_handle_v1 *h)
{
	(void)data; (void)h;
	schedule_debounced_refresh();
}

static void
ftl_handle_closed(void *data, struct ext_foreign_toplevel_handle_v1 *h)
{
	(void)h;
	struct window *w = data;
	/* remove from list */
	struct window **pp = &windows;
	while (*pp && *pp != w)
		pp = &(*pp)->next;
	if (*pp)
		*pp = w->next;
	free(w->identifier);
	free(w->title);
	free(w->app_id);
	free(w->workspace);
	free(w);
	schedule_debounced_refresh();
}

static const struct ext_foreign_toplevel_handle_v1_listener ftl_handle_listener = {
	.title = ftl_handle_title,
	.app_id = ftl_handle_app_id,
	.identifier = ftl_handle_identifier,
	.done = ftl_handle_done,
	.closed = ftl_handle_closed,
};

static void
ftl_list_toplevel(void *data, struct ext_foreign_toplevel_list_v1 *l,
		struct ext_foreign_toplevel_handle_v1 *h)
{
	(void)data; (void)l;
	struct window *w = calloc(1, sizeof *w);
	w->next = windows;
	windows = w;
	ext_foreign_toplevel_handle_v1_add_listener(h, &ftl_handle_listener, w);
}

static void
ftl_list_finished(void *data, struct ext_foreign_toplevel_list_v1 *l)
{
	(void)data; (void)l;
}

static const struct ext_foreign_toplevel_list_v1_listener ftl_list_listener = {
	.toplevel = ftl_list_toplevel,
	.finished = ftl_list_finished,
};

/* ---------------- ext-workspace ---------------- */

static void
ws_handle_id(void *data, struct ext_workspace_handle_v1 *h, const char *id)
{
	(void)data; (void)h; (void)id;
}

static void
ws_handle_name(void *data, struct ext_workspace_handle_v1 *h, const char *name)
{
	(void)h;
	struct workspace *ws = data;
	free(ws->name);
	ws->name = strdup(name);
	register_ws_handle(h, ws->name);
}

static void
ws_handle_coordinates(void *data, struct ext_workspace_handle_v1 *h,
		struct wl_array *coords)
{
	(void)data; (void)h; (void)coords;
}

static void
ws_handle_state(void *data, struct ext_workspace_handle_v1 *h,
		uint32_t state)
{
	(void)h;
	struct workspace *ws = data;
	ws->active = (state & EXT_WORKSPACE_HANDLE_V1_STATE_ACTIVE) != 0;
	if (ws->active) {
		free(active_workspace);
		active_workspace = strdup(ws->name);
		schedule_debounced_refresh();
	}
}

static void
ws_handle_capabilities(void *data, struct ext_workspace_handle_v1 *h,
		uint32_t caps)
{
	(void)data; (void)h; (void)caps;
}

static void
ws_handle_removed(void *data, struct ext_workspace_handle_v1 *h)
{
	(void)h;
	struct workspace *ws = data;
	struct workspace **pp = &workspaces;
	while (*pp && *pp != ws)
		pp = &(*pp)->next;
	if (*pp)
		*pp = ws->next;
	free(ws->name);
	free(ws);
}

static const struct ext_workspace_handle_v1_listener ws_handle_listener = {
	.id = ws_handle_id,
	.name = ws_handle_name,
	.coordinates = ws_handle_coordinates,
	.state = ws_handle_state,
	.capabilities = ws_handle_capabilities,
	.removed = ws_handle_removed,
};

static void
wsg_capabilities(void *data, struct ext_workspace_group_handle_v1 *g,
		uint32_t caps)
{
	(void)data; (void)g; (void)caps;
}

static void
wsg_output_enter(void *data, struct ext_workspace_group_handle_v1 *g,
		struct wl_output *o)
{
	(void)data; (void)g; (void)o;
}

static void
wsg_output_leave(void *data, struct ext_workspace_group_handle_v1 *g,
		struct wl_output *o)
{
	(void)data; (void)g; (void)o;
}

static void
wsg_workspace_enter(void *data, struct ext_workspace_group_handle_v1 *g,
		struct ext_workspace_handle_v1 *ws)
{
	/* Workspace handles are also announced via the manager's
	 * workspace event, where the listener is attached. Do not add a
	 * second listener here (duplicate add emits a warning). */
	(void)data; (void)g; (void)ws;
}

static void
wsg_workspace_leave(void *data, struct ext_workspace_group_handle_v1 *g,
		struct ext_workspace_handle_v1 *ws)
{
	(void)data; (void)g; (void)ws;
}

static void
wsg_removed(void *data, struct ext_workspace_group_handle_v1 *g)
{
	(void)data; (void)g;
}

static const struct ext_workspace_group_handle_v1_listener wsg_listener = {
	.capabilities = wsg_capabilities,
	.output_enter = wsg_output_enter,
	.output_leave = wsg_output_leave,
	.workspace_enter = wsg_workspace_enter,
	.workspace_leave = wsg_workspace_leave,
	.removed = wsg_removed,
};

static void
ws_mgr_workspace_group(void *data, struct ext_workspace_manager_v1 *m,
		struct ext_workspace_group_handle_v1 *g)
{
	(void)data; (void)m;
	ext_workspace_group_handle_v1_add_listener(g, &wsg_listener, NULL);
}

static void
ws_mgr_workspace(void *data, struct ext_workspace_manager_v1 *m,
		struct ext_workspace_handle_v1 *ws)
{
	(void)data; (void)m;
	struct workspace *w = calloc(1, sizeof *w);
	w->next = workspaces;
	workspaces = w;
	ext_workspace_handle_v1_add_listener(ws, &ws_handle_listener, w);
}

static void
ws_mgr_done(void *data, struct ext_workspace_manager_v1 *m)
{
	(void)data; (void)m;
}

static void
ws_mgr_finished(void *data, struct ext_workspace_manager_v1 *m)
{
	(void)data; (void)m;
}

static const struct ext_workspace_manager_v1_listener ws_mgr_listener = {
	.workspace_group = ws_mgr_workspace_group,
	.workspace = ws_mgr_workspace,
	.done = ws_mgr_done,
	.finished = ws_mgr_finished,
};

/* ---------------- zwlr foreign toplevel (activated) ---------------- */

static void
wlr_handle_title(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
		const char *title)
{
	(void)h;
	struct wlr_toplevel *t = data;
	free(t->title);
	t->title = strdup(title);
}

static void
wlr_handle_app_id(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
		const char *app_id)
{
	(void)h;
	struct wlr_toplevel *t = data;
	free(t->app_id);
	t->app_id = strdup(app_id);
}

static void
wlr_handle_output_enter(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
		struct wl_output *o)
{
	(void)data; (void)h; (void)o;
}

static void
wlr_handle_output_leave(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
		struct wl_output *o)
{
	(void)data; (void)h; (void)o;
}

/* Identity comparison used to correlate the two independent window
 * enumerations: ext-foreign-toplevel (struct window, carries the unique
 * identifier) and wlr-foreign-toplevel-management (struct wlr_toplevel,
 * only app_id+title). Same-identity windows (e.g. two kitty tmux tabs with
 * identical titles) are distinguished by their position in the lists, which
 * labwc emits in the same creation order on both protocols. */
static bool
identity_match(const char *a_app, const char *a_title,
		const char *b_app, const char *b_title)
{
	bool app_ok = (!a_app && !b_app)
		|| (a_app && b_app && strcmp(a_app, b_app) == 0);
	bool title_ok = (!a_title && !b_title)
		|| (a_title && b_title && strcmp(a_title, b_title) == 0);
	return app_ok && title_ok;
}

/* Index (0-based) of t among same-identity wlr toplevels — the position of
 * the matching ext window within its same-identity group. */
static int
wlr_group_index(const struct wlr_toplevel *t)
{
	int k = 0;
	for (const struct wlr_toplevel *p = wlr_toplevels; p && p != t;
			p = p->next) {
		if (identity_match(p->app_id, p->title, t->app_id, t->title))
			k++;
	}
	return k;
}

/* k-th same-identity ext window for the given wlr toplevel (0-based). */
static struct window *
nth_matching_window(const struct wlr_toplevel *t, int k)
{
	int seen = 0;
	for (struct window *w = windows; w; w = w->next) {
		if (identity_match(t->app_id, t->title, w->app_id, w->title)
				&& seen++ == k)
			return w;
	}
	return NULL;
}

/* Ext window carrying the given unique identifier, or NULL. */
static struct window *
find_window_by_identifier(const char *identifier)
{
	for (struct window *w = windows; w; w = w->next) {
		if (w->identifier && strcmp(w->identifier, identifier) == 0)
			return w;
	}
	return NULL;
}

static void
wlr_handle_state(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
		struct wl_array *state)
{
	(void)h;
	struct wlr_toplevel *t = data;
	bool activated = false;
	bool minimized = false;
	uint32_t *s;
	wl_array_for_each(s, state) {
		if (*s == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED)
			activated = true;
		else if (*s == ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED)
			minimized = true;
	}
	if (activated != t->activated || minimized != t->minimized) {
		fprintf(stderr, "thumbnaild: wlr-state title=[%s] activated=%d minimized=%d\n",
			t->title ? t->title : "?", activated, minimized);
		t->activated = activated;
		t->minimized = minimized;
		/* Attribution is applied in apply_activation_attribution()
		 * during the debounced flush — event arrival order between
		 * ext-ftl title/app_id and wlr state is not guaranteed. */
		schedule_debounced_refresh();
	}
}

static void
wlr_handle_done(void *data, struct zwlr_foreign_toplevel_handle_v1 *h)
{
	(void)data; (void)h;
}

static void
wlr_handle_closed(void *data, struct zwlr_foreign_toplevel_handle_v1 *h)
{
	(void)h;
	struct wlr_toplevel *t = data;
	fprintf(stderr, "thumbnaild: wlr-closed title=[%s]\n",
		t->title ? t->title : "?");
	struct wlr_toplevel **pp = &wlr_toplevels;
	while (*pp && *pp != t)
		pp = &(*pp)->next;
	if (*pp)
		*pp = t->next;
	free(t->title);
	free(t->app_id);
	free(t);
}

static void
wlr_handle_parent(void *data, struct zwlr_foreign_toplevel_handle_v1 *h,
		struct zwlr_foreign_toplevel_handle_v1 *parent)
{
	(void)data; (void)h; (void)parent;
}

static const struct zwlr_foreign_toplevel_handle_v1_listener wlr_handle_listener = {
	.title = wlr_handle_title,
	.app_id = wlr_handle_app_id,
	.output_enter = wlr_handle_output_enter,
	.output_leave = wlr_handle_output_leave,
	.state = wlr_handle_state,
	.done = wlr_handle_done,
	.closed = wlr_handle_closed,
	.parent = wlr_handle_parent,
};

static void
wlr_mgr_toplevel(void *data, struct zwlr_foreign_toplevel_manager_v1 *m,
		struct zwlr_foreign_toplevel_handle_v1 *h)
{
	(void)data; (void)m;
	struct wlr_toplevel *t = calloc(1, sizeof *t);
	t->handle = h;
	t->next = wlr_toplevels;
	wlr_toplevels = t;
	zwlr_foreign_toplevel_handle_v1_add_listener(h, &wlr_handle_listener, t);
}

static void
wlr_mgr_finished(void *data, struct zwlr_foreign_toplevel_manager_v1 *m)
{
	(void)data; (void)m;
}

static const struct zwlr_foreign_toplevel_manager_v1_listener wlr_mgr_listener = {
	.toplevel = wlr_mgr_toplevel,
	.finished = wlr_mgr_finished,
};

/* ---------------- registry ---------------- */

static void
registry_global(void *data, struct wl_registry *reg, uint32_t name,
		const char *iface, uint32_t version)
{
	(void)data; (void)version;
	if (strcmp(iface, ext_foreign_toplevel_list_v1_interface.name) == 0) {
		ftl_list = wl_registry_bind(reg, name,
			&ext_foreign_toplevel_list_v1_interface, 1);
		ext_foreign_toplevel_list_v1_add_listener(ftl_list,
			&ftl_list_listener, NULL);
	} else if (strcmp(iface, ext_workspace_manager_v1_interface.name) == 0) {
		ws_mgr = wl_registry_bind(reg, name,
			&ext_workspace_manager_v1_interface, 1);
		ext_workspace_manager_v1_add_listener(ws_mgr, &ws_mgr_listener, NULL);
	} else if (strcmp(iface,
			zwlr_foreign_toplevel_manager_v1_interface.name) == 0) {
		wlr_mgr = wl_registry_bind(reg, name,
			&zwlr_foreign_toplevel_manager_v1_interface, 3);
		zwlr_foreign_toplevel_manager_v1_add_listener(wlr_mgr,
			&wlr_mgr_listener, NULL);
	} else if (strcmp(iface, wl_seat_interface.name) == 0) {
		seat = wl_registry_bind(reg, name, &wl_seat_interface, 1);
	}
}

static void
registry_global_remove(void *data, struct wl_registry *reg, uint32_t name)
{
	(void)data; (void)reg; (void)name;
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_global,
	.global_remove = registry_global_remove,
};

/* ---------------- socket server ---------------- */

static void
close_client(int idx)
{
	if (idx < 0 || idx >= client_count)
		return;
	close(clients[idx]);
	memmove(&clients[idx], &clients[idx + 1],
		(client_count - idx - 1) * sizeof(clients[0]));
	client_count--;
}

static void
handle_client_input(int idx)
{
	char buf[1024];
	ssize_t n = read(clients[idx], buf, sizeof buf - 1);
	if (n <= 0) {
		close_client(idx);
		return;
	}
	buf[n] = '\0';

	/* parse newline-delimited JSON commands (keep it simple) */
	char *line = buf;
	while (line && *line) {
		char *nl = strchr(line, '\n');
		if (nl)
			*nl = '\0';
		fprintf(stderr, "thumbnaild: cmd: %s\n", line);
		if (strstr(line, "\"activate-workspace\"")) {
			const char *p = strstr(line, "\"name\":");
			if (p) {
				p += 7;
				while (*p == ' ' || *p == '\t')
					p++;
				/* strip quotes */
				char name[256] = "";
				if (*p == '"') {
					p++;
					int i = 0;
					while (*p && *p != '"' && i < 255)
						name[i++] = *p++;
				}
				activate_workspace_by_name(name);
			}
		} else if (strstr(line, "\"activate-window\"")) {
			const char *p = strstr(line, "\"identifier\":");
			if (p) {
				/* "identifier": is 13 chars (quote + identifier +
				 * quote + colon); skip exactly that to land on the
				 * opening quote of the value. p += 14 was an off-by-one
				 * that landed past the quote → empty identifier →
				 * activate_window_by_identifier("") silently bailed. */
				p += 13;
				while (*p == ' ' || *p == '\t')
					p++;
				char ident[64] = "";
				if (*p == '"') {
					p++;
					int i = 0;
					while (*p && *p != '"' && i < 63)
						ident[i++] = *p++;
				}
				activate_window_by_identifier(ident);
			}
		} else if (strstr(line, "\"send-to-workspace\"")) {
			const char *ip = strstr(line, "\"identifier\":");
			const char *wp = strstr(line, "\"workspace\":");
			if (ip && wp) {
				ip += 13; /* "identifier": — see activate-window */
				while (*ip == ' ' || *ip == '\t')
					ip++;
				char ident[64] = "";
				if (*ip == '"') {
					ip++;
					int i = 0;
					while (*ip && *ip != '"' && i < 63)
						ident[i++] = *ip++;
				}
				wp += 12; /* "workspace": — quote + 9 + quote + colon */
				while (*wp == ' ' || *wp == '\t')
					wp++;
				char wsname[32] = "";
				if (*wp == '"') {
					wp++;
					int i = 0;
					while (*wp && *wp != '"' && i < 31)
						wsname[i++] = *wp++;
				}
				bool follow = strstr(line, "\"follow\":true") != NULL;
				if (*ident && *wsname) {
					int ws = atoi(wsname);
					if (ws >= 1 && ws <= 5) {
						/* focus the target window first — SendToDesktop
						 * acts on the focused window only. Only synthesize
						 * the key if the window was actually found, else
						 * the key would move the *current* focus. */
						if (activate_window_by_identifier(ident))
							synth_move_key(ws, follow);
					} else {
						fprintf(stderr, "thumbnaild: send-to-workspace "
							"ws out of range '%s'\n", wsname);
					}
				}
			}
		} else if (strstr(line, "\"refresh\"")) {
			debounce_pending = false;
			refresh_thumbnails();
		} else if (strstr(line, "\"dbgstate\"")) {
			fprintf(stderr, "thumbnaild: dbgstate wlr_mgr=%p seat=%p "
				"ftl_list=%p ws_mgr=%p active_ws=%s\n",
				(void *)wlr_mgr, (void *)seat, (void *)ftl_list,
				(void *)ws_mgr, active_workspace ? active_workspace : "?");
			for (struct wlr_toplevel *t = wlr_toplevels; t; t = t->next) {
				fprintf(stderr, "thumbnaild:   wlr handle=%p title=[%s] "
					"app=[%s] activated=%d minimized=%d\n",
					(void *)t->handle, t->title ? t->title : "?",
					t->app_id ? t->app_id : "?", t->activated, t->minimized);
			}
			for (struct window *w = windows; w; w = w->next) {
				fprintf(stderr, "thumbnaild:   win id=%s title=[%s] "
					"active=%d ws=%s\n", w->identifier ? w->identifier : "?",
					w->title ? w->title : "?", w->active,
					w->workspace ? w->workspace : "?");
			}
		}
		if (!nl)
			break;
		line = nl + 1;
	}
}

/* workspace handles map (name → handle) for activate */
struct ws_handle {
	char *name;
	struct ext_workspace_handle_v1 *handle;
	struct ws_handle *next;
};
static struct ws_handle *ws_handles;

static void
register_ws_handle(struct ext_workspace_handle_v1 *h, const char *name)
{
	struct ws_handle *e = calloc(1, sizeof *e);
	e->handle = h;
	e->name = strdup(name);
	e->next = ws_handles;
	ws_handles = e;
}

static void
activate_workspace_by_name(const char *name)
{
	if (!ws_mgr || !name)
		return;
	for (struct ws_handle *e = ws_handles; e; e = e->next) {
		if (e->name && strcmp(e->name, name) == 0) {
			ext_workspace_handle_v1_activate(e->handle);
			ext_workspace_manager_v1_commit(ws_mgr);
			wl_display_flush(display);
			return;
		}
	}
	fprintf(stderr, "thumbnaild: no workspace '%s'\n", name);
}

/* Focus a window by ext-ftl identifier. labwc's request_activate handler
 * runs desktop_focus_view() → workspaces_switch_to(view->workspace), so a
 * single activate request both switches workspace and focuses the window.
 * Returns true if the window was found and the activate request was sent. */
static bool
activate_window_by_identifier(const char *identifier)
{
	if (!wlr_mgr || !seat || !identifier || !*identifier) {
		fprintf(stderr, "thumbnaild: activate blocked wlr_mgr=%p seat=%p id=%s\n",
			(void *)wlr_mgr, (void *)seat, identifier ? identifier : "?");
		return false;
	}
	struct window *target = find_window_by_identifier(identifier);
	if (!target) {
		fprintf(stderr, "thumbnaild: no window '%s'\n", identifier);
		return false;
	}
	/* labwc emits the ext and wlr enumerations in the same creation order,
	 * so same-identity windows (e.g. two kitty tmux tabs with identical
	 * titles) pair up by position: the target's index within its ext
	 * same-identity group selects the wlr toplevel at the same position. */
	int k = 0;
	for (struct window *w = windows; w && w != target; w = w->next) {
		if (identity_match(w->app_id, w->title,
					target->app_id, target->title))
			k++;
	}
	int seen = 0;
	for (struct wlr_toplevel *t = wlr_toplevels; t; t = t->next) {
		if (!identity_match(t->app_id, t->title,
					target->app_id, target->title))
			continue;
		if (seen++ != k)
			continue;
		fprintf(stderr, "thumbnaild: activating id=%s handle=%p title=[%s] "
			"activated=%d minimized=%d\n", identifier, (void *)t->handle,
			t->title ? t->title : "?", t->activated, t->minimized);
		zwlr_foreign_toplevel_handle_v1_activate(t->handle, seat);
		wl_display_flush(display);
		return true;
	}
	fprintf(stderr, "thumbnaild: no window '%s'\n", identifier);
	return false;
}

/* Send a window to another workspace.
 *
 * labwc has no IPC and its SendToDesktop action only ever targets the
 * *focused* window, so an external caller cannot address an arbitrary
 * window directly. We therefore (1) activate the target window via zwlr
 * (the same verified path as overview click), then (2) synthesize the
 * existing rc.xml keybind with ydotool:
 *     follow=yes → Super+Shift+N   (SendToDesktop to=N follow=yes)
 *     follow=no  → Super+Shift+Alt+N (SendToDesktop to=N follow=no)
 * The key synthesis runs in a forked child after a 200ms settle so labwc
 * has processed the activate request before the key event lands (the
 * activate is async: zwlr request + flush, compositor picks it up on its
 * own dispatch).
 *
 * Workspace names are the numeric "1".."5" from <desktops number="5"> in
 * rc.xml; named workspaces would need a name→digit mapping here.
 */
static void
synth_move_key(int ws, bool follow)
{
	/* KEY_LEFTMETA=125, KEY_LEFTSHIFT=42, KEY_LEFTALT=56; KEY_1..5=2..6 */
	char dkey[8];
	snprintf(dkey, sizeof(dkey), "%d", 1 + ws); /* ws 1..5 → 2..6 */

	pid_t pid = fork();
	if (pid < 0) {
		fprintf(stderr, "thumbnaild: fork failed for ydotool\n");
		return;
	}
	if (pid > 0) {
		fprintf(stderr, "thumbnaild: sent window to ws=%d follow=%d (child %d)\n",
			ws, follow ? 1 : 0, (int)pid);
		return;
	}
	/* child: wait for labwc to process the activate, then synthesize.
	 * press order meta,shift[,alt],digit; release in reverse.
	 * YDOTOOL_SOCKET must point at the running ydotoold (probed in
	 * setup_socket) — the client's default is the wrong path here. */
	if (!ydotool_sock[0]) {
		fprintf(stderr, "thumbnaild: ydotool socket not found, "
			"cannot move window\n");
		_exit(2);
	}
	setenv("YDOTOOL_SOCKET", ydotool_sock, 1);
	usleep(200000);
	if (follow) {
		execl("/usr/bin/ydotool", "ydotool", "key",
			"125:1", "42:1", dkey, dkey, "42:0", "125:0", (char *)NULL);
	} else {
		execl("/usr/bin/ydotool", "ydotool", "key",
			"125:1", "42:1", "56:1", dkey,
			dkey, "56:0", "42:0", "125:0", (char *)NULL);
	}
	_exit(127); /* execl only returns on failure */
}

static void
setup_socket(void)
{
	/* ydotool client socket: probe the common locations once. The daemon
	 * runs inside a labwc session where the user's session env (which may
	 * carry YDOTOOL_SOCKET) is present, but the value is not guaranteed —
	 * probe defaults as a fallback. */
	{
		const char *env_sock = getenv("YDOTOOL_SOCKET");
		if (env_sock && *env_sock && access(env_sock, W_OK) == 0) {
			snprintf(ydotool_sock, sizeof ydotool_sock, "%s", env_sock);
		} else {
			const char *xr = getenv("XDG_RUNTIME_DIR");
			char cand[128];
			if (xr && *xr) {
				snprintf(cand, sizeof cand, "%s/.ydotool_socket", xr);
				if (access(cand, W_OK) == 0) {
					snprintf(ydotool_sock, sizeof ydotool_sock, "%s", cand);
					goto probed;
				}
			}
			if (access("/tmp/.ydotool_socket", W_OK) == 0)
				snprintf(ydotool_sock, sizeof ydotool_sock,
					"/tmp/.ydotool_socket");
		}
	}
probed:
	fprintf(stderr, "thumbnaild: ydotool socket = %s\n",
		ydotool_sock[0] ? ydotool_sock : "(none)");

	const char *rt = getenv("SUMIKA_SHELL_RUNTIME_DIR");
	if (!rt || !*rt) {
		/* repo path contract (lib/paths.sh): XDG_RUNTIME_DIR/sumika-shell;
		 * matches the QML bridge's fallback. Sized to leave room for the
		 * "/overview-thumbnaild.sock" suffix in sock_path. */
		static char fallback[4000];
		const char *xr = getenv("XDG_RUNTIME_DIR");
		if (xr && *xr)
			snprintf(fallback, sizeof fallback, "%s/sumika-shell", xr);
		else
			snprintf(fallback, sizeof fallback, "/tmp/sumika-shell");
		rt = fallback;
	}
	snprintf(sock_path, sizeof sock_path, "%s/overview-thumbnaild.sock", rt);

	/* the runtime dir may not exist yet when launched from autostart
	 * before any other component created it */
	{
		char *slash = strrchr(sock_path, '/');
		if (slash && slash != sock_path) {
			*slash = '\0';
			mkdir(sock_path, 0755);
			*slash = '/';
		}
	}

	/* Single-instance guard. flock(2) on a sibling lock file: without it a
	 * second instance — e.g. a headless labwc running the shared autostart —
	 * would unlink() the live daemon's socket and steal it (observed
	 * 2026-08-09). The lock is released automatically when we exit. */
	static char lock_path[sizeof sock_path + 8];
	static int lock_fd = -1;
	snprintf(lock_path, sizeof lock_path, "%s.lock", sock_path);
	lock_fd = open(lock_path, O_CREAT | O_RDWR, 0600);
	if (lock_fd < 0) {
		perror("thumbnaild: lock");
		return;
	}
	if (flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
		fprintf(stderr, "thumbnaild: another instance holds %s, exiting\n",
			lock_path);
		close(lock_fd);
		lock_fd = -1;
		exit(0); /* no-op like the labwc gate, so autostart stays quiet */
	}

	listen_fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (listen_fd < 0) {
		perror("socket");
		return;
	}

	struct sockaddr_un addr = { .sun_family = AF_UNIX };
	if (strlen(sock_path) >= sizeof addr.sun_path) {
		fprintf(stderr, "thumbnaild: socket path too long\n");
		close(listen_fd);
		listen_fd = -1;
		return;
	}
	snprintf(addr.sun_path, sizeof addr.sun_path, "%s", sock_path);
	unlink(sock_path);
	if (bind(listen_fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
		perror("bind");
		close(listen_fd);
		listen_fd = -1;
		return;
	}
	if (listen(listen_fd, 4) < 0) {
		perror("listen");
		close(listen_fd);
		listen_fd = -1;
		return;
	}
	/* allow the overview process (same user) to connect */
	chmod(sock_path, 0600);
}

/* ---------------- main loop ---------------- */

static void
on_signal(int sig)
{
	(void)sig;
	quitting = true;
}

/* grim child finished: remember to reap (and promote .tmp -> .png) in the
 * main loop. Not async-signal-safe to scan the dir here. */
static void
on_sigchld(int sig)
{
	(void)sig;
	child_exited = 1;
}

static void
setup_paths(void)
{
	const char *state = getenv("SUMIKA_SHELL_STATE_HOME");
	if (!state || !*state) {
		/* repo path contract (lib/paths.sh): XDG_STATE_HOME/sumika-shell.
		 * Sized to leave room for the "/overview-thumbs" suffix. */
		static char fallback[4000];
		const char *xs = getenv("XDG_STATE_HOME");
		if (xs && *xs)
			snprintf(fallback, sizeof fallback, "%s/sumika-shell", xs);
		else
			snprintf(fallback, sizeof fallback, "%s/.local/state/sumika-shell",
					getenv("HOME") ? getenv("HOME") : "/tmp");
		state = fallback;
	}
	snprintf(thumbs_dir, sizeof thumbs_dir, "%s/overview-thumbs", state);
	mkdir(thumbs_dir, 0755);

	/* grim availability */
	grim_ok = (access("/usr/bin/grim", X_OK) == 0
			|| access("/bin/grim", X_OK) == 0
			|| access("/usr/local/bin/grim", X_OK) == 0);
	if (!grim_ok) {
		char *path = getenv("PATH");
		if (path) {
			char *copy = strdup(path);
			char *save = NULL;
			for (char *dir = strtok_r(copy, ":", &save); dir;
					dir = strtok_r(NULL, ":", &save)) {
				char probe[4096];
				snprintf(probe, sizeof probe, "%s/grim", dir);
				if (access(probe, X_OK) == 0) {
					grim_ok = true;
					break;
				}
			}
			free(copy);
		}
	}
	if (!grim_ok)
		fprintf(stderr, "thumbnaild: grim not found — thumbnails disabled\n");
}

int
main(int argc, char **argv)
{
	(void)argc; (void)argv;
	setvbuf(stdout, NULL, _IOLBF, 0);

	/* labwc-only gate: we need ext_foreign_toplevel_list_v1 */
	display = wl_display_connect(NULL);
	if (!display) {
		fprintf(stderr, "thumbnaild: cannot connect to Wayland\n");
		return 1;
	}

	struct wl_registry *reg = wl_display_get_registry(display);
	wl_registry_add_listener(reg, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_display_roundtrip(display);

	if (!ftl_list) {
		fprintf(stderr, "thumbnaild: ext_foreign_toplevel_list_v1 not "
			"advertised — not a labwc session, exiting\n");
		return 0; /* labwc-only: no-op elsewhere */
	}
	fprintf(stderr, "thumbnaild: labwc session detected, starting\n");

	setup_paths();
	setup_socket();

	/* capture initial state after a short settle */
	schedule_debounced_refresh();
	debounce_pending = false;
	refresh_thumbnails();

	struct sigaction sa = { .sa_handler = on_signal };
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	signal(SIGCHLD, on_sigchld); /* grim exited: reap + rename promptly */
	signal(SIGPIPE, SIG_IGN); /* writes to dead clients must not kill us */

	int wl_fd = wl_display_get_fd(display);
	struct pollfd fds[2 + MAX_CLIENTS];

	while (!quitting) {
		/* a grim child exited while we were in poll: promote its .tmp
		 * capture now so thumbnails appear without waiting for the next
		 * protocol event (which may never come on an idle desktop) */
		if (child_exited) {
			child_exited = 0;
			reap_children();
		}

		int nfds = 0;
		fds[nfds++] = (struct pollfd){ wl_fd, POLLIN, 0 };
		if (listen_fd >= 0)
			fds[nfds++] = (struct pollfd){ listen_fd, POLLIN, 0 };
		for (int i = 0; i < client_count && nfds < (int)ARRAY_LEN(fds); i++)
			fds[nfds++] = (struct pollfd){ clients[i], POLLIN, 0 };

		int tmo = debounce_pending ? THUMB_DEBOUNCE_MS : -1;
		int r = poll(fds, nfds, tmo);
		if (r < 0) {
			if (errno == EINTR)
				continue;
			fprintf(stderr, "thumbnaild: poll errno=%d\n", errno);
			break;
		}
		if (r == 0 && debounce_pending) {
			flush_debounced();
			continue;
		}

		/* display events */
		if (fds[0].revents & (POLLIN | POLLHUP)) {
			if (wl_display_dispatch(display) < 0) {
				fprintf(stderr, "thumbnaild: dispatch errno=%d\n", errno);
				if (errno != EAGAIN && errno != EINTR)
					break;
			}
		}

		/* new clients */
		if (listen_fd >= 0 && (fds[1].revents & POLLIN)) {
			int c = accept(listen_fd, NULL, NULL);
			if (c >= 0 && client_count < MAX_CLIENTS) {
				clients[client_count++] = c;
				write_snapshot_to(c); /* immediate state on connect */
			} else if (c >= 0) {
				close(c);
			}
		}

		/* client input — at most one client per poll round. Two hazards:
		 * (a) a client accepted after poll() leaves fds[idx] uninitialized
		 *     stack memory — reading .revents there is UB and can trigger a
		 *     blocking read on a silent fd; (b) handle_client_input may
		 *     close_client() (memmove compaction + count--), which shifts the
		 *     client array under any later fds[] revents checks. Processing
		 *     a single input per round and bounding idx by nfds avoids both. */
		for (int i = 0; i < client_count; i++) {
			int idx = 2 + i;
			if (idx >= nfds)
				break; /* accepted after poll; not polled this round */
			if (fds[idx].revents & (POLLIN | POLLHUP)) {
				handle_client_input(i);
				break;
			}
		}
	}

	/* cleanup */
	if (listen_fd >= 0) {
		close(listen_fd);
		unlink(sock_path);
	}
	for (int i = 0; i < client_count; i++)
		close(clients[i]);

	wl_display_disconnect(display);
	fprintf(stderr, "thumbnaild: exiting\n");
	return 0;
}
