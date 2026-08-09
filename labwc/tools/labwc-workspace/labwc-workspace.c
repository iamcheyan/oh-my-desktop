/*
 * labwc-workspace — tiny Wayland client that reports the active labwc
 * workspace name over a unix socket.
 *
 * Binds ext_workspace_manager_v1 (offered by labwc 0.20.1) and pushes the
 * name of the active workspace to clients of a unix stream socket at
 * $SUMIKA_SHELL_RUNTIME_DIR/labwc-workspace.sock (fallback
 * $XDG_RUNTIME_DIR/sumika-shell/labwc-workspace.sock).
 *
 * Protocol: newline-delimited plain text, one workspace name per message
 * (e.g. "1", "0"). A newly connected client receives the current active
 * workspace immediately; changes are pushed to all connected clients.
 *
 * labwc-only: exits 0 immediately when ext_workspace_manager_v1 is not
 * advertised (e.g. Hyprland), so autostart can start it unconditionally.
 *
 * Consumed by quickshell/modules/workspaces/Workspaces.qml in labwc
 * sessions to render the "workspaces[N]" bar label.
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
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#include "ext-ws-client.h"

#define MAX_CLIENTS 8
#define ARRAY_LEN(a) (sizeof(a) / sizeof(a)[0])

static struct wl_display *display;
static struct ext_workspace_manager_v1 *ws_mgr;

struct workspace {
	struct workspace *next;
	char *name;
	bool active;
};

static struct workspace *workspaces;
static char *active_workspace; /* name of active workspace or NULL */

static int listen_fd = -1;
static int clients[MAX_CLIENTS];
static int client_count;
static char sock_path[4096];
static bool quitting;

/* ---------------- broadcast ---------------- */

static void
write_state_to(int fd)
{
	/* active_workspace may be NULL before the first state event; send an
	 * empty line so the client always gets a well-formed message. */
	dprintf(fd, "%s\n", active_workspace ? active_workspace : "");
}

static void
broadcast_state(void)
{
	for (int i = 0; i < client_count; i++)
		write_state_to(clients[i]);
}

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
		broadcast_state();
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
	if (ws->active) {
		/* the active workspace disappeared; clear the cached name */
		free(active_workspace);
		active_workspace = NULL;
		broadcast_state();
	}
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
	/* Handles are also announced via the manager's workspace event where
	 * the listener is attached; do not add a second one here. */
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

static void
registry_handle_global(void *data, struct wl_registry *registry,
		uint32_t name, const char *interface, uint32_t version)
{
	(void)data; (void)version;
	if (!strcmp(interface, ext_workspace_manager_v1_interface.name)) {
		ws_mgr = wl_registry_bind(registry, name,
			&ext_workspace_manager_v1_interface, 1);
		/*
		 * wlroots replays the full workspace state synchronously inside
		 * bind (manager_bind in wlr_ext_workspace_v1.c), so those events
		 * are already queued when the registry global arrives. The
		 * listener MUST be attached here, before the next roundtrip
		 * dispatches them — attaching later drops the initial state.
		 */
		if (ws_mgr)
			ext_workspace_manager_v1_add_listener(ws_mgr,
				&ws_mgr_listener, NULL);
	}
}

static void
registry_handle_global_remove(void *data, struct wl_registry *registry,
		uint32_t name)
{
	(void)data; (void)registry; (void)name;
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_handle_global,
	.global_remove = registry_handle_global_remove,
};

/* ---------------- unix socket ---------------- */

static void
setup_socket(void)
{
	const char *rt = getenv("SUMIKA_SHELL_RUNTIME_DIR");
	if (!rt || !*rt) {
		/* repo path contract (lib/paths.sh): XDG_RUNTIME_DIR/sumika-shell */
		static char fallback[4000];
		const char *xr = getenv("XDG_RUNTIME_DIR");
		if (xr && *xr)
			snprintf(fallback, sizeof fallback, "%s/sumika-shell", xr);
		else
			snprintf(fallback, sizeof fallback, "/tmp/sumika-shell");
		rt = fallback;
	}
	snprintf(sock_path, sizeof sock_path, "%s/labwc-workspace.sock", rt);

	/* runtime dir may not exist yet when launched early from autostart */
	{
		char *slash = strrchr(sock_path, '/');
		if (slash && slash != sock_path) {
			*slash = '\0';
			mkdir(sock_path, 0755);
			*slash = '/';
		}
	}

	/* Single-instance guard, same pattern as the overview thumbnaild. */
	static char lock_path[sizeof sock_path + 8];
	static int lock_fd = -1;
	snprintf(lock_path, sizeof lock_path, "%s.lock", sock_path);
	lock_fd = open(lock_path, O_CREAT | O_RDWR, 0600);
	if (lock_fd < 0) {
		perror("labwc-workspace: lock");
		return;
	}
	if (flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
		fprintf(stderr, "labwc-workspace: another instance holds %s, exiting\n",
			lock_path);
		close(lock_fd);
		lock_fd = -1;
		exit(0);
	}

	listen_fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (listen_fd < 0) {
		perror("labwc-workspace: socket");
		return;
	}

	struct sockaddr_un addr = { .sun_family = AF_UNIX };
	if (strlen(sock_path) >= sizeof addr.sun_path) {
		fprintf(stderr, "labwc-workspace: socket path too long\n");
		close(listen_fd);
		listen_fd = -1;
		return;
	}
	snprintf(addr.sun_path, sizeof addr.sun_path, "%s", sock_path);
	unlink(sock_path);
	if (bind(listen_fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
		perror("labwc-workspace: bind");
		close(listen_fd);
		listen_fd = -1;
		return;
	}
	if (listen(listen_fd, 4) < 0) {
		perror("labwc-workspace: listen");
		close(listen_fd);
		listen_fd = -1;
		return;
	}
	chmod(sock_path, 0600);
}

static void
close_client(int i)
{
	close(clients[i]);
	memmove(&clients[i], &clients[i + 1],
		(client_count - i - 1) * sizeof clients[0]);
	client_count--;
}

/* ---------------- main loop ---------------- */

static void
on_signal(int sig)
{
	(void)sig;
	quitting = true;
}

int
main(int argc, char **argv)
{
	(void)argc; (void)argv;

	display = wl_display_connect(NULL);
	if (!display) {
		fprintf(stderr, "labwc-workspace: cannot connect to Wayland\n");
		return 1;
	}

	struct wl_registry *reg = wl_display_get_registry(display);
	wl_registry_add_listener(reg, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_display_roundtrip(display);

	if (!ws_mgr) {
		fprintf(stderr, "labwc-workspace: ext_workspace_manager_v1 not "
			"advertised — not a labwc session, exiting\n");
		return 0; /* labwc-only: no-op elsewhere */
	}

	/* Initial workspace state was collected during the registry
	 * roundtrips (listener attached in the global handler). */

	setup_socket();
	fprintf(stderr, "labwc-workspace: listening on %s\n", sock_path);

	struct sigaction sa = { .sa_handler = on_signal };
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	signal(SIGPIPE, SIG_IGN); /* writes to dead clients must not kill us */

	int wl_fd = wl_display_get_fd(display);
	struct pollfd fds[2 + MAX_CLIENTS];

	while (!quitting) {
		int nfds = 0;
		fds[nfds++] = (struct pollfd){ wl_fd, POLLIN, 0 };
		if (listen_fd >= 0)
			fds[nfds++] = (struct pollfd){ listen_fd, POLLIN, 0 };
		for (int i = 0; i < client_count && nfds < (int)ARRAY_LEN(fds); i++)
			fds[nfds++] = (struct pollfd){ clients[i], POLLIN, 0 };

		int r = poll(fds, nfds, -1);
		if (r < 0) {
			if (errno == EINTR)
				continue;
			fprintf(stderr, "labwc-workspace: poll errno=%d\n", errno);
			break;
		}

		/* display events */
		if (fds[0].revents & (POLLIN | POLLHUP)) {
			if (wl_display_dispatch(display) < 0) {
				fprintf(stderr, "labwc-workspace: dispatch errno=%d\n", errno);
				if (errno != EAGAIN && errno != EINTR)
					break;
			}
		}

		/* new clients */
		if (listen_fd >= 0 && (fds[1].revents & POLLIN)) {
			int c = accept(listen_fd, NULL, NULL);
			if (c >= 0 && client_count < MAX_CLIENTS) {
				clients[client_count++] = c;
				write_state_to(c); /* immediate state on connect */
			} else if (c >= 0) {
				close(c);
			}
		}

		/* client input — at most one client per poll round, mirroring the
		 * thumbnaild reasoning: fds[] beyond nfds is stale stack memory and
		 * close_client() compacts the array under later revents checks. */
		for (int i = 0; i < client_count; i++) {
			int idx = 2 + i;
			if (idx >= nfds)
				break; /* accepted after poll; not polled this round */
			if (fds[idx].revents & (POLLIN | POLLHUP)) {
				char buf[64];
				ssize_t n = read(clients[i], buf, sizeof buf);
				if (n <= 0) { /* EOF or error: client gone */
					close_client(i);
				}
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
	fprintf(stderr, "labwc-workspace: exiting\n");
	return 0;
}
