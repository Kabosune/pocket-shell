/*
 * pocket-padtest: gamepad tester.
 *
 *   pocket-padtest              full-screen window: what apps see through SDL3
 *   pocket-padtest --raw        terminal table of the kernel's own axis values
 *   pocket-padtest --calibrate  measure how far the sticks really reach and
 *                               save that as their range (root)
 *   pocket-padtest --apply [NODE]  put the saved range on the device (root;
 *                               run by udev when the pad appears)
 *   pocket-padtest --reset      back to the driver's own range (root)
 *   pocket-padtest --set AXIS MIN MAX ...  save hand-picked ranges (root)
 *   pocket-padtest --stream     stick values of the hidden pad, for the
 *                               window's Calibrate screen (root)
 *
 * The window shows each stick's reach in every direction (the outline grows
 * as you roll the stick around the edge), the triggers, every button, the
 * pad's raw SDL joystick axes and, when readable, the kernel (evdev) values
 * of every gamepad device, including the built-in pad that InputPlumber
 * hides behind its virtual Xbox 360 pad. Comparing the two shows where the
 * outer part of the stick range gets lost.
 *
 * Moonlight and most other games read pads through SDL (SDL2 apps through
 * sdl2-compat, which runs on SDL3), so the window shows what they get.
 *
 * Why calibrate: a driver may advertise a wider range than its sticks can
 * reach (the RP5's says +-1408, its sticks stop around +-1200), and
 * InputPlumber scales by that range, so games never see a full push.
 * The saved range lives in /etc/pocket-shell/stick-range; InputPlumber reads
 * a device's range when it opens it, so restart it after a change
 * (pocket-sticks does all of this).
 *
 * Window controls: hold Start + Select to quit, Select + X to reset,
 * Select + Y (or the Calibrate button) for the Calibrate screen, where each
 * stick's centre and range can be tuned by hand. Esc quits, R resets.
 */

#include <SDL3/SDL.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define BINS      72
#define MAX_PADS   8
#define MAX_RAW    4
#define MAX_AXES  24
#define LBITS     (8 * (int)sizeof(unsigned long))

/* ---------- kernel (evdev) side ---------- */

typedef struct {
    int code;
    struct input_absinfo info;
    int lo, hi;
    bool seen;
} RawAxis;

typedef struct {
    char node[160];
    char name[128];
    dev_t rdev;
    int fd, err, nax;
    bool virt;                       /* made by software (uinput), e.g. InputPlumber */
    RawAxis ax[MAX_AXES];
} RawDev;

static RawDev raw[MAX_RAW];
static int nraw;

static const char *abs_name(int code)
{
    static char buf[16];
    static const char *names[] = {
        [ABS_X] = "X", [ABS_Y] = "Y", [ABS_Z] = "Z",
        [ABS_RX] = "RX", [ABS_RY] = "RY", [ABS_RZ] = "RZ",
        [ABS_THROTTLE] = "THROTTLE", [ABS_RUDDER] = "RUDDER",
        [ABS_WHEEL] = "WHEEL", [ABS_GAS] = "GAS", [ABS_BRAKE] = "BRAKE",
        [ABS_HAT0X] = "HAT0X", [ABS_HAT0Y] = "HAT0Y",
        [ABS_HAT1X] = "HAT1X", [ABS_HAT1Y] = "HAT1Y",
        [ABS_HAT2X] = "HAT2X", [ABS_HAT2Y] = "HAT2Y",
    };
    if (code >= 0 && code < (int)(sizeof names / sizeof *names) && names[code])
        return names[code];
    snprintf(buf, sizeof buf, "0x%02x", code);
    return buf;
}

static bool is_stick(int code)
{
    return code == ABS_X || code == ABS_Y || code == ABS_RX || code == ABS_RY;
}

/* Reads a capability bitmap from sysfs (works without access to the node) */
static int sys_bits(dev_t rdev, const char *cap, unsigned long *bits, int nwords)
{
    char path[128], line[1024];
    snprintf(path, sizeof path, "/sys/dev/char/%u:%u/device/capabilities/%s",
             major(rdev), minor(rdev), cap);
    memset(bits, 0, nwords * sizeof *bits);
    FILE *f = fopen(path, "r");
    if (!f)
        return -1;
    bool ok = fgets(line, sizeof line, f) != NULL;
    fclose(f);
    if (!ok)
        return -1;
    char *tok[64];
    int n = 0;
    for (char *t = strtok(line, " \n"); t && n < 64; t = strtok(NULL, " \n"))
        tok[n++] = t;
    for (int i = 0; i < n && i < nwords; i++)
        bits[i] = strtoul(tok[n - 1 - i], NULL, 16);
    return 0;
}

static bool bit(const unsigned long *bits, int n)
{
    return (bits[n / LBITS] >> (n % LBITS)) & 1;
}

static void sys_name(dev_t rdev, char *out, size_t len)
{
    char path[128];
    snprintf(path, sizeof path, "/sys/dev/char/%u:%u/device/name", major(rdev), minor(rdev));
    snprintf(out, len, "?");
    FILE *f = fopen(path, "r");
    if (!f)
        return;
    if (fgets(out, (int)len, f))
        out[strcspn(out, "\n")] = 0;
    fclose(f);
}

static bool sys_virtual(dev_t rdev)
{
    char path[128], real[PATH_MAX];
    snprintf(path, sizeof path, "/sys/dev/char/%u:%u", major(rdev), minor(rdev));
    return realpath(path, real) && strstr(real, "/virtual/");
}

static void raw_close(void)
{
    for (int i = 0; i < nraw; i++)
        if (raw[i].fd >= 0)
            close(raw[i].fd);
    nraw = 0;
}

static void raw_add(const char *node)
{
    struct stat sb;
    if (nraw >= MAX_RAW || stat(node, &sb) != 0 || !S_ISCHR(sb.st_mode))
        return;
    for (int i = 0; i < nraw; i++)
        if (raw[i].rdev == sb.st_rdev)
            return;

    unsigned long absb[2], keyb[KEY_CNT / LBITS + 1];
    if (sys_bits(sb.st_rdev, "abs", absb, 2) || sys_bits(sb.st_rdev, "key", keyb, KEY_CNT / LBITS + 1))
        return;
    /* Gamepads only: sticks and pad buttons, no touchscreens */
    if (!bit(absb, ABS_X) || bit(absb, ABS_MT_POSITION_X))
        return;
    if (!bit(keyb, BTN_SOUTH) && !bit(keyb, BTN_TRIGGER))
        return;

    RawDev *d = &raw[nraw++];
    memset(d, 0, sizeof *d);
    snprintf(d->node, sizeof d->node, "%s", node);
    d->rdev = sb.st_rdev;
    sys_name(sb.st_rdev, d->name, sizeof d->name);
    d->virt = sys_virtual(sb.st_rdev);
    d->fd = open(node, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    d->err = d->fd < 0 ? errno : 0;
    for (int code = 0; code < ABS_MT_SLOT && d->nax < MAX_AXES; code++) {
        if (!bit(absb, code))
            continue;
        RawAxis *a = &d->ax[d->nax++];
        a->code = code;
        if (d->fd >= 0)
            ioctl(d->fd, EVIOCGABS(code), &a->info);
    }
}

static void raw_scan(void)
{
    static const char *dirs[] = { "/dev/input", "/dev/inputplumber/sources" };
    raw_close();
    for (size_t i = 0; i < sizeof dirs / sizeof *dirs; i++) {
        DIR *dir = opendir(dirs[i]);
        if (!dir)
            continue;
        struct dirent *e;
        char names[64][64];
        int n = 0;
        while ((e = readdir(dir)) && n < 64) {
            if (e->d_name[0] == '.')
                continue;
            if (i == 0 && strncmp(e->d_name, "event", 5))
                continue;
            snprintf(names[n++], sizeof names[0], "%.63s", e->d_name);
        }
        closedir(dir);
        /* event2 before event10 */
        for (int a = 0; a < n; a++)
            for (int b = a + 1; b < n; b++)
                if (strlen(names[b]) < strlen(names[a]) ||
                    (strlen(names[b]) == strlen(names[a]) && strcmp(names[b], names[a]) < 0)) {
                    char t[64];
                    memcpy(t, names[a], 64);
                    memcpy(names[a], names[b], 64);
                    memcpy(names[b], t, 64);
                }
        for (int k = 0; k < n; k++) {
            char path[160];
            snprintf(path, sizeof path, "%.40s/%.63s", dirs[i], names[k]);
            raw_add(path);
        }
    }
}

/* The kernel keeps each axis' latest value even while InputPlumber grabs the
 * device, so polling EVIOCGABS works where reading events wouldn't. */
static void raw_poll(void)
{
    for (int i = 0; i < nraw; i++) {
        RawDev *d = &raw[i];
        if (d->fd < 0)
            continue;
        for (int k = 0; k < d->nax; k++) {
            RawAxis *a = &d->ax[k];
            if (ioctl(d->fd, EVIOCGABS(a->code), &a->info) < 0)
                continue;
            int v = a->info.value;
            if (!a->seen) {
                a->lo = a->hi = v;
                a->seen = true;
            }
            if (v < a->lo) a->lo = v;
            if (v > a->hi) a->hi = v;
        }
    }
}

static void raw_reset(void)
{
    for (int i = 0; i < nraw; i++)
        for (int k = 0; k < raw[i].nax; k++)
            raw[i].ax[k].seen = false;
}

/* Reach toward each end, in percent of the advertised range */
static void raw_reach(const RawAxis *a, double *neg, double *pos)
{
    double mn = a->info.minimum, mx = a->info.maximum;
    *neg = *pos = -1;
    if (!a->seen || mx <= mn)
        return;
    if (is_stick(a->code)) {
        double c = (mn + mx) / 2;
        *neg = 100 * (c - a->lo) / (c - mn);
        *pos = 100 * (a->hi - c) / (mx - c);
    } else {
        *pos = 100 * (a->hi - mn) / (mx - mn);
    }
}

static void raw_line(const RawAxis *a, char *out, size_t len)
{
    double neg, pos;
    raw_reach(a, &neg, &pos);
    char reach[32] = "";
    if (neg >= 0)
        snprintf(reach, sizeof reach, "%3.0f%% / %3.0f%%", neg, pos);
    else if (pos >= 0)
        snprintf(reach, sizeof reach, "%3.0f%%", pos);
    snprintf(out, len, "%-6s now %6d  seen %6d..%-6d of %6d..%-6d flat %d fuzz %d  %s",
             abs_name(a->code), a->info.value, a->seen ? a->lo : 0, a->seen ? a->hi : 0,
             a->info.minimum, a->info.maximum, a->info.flat, a->info.fuzz, reach);
}

/* ---------- terminal mode ---------- */

static volatile sig_atomic_t stop;
static void on_signal(int sig) { (void)sig; stop = 1; }

static int raw_main(void)
{
    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    raw_scan();
    if (nraw == 0) {
        printf("No gamepad devices found under /dev/input.\n");
        return 1;
    }
    struct timespec tick = { 0, 4 * 1000 * 1000 };
    int frame = 0;
    char line[256];
    while (!stop) {
        raw_poll();
        if (frame++ % 25 == 0) {
            printf("\033[H\033[J");
            printf("pocket-padtest --raw: kernel axis values. Roll each stick around its edge, press the triggers.\n");
            printf("Reach = how far toward each end of the advertised range the axis has gone. Ctrl+C ends.\n\n");
            for (int i = 0; i < nraw; i++) {
                printf("%s  (%s)\n", raw[i].name, raw[i].node);
                if (raw[i].fd < 0) {
                    printf("  can't read: %s%s\n\n", strerror(raw[i].err),
                           raw[i].err == EACCES ? " (run with sudo)" : "");
                    continue;
                }
                for (int k = 0; k < raw[i].nax; k++) {
                    raw_line(&raw[i].ax[k], line, sizeof line);
                    printf("  %s\n", line);
                }
                printf("\n");
            }
            fflush(stdout);
        }
        nanosleep(&tick, NULL);
    }
    printf("\nSeen ranges:\n");
    for (int i = 0; i < nraw; i++) {
        if (raw[i].fd < 0)
            continue;
        printf("%s  (%s)\n", raw[i].name, raw[i].node);
        for (int k = 0; k < raw[i].nax; k++) {
            raw_line(&raw[i].ax[k], line, sizeof line);
            printf("  %s\n", line);
        }
    }
    raw_close();
    return 0;
}

/* ---------- stick range calibration ---------- */

#define RANGE_DIR   "/etc/pocket-shell"
#define RANGE_FILE  RANGE_DIR "/stick-range"
#define MARGIN      0.98             /* a little inside the measured edge */

typedef struct {
    int code, min, max, omin, omax;  /* saved range, driver's own range */
} Range;

typedef struct {
    char name[128];
    int n;
    Range r[4];
} RangeFile;

static const int stick_codes[] = { ABS_X, ABS_Y, ABS_RX, ABS_RY };

static int stick_code(const char *name)
{
    for (int i = 0; i < 4; i++)
        if (!strcmp(abs_name(stick_codes[i]), name))
            return stick_codes[i];
    return -1;
}

static int iround(double v) { return (int)(v + (v >= 0 ? 0.5 : -0.5)); }

static bool range_load(RangeFile *f)
{
    memset(f, 0, sizeof *f);
    FILE *fp = fopen(RANGE_FILE, "r");
    if (!fp)
        return false;
    char line[256];
    while (fgets(line, sizeof line, fp)) {
        line[strcspn(line, "\n")] = 0;
        if (!strncmp(line, "name ", 5)) {
            snprintf(f->name, sizeof f->name, "%.127s", line + 5);
            continue;
        }
        char ax[16];
        Range r;
        if (f->n < 4 && sscanf(line, "%15s %d %d %d %d", ax, &r.min, &r.max, &r.omin, &r.omax) == 5 &&
            (r.code = stick_code(ax)) >= 0 && r.max > r.min)
            f->r[f->n++] = r;
    }
    fclose(fp);
    return f->name[0] && f->n;
}

static bool range_save(const RangeFile *f)
{
    mkdir(RANGE_DIR, 0755);
    FILE *fp = fopen(RANGE_FILE ".new", "w");
    if (!fp)
        return false;
    fprintf(fp, "# Stick ranges measured by pocket-padtest --calibrate\n"
                "# axis  min  max  driver-min  driver-max\n"
                "name %s\n", f->name);
    for (int i = 0; i < f->n; i++)
        fprintf(fp, "%s %d %d %d %d\n", abs_name(f->r[i].code), f->r[i].min, f->r[i].max,
                f->r[i].omin, f->r[i].omax);
    bool ok = fclose(fp) == 0;
    return ok && rename(RANGE_FILE ".new", RANGE_FILE) == 0;
}

static int set_range(const char *node, int code, int min, int max)
{
    int fd = open(node, O_RDWR | O_CLOEXEC);
    if (fd < 0)
        return errno;
    struct input_absinfo info;
    int err = 0;
    if (ioctl(fd, EVIOCGABS(code), &info) < 0)
        err = errno;
    else {
        info.minimum = min;
        info.maximum = max;
        if (ioctl(fd, EVIOCSABS(code), &info) < 0)
            err = errno;
    }
    close(fd);
    return err;
}

/* Sets the saved (or, with driver set, the driver's) ranges on every real
 * device named in the file, or only on ONLY. Returns how many it changed. */
static int range_apply(const RangeFile *f, const char *only, bool driver, bool verbose)
{
    char nodes[32][64];
    int n = 0;
    if (only)
        snprintf(nodes[n++], sizeof nodes[0], "%.63s", only);
    else {
        DIR *dir = opendir("/dev/input");
        struct dirent *e;
        while (dir && (e = readdir(dir)) && n < 32)
            if (!strncmp(e->d_name, "event", 5))
                snprintf(nodes[n++], sizeof nodes[0], "/dev/input/%.40s", e->d_name);
        if (dir)
            closedir(dir);
    }
    int done = 0;
    for (int i = 0; i < n; i++) {
        struct stat sb;
        char name[128];
        if (stat(nodes[i], &sb) || !S_ISCHR(sb.st_mode))
            continue;
        sys_name(sb.st_rdev, name, sizeof name);
        if (strcmp(name, f->name) || sys_virtual(sb.st_rdev))
            continue;
        for (int k = 0; k < f->n; k++) {
            const Range *r = &f->r[k];
            int mn = driver ? r->omin : r->min, mx = driver ? r->omax : r->max;
            int err = set_range(nodes[i], r->code, mn, mx);
            if (verbose)
                printf("  %-3s %6d..%-6d %s\n", abs_name(r->code), mn, mx, err ? strerror(err) : "");
            if (!err)
                done++;
        }
    }
    return done;
}

static int need_root(void)
{
    if (geteuid() == 0)
        return 0;
    fprintf(stderr, "This changes the pad's settings in the kernel: run it with sudo\n"
                    "(or use pocket-sticks, which also restarts InputPlumber).\n");
    return 1;
}

static long now_ms(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1000L + t.tv_nsec / 1000000;
}

/* The built-in pad: the first readable gamepad that isn't a virtual one */
static RawDev *source_pad(void)
{
    raw_scan();
    for (int i = 0; i < nraw; i++)
        if (raw[i].fd >= 0 && !raw[i].virt)
            return &raw[i];
    return NULL;
}

/* The pad's sticks with their ranges now (min/max) and the driver's own
 * (omin/omax, kept from an earlier calibration if there is one) */
static int pad_ranges(RawDev *d, RangeFile *f, RawAxis *axes[4])
{
    RangeFile saved;
    bool have = range_load(&saved) && !strcmp(saved.name, d->name);
    memset(f, 0, sizeof *f);
    snprintf(f->name, sizeof f->name, "%s", d->name);
    for (int i = 0; i < 4; i++)
        for (int k = 0; k < d->nax; k++)
            if (d->ax[k].code == stick_codes[i]) {
                Range *r = &f->r[f->n];
                r->code = stick_codes[i];
                r->min = r->omin = d->ax[k].info.minimum;
                r->max = r->omax = d->ax[k].info.maximum;
                for (int j = 0; have && j < saved.n; j++)
                    if (saved.r[j].code == r->code) {
                        r->omin = saved.r[j].omin;
                        r->omax = saved.r[j].omax;
                    }
                if (axes)
                    axes[f->n] = &d->ax[k];
                f->n++;
            }
    return f->n;
}

/* Where a stick comes to rest after springing back: a stretch of 0.4 s in
 * which it stays within 2% of its range, after a push past half way. */
typedef struct {
    int ix, iy;
    bool pushed;
    long t0;
    int n, mnx, mxx, mny, mxy, rests;
    double sx, sy, cx, cy;
} Rest;

static void rest_feed(Rest *t, const Range *rx, const Range *ry, int x, int y, long now)
{
    double hx = (rx->omax - rx->omin) / 2.0, hy = (ry->omax - ry->omin) / 2.0;
    double dx = x - (rx->omin + rx->omax) / 2.0, dy = y - (ry->omin + ry->omax) / 2.0;
    if (dx < 0) dx = -dx;
    if (dy < 0) dy = -dy;
    double m = dx / hx > dy / hy ? dx / hx : dy / hy;
    if (m > 0.5) {
        t->pushed = true;
        t->n = 0;
        return;
    }
    if (!t->pushed || m > 0.3) {
        t->n = 0;
        return;
    }
    int tx = (int)(hx * 0.02) + 2, ty = (int)(hy * 0.02) + 2;
    if (t->n > 0) {
        int a = x < t->mnx ? x : t->mnx, b = x > t->mxx ? x : t->mxx;
        int c = y < t->mny ? y : t->mny, d = y > t->mxy ? y : t->mxy;
        if (b - a > tx || d - c > ty)
            t->n = 0;
        else {
            t->mnx = a; t->mxx = b; t->mny = c; t->mxy = d;
        }
    }
    if (t->n == 0) {
        t->t0 = now;
        t->sx = t->sy = 0;
        t->mnx = t->mxx = x;
        t->mny = t->mxy = y;
    }
    t->sx += x;
    t->sy += y;
    t->n++;
    if (now - t->t0 >= 400 && t->n >= 20) {
        t->cx += t->sx / t->n;
        t->cy += t->sy / t->n;
        t->rests++;
        t->pushed = false;
        t->n = 0;
    }
}

#define RESTS 3

static int calibrate_main(void)
{
    if (need_root())
        return 1;
    RawDev *d = source_pad();
    if (!d) {
        fprintf(stderr, "No built-in gamepad found (virtual pads like InputPlumber's are skipped).\n");
        return 1;
    }
    RangeFile f;
    RawAxis *axes[4] = { 0 };
    if (pad_ranges(d, &f, axes) == 0) {
        fprintf(stderr, "%s has no stick axes.\n", d->name);
        return 1;
    }

    /* Step 1 pairs X with Y and RX with RY */
    Rest rest[2];
    memset(rest, 0, sizeof rest);
    rest[0].ix = rest[0].iy = rest[1].ix = rest[1].iy = -1;
    for (int i = 0; i < f.n; i++) {
        int c = f.r[i].code;
        if (c == ABS_X) rest[0].ix = i;
        if (c == ABS_Y) rest[0].iy = i;
        if (c == ABS_RX) rest[1].ix = i;
        if (c == ABS_RY) rest[1].iy = i;
    }
    double centre[4];
    for (int i = 0; i < f.n; i++)
        centre[i] = (f.r[i].omin + f.r[i].omax) / 2.0;

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);
    struct pollfd in = { .fd = 0, .events = POLLIN };
    int step = 1;
    bool centred = false;
    static const char *stick_name[] = { "Left stick ", "Right stick" };
    for (int frame = 0; !stop && step < 3; frame++) {
        raw_poll();
        long now = now_ms();
        bool all = true;
        for (int s = 0; s < 2; s++) {
            Rest *t = &rest[s];
            if (t->ix < 0 || t->iy < 0)
                continue;
            if (step == 1 && t->rests < RESTS)
                rest_feed(t, &f.r[t->ix], &f.r[t->iy], axes[t->ix]->info.value, axes[t->iy]->info.value, now);
            if (t->rests < RESTS)
                all = false;
        }
        if (step == 1 && all) {
            for (int s = 0; s < 2; s++)
                if (rest[s].ix >= 0 && rest[s].iy >= 0 && rest[s].rests) {
                    centre[rest[s].ix] = rest[s].cx / rest[s].rests;
                    centre[rest[s].iy] = rest[s].cy / rest[s].rests;
                }
            centred = true;
            step = 2;
            frame = 0;
        }
        if (frame % 25 == 0) {
            printf("\033[H\033[J");
            printf("Calibrating %s (%s)\n\n", d->name, d->node);
            if (step == 1) {
                printf("Step 1 of 2: centre\n\n"
                       "Push each stick toward the edge and let it spring back by itself,\n"
                       "%d times per stick. Enter skips this step (keeps the driver's centre).\n"
                       "Ctrl+C cancels.\n\n", RESTS);
                for (int s = 0; s < 2; s++) {
                    Rest *t = &rest[s];
                    if (t->ix < 0 || t->iy < 0)
                        continue;
                    printf("  %s  %d of %d", stick_name[s], t->rests < RESTS ? t->rests : RESTS, RESTS);
                    if (t->rests)
                        printf("   rests at %+5.0f, %+5.0f", t->cx / t->rests, t->cy / t->rests);
                    printf("\n");
                }
            } else {
                printf("Step 2 of 2: edges%s\n\n", centred ? "" : " (centre skipped)");
                printf("Roll both sticks slowly around their edges 3 or 4 times, pushing\n"
                       "firmly, then press Enter. Ctrl+C cancels.\n\n");
                for (int i = 0; i < f.n; i++) {
                    const RawAxis *a = axes[i];
                    double h = (f.r[i].omax - f.r[i].omin) / 2.0, c = centre[i];
                    printf("  %-3s centre %+5.0f   seen %6d..%-6d  %3.0f%% / %3.0f%% of the driver's range\n",
                           abs_name(a->code), c, a->seen ? a->lo : 0, a->seen ? a->hi : 0,
                           a->seen ? 100 * (c - a->lo) / h : 0, a->seen ? 100 * (a->hi - c) / h : 0);
                }
            }
            fflush(stdout);
        }
        if (poll(&in, 1, 4) > 0) {
            char line[64];
            if (!fgets(line, sizeof line, stdin))
                break;
            if (step == 1) {
                step = 2;
                frame = -1;
                raw_reset();
            } else {
                step = 3;
            }
        }
    }
    if (step < 3) {
        printf("\nCancelled, nothing changed.\n");
        return 1;
    }

    for (int i = 0; i < f.n; i++) {
        Range *r = &f.r[i];
        const RawAxis *a = axes[i];
        double c = centre[i], h = (r->omax - r->omin) / 2.0;
        double neg = c - a->lo, pos = a->hi - c;
        if (!a->seen || neg < 0.5 * h || pos < 0.5 * h) {
            printf("\n%s didn't reach far enough both ways (%d..%d). Nothing saved; try again\n"
                   "and push each stick all the way around.\n", abs_name(r->code), a->lo, a->hi);
            return 1;
        }
        /* Same distance both ways from the centre, a touch inside the edge */
        double reach = (neg < pos ? neg : pos) * MARGIN;
        r->min = iround(c - reach);
        r->max = iround(c + reach);
    }
    if (!range_save(&f)) {
        fprintf(stderr, "Can't write %s: %s\n", RANGE_FILE, strerror(errno));
        return 1;
    }
    printf("\nSaved to %s:\n", RANGE_FILE);
    range_apply(&f, d->node, false, true);
    return 0;
}

/* For Gamepad Tester's Calibrate screen, which can't open the hidden pad
 * itself: prints the pad's name, its stick ranges (again whenever they
 * change) and the stick values, until whoever reads it goes away.
 *
 *   dev NAME
 *   axis X MIN MAX DRIVER-MIN DRIVER-MAX
 *   v X n Y n RX n RY n
 */
static int stream_main(void)
{
    if (geteuid() != 0) {
        printf("error needs root\n");
        return 1;
    }
    signal(SIGPIPE, SIG_DFL);
    RawDev *d = source_pad();
    if (!d) {
        printf("error no built-in gamepad found\n");
        return 1;
    }
    printf("dev %s\n", d->name);
    int shown[4][2];
    memset(shown, 0, sizeof shown);
    struct timespec tick = { 0, 8 * 1000 * 1000 };
    RangeFile f;
    RawAxis *axes[4] = { 0 };
    long start = now_ms();
    for (int iter = 0; now_ms() - start < 30L * 60 * 1000; iter++) {
        raw_poll();
        if (iter % 60 == 0)
            pad_ranges(d, &f, axes);
        for (int i = 0; i < f.n; i++) {
            int mn = axes[i]->info.minimum, mx = axes[i]->info.maximum;
            if (shown[i][0] != mn || shown[i][1] != mx) {
                printf("axis %s %d %d %d %d\n", abs_name(f.r[i].code), mn, mx, f.r[i].omin, f.r[i].omax);
                shown[i][0] = mn;
                shown[i][1] = mx;
            }
        }
        printf("v");
        for (int i = 0; i < f.n; i++)
            printf(" %s %d", abs_name(f.r[i].code), axes[i]->info.value);
        printf("\n");
        if (fflush(stdout) == EOF)
            break;
        nanosleep(&tick, NULL);
    }
    return 0;
}

/* --set AXIS MIN MAX [AXIS MIN MAX ...]: save and apply hand-picked ranges */
static int set_main(int argc, char **argv)
{
    if (need_root())
        return 1;
    if (argc == 0 || argc % 3) {
        fprintf(stderr, "Usage: pocket-padtest --set AXIS MIN MAX [AXIS MIN MAX ...]  (AXIS: X Y RX RY)\n");
        return 2;
    }
    RawDev *d = source_pad();
    if (!d) {
        fprintf(stderr, "No built-in gamepad found.\n");
        return 1;
    }
    RangeFile f;
    if (pad_ranges(d, &f, NULL) == 0) {
        fprintf(stderr, "%s has no stick axes.\n", d->name);
        return 1;
    }
    for (int a = 0; a < argc; a += 3) {
        int code = stick_code(argv[a]);
        char *e1, *e2;
        long mn = strtol(argv[a + 1], &e1, 10), mx = strtol(argv[a + 2], &e2, 10);
        Range *r = NULL;
        for (int i = 0; i < f.n; i++)
            if (f.r[i].code == code)
                r = &f.r[i];
        if (!r || *e1 || *e2) {
            fprintf(stderr, "Not a stick axis and two whole numbers: %s %s %s\n",
                    argv[a], argv[a + 1], argv[a + 2]);
            return 2;
        }
        long h = (r->omax - r->omin) / 2;
        if (mx - mn < h / 5 || mn < r->omin - h || mx > r->omax + h) {
            fprintf(stderr, "%s %ld..%ld is too far from the driver's %d..%d\n",
                    argv[a], mn, mx, r->omin, r->omax);
            return 2;
        }
        r->min = (int)mn;
        r->max = (int)mx;
    }
    if (!range_save(&f)) {
        fprintf(stderr, "Can't write %s: %s\n", RANGE_FILE, strerror(errno));
        return 1;
    }
    printf("Saved to %s:\n", RANGE_FILE);
    range_apply(&f, d->node, false, true);
    return 0;
}

static int apply_main(const char *node)
{
    if (need_root())
        return 1;
    RangeFile f;
    if (!range_load(&f))
        return 0;                    /* nothing saved: leave the driver's range */
    range_apply(&f, node, false, !node);
    return 0;
}

static int reset_main(void)
{
    if (need_root())
        return 1;
    RangeFile f;
    if (!range_load(&f)) {
        printf("No saved stick range; the driver's own range is in use.\n");
        return 0;
    }
    printf("Back to the driver's range:\n");
    range_apply(&f, NULL, true, true);
    if (unlink(RANGE_FILE))
        fprintf(stderr, "Can't remove %s: %s\n", RANGE_FILE, strerror(errno));
    return 0;
}

/* ---------- SDL side ---------- */

typedef struct {
    float reach[BINS];
    int lox, hix, loy, hiy;
    bool any;
} Stick;

static SDL_Renderer *R;
static float U;                       /* 1 unit = 1/540 of the screen height */
static SDL_Gamepad *pads[MAX_PADS];
static int active = -1;
static Stick sticks[2];
static int trig_max[2];
static bool btn_seen[SDL_GAMEPAD_BUTTON_COUNT];

static const SDL_Color C_BG = { 16, 17, 20, 255 }, C_PANEL = { 27, 29, 34, 255 },
    C_GRID = { 44, 47, 54, 255 }, C_RING = { 96, 102, 116, 255 }, C_ACC = { 110, 231, 183, 255 },
    C_WARN = { 245, 165, 36, 255 }, C_TEXT = { 230, 230, 230, 255 }, C_DIM = { 138, 143, 152, 255 },
    C_HOT = { 255, 255, 255, 255 }, C_FILL = { 46, 128, 98, 255 };

static void color(SDL_Color c) { SDL_SetRenderDrawColor(R, c.r, c.g, c.b, c.a); }

static void text(float x, float y, float size, SDL_Color c, const char *fmt, ...)
{
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    float s = size * U;
    SDL_SetRenderScale(R, s, s);
    color(c);
    SDL_RenderDebugText(R, x / s, y / s, buf);
    SDL_SetRenderScale(R, 1, 1);
}

static void fill(float x, float y, float w, float h, SDL_Color c)
{
    SDL_FRect r = { x, y, w, h };
    color(c);
    SDL_RenderFillRect(R, &r);
}

static void frame_rect(float x, float y, float w, float h, SDL_Color c)
{
    SDL_FRect r = { x, y, w, h };
    color(c);
    SDL_RenderRect(R, &r);
}

static void circle(float cx, float cy, float r, SDL_Color c)
{
    SDL_FPoint p[97];
    for (int i = 0; i <= 96; i++) {
        float t = (float)i / 96 * 2 * SDL_PI_F;
        p[i] = (SDL_FPoint){ cx + r * SDL_cosf(t), cy + r * SDL_sinf(t) };
    }
    color(c);
    SDL_RenderLines(R, p, 97);
}

static float norm(Sint16 v) { return v >= 0 ? v / 32767.0f : v / 32768.0f; }

static const char *dir_name(int bin)
{
    static const char *names[] = { "right", "down-right", "down", "down-left",
                                   "left", "up-left", "up", "up-right" };
    float deg = (bin + 0.5f) * 360.0f / BINS;      /* 0 = right, 90 = down */
    return names[(int)SDL_floorf((deg + 22.5f) / 45.0f) % 8];
}

static void stick_track(Stick *s, Sint16 x, Sint16 y)
{
    if (!s->any) {
        s->lox = s->hix = x;
        s->loy = s->hiy = y;
        s->any = true;
    }
    if (x < s->lox) s->lox = x;
    if (x > s->hix) s->hix = x;
    if (y < s->loy) s->loy = y;
    if (y > s->hiy) s->hiy = y;
    float nx = norm(x), ny = norm(y), m = SDL_sqrtf(nx * nx + ny * ny);
    if (m < 0.3f)
        return;
    float a = SDL_atan2f(ny, nx);
    if (a < 0)
        a += 2 * SDL_PI_F;
    int b = (int)(a / (2 * SDL_PI_F) * BINS) % BINS;
    if (m > s->reach[b])
        s->reach[b] = m;
}

typedef struct {
    int swept, full, weakest;
    float avg, low;
} Reach;

static Reach stick_reach(const Stick *s)
{
    Reach r = { 0, 0, -1, 0, 2 };
    for (int b = 0; b < BINS; b++) {
        float v = s->reach[b];
        if (v < 0.3f)
            continue;
        float c = v > 1 ? 1 : v;
        r.swept++;
        r.avg += c;
        if (c >= 0.99f)
            r.full++;
        if (c < r.low) {
            r.low = c;
            r.weakest = b;
        }
    }
    if (r.swept)
        r.avg /= r.swept;
    return r;
}

static void reset_all(void)
{
    memset(sticks, 0, sizeof sticks);
    memset(trig_max, 0, sizeof trig_max);
    memset(btn_seen, 0, sizeof btn_seen);
    raw_reset();
}

static void open_pads(void)
{
    for (int i = 0; i < MAX_PADS; i++)
        if (pads[i]) {
            SDL_CloseGamepad(pads[i]);
            pads[i] = NULL;
        }
    int n = 0;
    SDL_JoystickID *ids = SDL_GetGamepads(&n);
    for (int i = 0; i < n && i < MAX_PADS; i++)
        pads[i] = SDL_OpenGamepad(ids[i]);
    SDL_free(ids);
    active = -1;
    for (int i = 0; i < MAX_PADS; i++)
        if (pads[i]) {
            active = i;
            break;
        }
    raw_scan();
}

static void make_active(SDL_JoystickID id)
{
    for (int i = 0; i < MAX_PADS; i++)
        if (pads[i] && SDL_GetGamepadID(pads[i]) == id && active != i) {
            active = i;
            reset_all();
        }
}

static void draw_stick(float x, float y, float size, float tx, const char *label, Sint16 sx, Sint16 sy,
                       const Stick *s)
{
    float cx = x + size / 2, cy = y + size / 2, r = size * 0.42f;
    fill(x, y, size, size, C_PANEL);
    frame_rect(cx - r, cy - r, 2 * r, 2 * r, C_GRID);           /* full-range square */
    color(C_GRID);
    SDL_RenderLine(R, cx - r, cy, cx + r, cy);
    SDL_RenderLine(R, cx, cy - r, cx, cy + r);
    for (int i = 1; i <= 3; i++)
        circle(cx, cy, r * i / 4, C_GRID);
    circle(cx, cy, r, C_RING);                                    /* 100 % */

    /* Reach outline: amber where a direction never got to the edge */
    for (int b = 0; b < BINS; b++) {
        int nb = (b + 1) % BINS;
        float v0 = s->reach[b], v1 = s->reach[nb];
        if (v0 < 0.3f || v1 < 0.3f)
            continue;
        float a0 = (b + 0.5f) * 2 * SDL_PI_F / BINS, a1 = (nb + 0.5f) * 2 * SDL_PI_F / BINS;
        if (v0 > 1.18f) v0 = 1.18f;                         /* stay in the panel */
        if (v1 > 1.18f) v1 = 1.18f;
        color(v0 >= 0.99f && v1 >= 0.99f ? C_ACC : C_WARN);
        for (int t = -1; t <= 1; t++)
            SDL_RenderLine(R, cx + (r * v0 + t) * SDL_cosf(a0), cy + (r * v0 + t) * SDL_sinf(a0),
                              cx + (r * v1 + t) * SDL_cosf(a1), cy + (r * v1 + t) * SDL_sinf(a1));
    }

    float px = cx + norm(sx) * r, py = cy + norm(sy) * r;
    color(C_HOT);
    SDL_RenderLine(R, cx, cy, px, py);
    fill(px - 4 * U, py - 4 * U, 8 * U, 8 * U, C_HOT);
    text(x + 6 * U, y + 6 * U, 1, C_DIM, "%s", label);

    float nx = norm(sx), ny = norm(sy), m = SDL_sqrtf(nx * nx + ny * ny);
    Reach re = stick_reach(s);
    float ty = y + size + 8 * U, lh = 11 * U;
    x = tx;
    text(x, ty, 1.25f, C_TEXT, "X %+6d  Y %+6d  %3.0f%%", sx, sy, m * 100);
    ty += lh * 1.3f;
    if (re.swept < BINS / 2) {
        text(x, ty, 1, C_DIM, "Roll it around the edge a few times");
        ty += lh;
        text(x, ty, 1, C_DIM, "(swept %d of %d directions)", re.swept, BINS);
        return;
    }
    text(x, ty, 1, re.avg >= 0.99f ? C_ACC : C_WARN, "Reach: avg %.0f%%, low %.0f%% (%s)",
         re.avg * 100, re.low * 100, re.weakest >= 0 ? dir_name(re.weakest) : "-");
    ty += lh;
    text(x, ty, 1, C_DIM, "Full edge (99%%+): %d of %d dirs", re.full, re.swept);
    ty += lh;
    text(x, ty, 1, C_DIM, "X %+6d..%+6d  Y %+6d..%+6d", s->lox, s->hix, s->loy, s->hiy);
}

static void draw_bar(float x, float y, float w, float h, const char *label, int v, int mx)
{
    fill(x, y, w, h, C_PANEL);
    fill(x, y, w * v / 32767.0f, h, C_FILL);
    color(C_HOT);
    float m = x + w * mx / 32767.0f;
    SDL_RenderLine(R, m, y, m, y + h);
    text(x + 4 * U, y + (h - 8 * U) / 2, 1, C_HOT, "%s %5d  max %3.0f%%",
         label, v, mx * 100 / 32767.0f);
}

static bool in_rect(float px, float py, const SDL_FRect *r)
{
    return px >= r->x && px <= r->x + r->w && py >= r->y && py <= r->y + r->h;
}

static void print_summary(void)
{
    static const char *names[] = { "Left stick", "Right stick" };
    for (int i = 0; i < 2; i++) {
        Reach re = stick_reach(&sticks[i]);
        if (re.swept)
            printf("%s: average reach %.0f%%, weakest %.0f%% (%s), full edge in %d of %d directions, "
                   "X %d..%d, Y %d..%d\n", names[i], re.avg * 100, re.low * 100,
                   re.weakest >= 0 ? dir_name(re.weakest) : "-", re.full, re.swept,
                   sticks[i].lox, sticks[i].hix, sticks[i].loy, sticks[i].hiy);
    }
    printf("Triggers: left max %.0f%%, right max %.0f%%\n",
           trig_max[0] * 100 / 32767.0f, trig_max[1] * 100 / 32767.0f);
    char line[256];
    for (int i = 0; i < nraw; i++) {
        if (raw[i].fd < 0)
            continue;
        printf("%s (%s)\n", raw[i].name, raw[i].node);
        for (int k = 0; k < raw[i].nax; k++)
            if (is_stick(raw[i].ax[k].code)) {
                raw_line(&raw[i].ax[k], line, sizeof line);
                printf("  %s\n", line);
            }
    }
}

/* Fake readings, for checking the layout without a pad (--shot FILE.bmp) */
static void demo_fill(void)
{
    for (int b = 0; b < BINS; b++) {
        float a = (b + 0.5f) * 2 * SDL_PI_F / BINS;
        sticks[0].reach[b] = 0.86f + 0.04f * SDL_cosf(4 * a);
        sticks[1].reach[b] = b < 60 ? 1.0f + 0.25f * SDL_fabsf(SDL_sinf(2 * a)) : 0;
    }
    sticks[0].any = sticks[1].any = true;
    sticks[0].lox = -28100; sticks[0].hix = 28400; sticks[0].loy = -27900; sticks[0].hiy = 28800;
    sticks[1].lox = -32768; sticks[1].hix = 32767; sticks[1].loy = -32768; sticks[1].hiy = 32767;
    trig_max[0] = 32767; trig_max[1] = 25000;
    btn_seen[SDL_GAMEPAD_BUTTON_SOUTH] = btn_seen[SDL_GAMEPAD_BUTTON_START] = true;
}

/* A, B, X or Y as printed on the pad (SDL's label), else by position */
static char face(SDL_Gamepad *pad, int b)
{
    if (b > SDL_GAMEPAD_BUTTON_NORTH)
        return 0;
    switch (SDL_GetGamepadButtonLabel(pad, b)) {
    case SDL_GAMEPAD_BUTTON_LABEL_A: case SDL_GAMEPAD_BUTTON_LABEL_CROSS:    return 'A';
    case SDL_GAMEPAD_BUTTON_LABEL_B: case SDL_GAMEPAD_BUTTON_LABEL_CIRCLE:   return 'B';
    case SDL_GAMEPAD_BUTTON_LABEL_X: case SDL_GAMEPAD_BUTTON_LABEL_SQUARE:   return 'X';
    case SDL_GAMEPAD_BUTTON_LABEL_Y: case SDL_GAMEPAD_BUTTON_LABEL_TRIANGLE: return 'Y';
    default: return "ABXY"[b];
    }
}

/* ---------- touch targets ---------- */

enum {
    H_NONE, H_QUIT, H_RESET, H_CAL, H_BACK, H_LEFT, H_RIGHT, H_HERE, H_DRIVER, H_UNDO, H_SAVE,
    H_ROW = 20, H_MINUS = 30, H_PLUS = 40,
};

typedef struct {
    SDL_FRect r;
    int id;
} Hit;

static Hit hits[48];
static int nhits;

static void hit_add(float x, float y, float w, float h, int id)
{
    if (nhits < (int)(sizeof hits / sizeof *hits))
        hits[nhits++] = (Hit){ { x, y, w, h }, id };
}

static int hit_at(float px, float py)
{
    for (int i = nhits - 1; i >= 0; i--)
        if (in_rect(px, py, &hits[i].r))
            return hits[i].id;
    return H_NONE;
}

/* A labelled box; filled when on */
static void button(float x, float y, float w, float h, const char *label, int id, bool on)
{
    if (on)
        fill(x, y, w, h, C_FILL);
    frame_rect(x, y, w, h, on ? C_ACC : C_RING);
    float tw = (float)strlen(label) * 8 * U;
    text(x + (w - tw) / 2, y + (h - 8 * U) / 2, 1, C_TEXT, "%s", label);
    hit_add(x, y, w, h, id);
}

/* ---------- Calibrate screen ---------- */

/* Stick axes in this order: X Y RX RY (left stick 0-1, right stick 2-3) */
typedef struct {
    int min, max, omin, omax;
    bool have;
} CalRange;

static struct {
    FILE *pipe;
    char buf[8192];
    int len;
    bool live;
    char status[200];
    char dev[128];
    CalRange cur[4], edit[4];
    int val[4], hist[4][64], hpos, hcount;
    int stick, row;
    pid_t saver;
} cal;

static bool cal_view;

static int cal_index(const char *name)
{
    int code = stick_code(name);
    for (int i = 0; i < 4; i++)
        if (stick_codes[i] == code)
            return i;
    return -1;
}

static void cal_set_status(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(cal.status, sizeof cal.status, fmt, ap);
    va_end(ap);
}

/* The hidden pad needs root, so a helper reads it (see --stream) */
static void cal_open(void)
{
    if (cal.pipe)
        return;
    cal.len = 0;
    cal.live = false;
    cal.pipe = popen("exec sudo -n /usr/local/bin/pocket-padtest --stream 2>&1", "r");
    if (!cal.pipe) {
        cal_set_status("Can't start the helper: %s", strerror(errno));
        return;
    }
    int fd = fileno(cal.pipe);
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
    cal_set_status("Reading the built-in pad...");
}

static void cal_close(void)
{
    if (cal.pipe)
        pclose(cal.pipe);
    cal.pipe = NULL;
    cal.live = false;
}

static void cal_line(char *line)
{
    if (!strncmp(line, "dev ", 4)) {
        snprintf(cal.dev, sizeof cal.dev, "%.127s", line + 4);
        cal.live = true;
        cal.status[0] = 0;
    } else if (!strncmp(line, "axis ", 5)) {
        char ax[16];
        CalRange r = { .have = true };
        int i;
        if (sscanf(line + 5, "%15s %d %d %d %d", ax, &r.min, &r.max, &r.omin, &r.omax) == 5 &&
            (i = cal_index(ax)) >= 0) {
            cal.cur[i] = r;
            if (!cal.edit[i].have)
                cal.edit[i] = r;
        }
    } else if (line[0] == 'v' && line[1] == ' ') {
        char *save = NULL, *tok = strtok_r(line + 2, " ", &save);
        while (tok) {
            char *v = strtok_r(NULL, " ", &save);
            int i = cal_index(tok);
            if (!v)
                break;
            if (i >= 0)
                cal.val[i] = atoi(v);
            tok = strtok_r(NULL, " ", &save);
        }
        for (int i = 0; i < 4; i++)
            cal.hist[i][cal.hpos] = cal.val[i];
        cal.hpos = (cal.hpos + 1) % 64;
        if (cal.hcount < 64)
            cal.hcount++;
    } else if (!strncmp(line, "error ", 6)) {
        cal_set_status("Helper: %s", line + 6);
    } else if (!strncmp(line, "sudo:", 5)) {
        cal_set_status("Needs the sudo rule install.sh adds (and your user in the wheel group). "
                       "Or tune over SSH: pocket-sticks set");
    }
}

static void cal_poll(void)
{
    if (!cal.pipe)
        return;
    for (;;) {
        size_t used = cal.len > 0 && cal.len < (int)sizeof cal.buf - 1 ? (size_t)cal.len : 0;
        cal.len = (int)used;
        ssize_t n = read(fileno(cal.pipe), &cal.buf[used], sizeof cal.buf - 1 - used);
        if (n == 0) {
            if (!cal.status[0])
                cal_set_status("The helper stopped. Reopen Calibrate to try again.");
            cal_close();
            return;
        }
        if (n < 0)
            break;
        cal.len += (int)n;
        cal.buf[cal.len] = 0;
        char *start = cal.buf, *nl;
        while ((nl = strchr(start, '\n'))) {
            *nl = 0;
            cal_line(start);
            start = nl + 1;
        }
        cal.len -= (int)(start - cal.buf);
        memmove(cal.buf, start, cal.len);
        if (cal.len >= (int)sizeof cal.buf - 1)
            cal.len = 0;
    }
}

static bool cal_dirty(void)
{
    for (int i = 0; i < 4; i++)
        if (cal.edit[i].have && (cal.edit[i].min != cal.cur[i].min || cal.edit[i].max != cal.cur[i].max))
            return true;
    return false;
}

/* Rows: 0 centre X, 1 centre Y, 2 range X, 3 range Y of the chosen stick */
static void cal_adjust(int row, int dir)
{
    CalRange *r = &cal.edit[cal.stick * 2 + (row & 1)];
    if (!r->have)
        return;
    int h = (r->omax - r->omin) / 2, oc = (r->omin + r->omax) / 2;
    int mn = r->min, mx = r->max;
    if (row < 2) {
        mn += 2 * dir;
        mx += 2 * dir;
    } else {
        mn -= 4 * dir;
        mx += 4 * dir;
    }
    int c = (mn + mx) / 2, half = (mx - mn) / 2;
    if (c < oc - h * 3 / 10 || c > oc + h * 3 / 10 || half < h * 3 / 10 || half > h * 6 / 5)
        return;
    r->min = mn;
    r->max = mx;
}

/* Centre the chosen stick where it rests now (last ~0.5 s, held still) */
static void cal_centre_here(void)
{
    if (cal.hcount < 32) {
        cal_set_status("Still reading the stick, try again in a moment.");
        return;
    }
    for (int a = 0; a < 2; a++) {
        int i = cal.stick * 2 + a;
        CalRange *r = &cal.edit[i];
        if (!r->have) {
            cal_set_status("No values for this stick yet.");
            return;
        }
        double sum = 0;
        int lo = INT_MAX, hi = INT_MIN;
        for (int k = 0; k < 48; k++) {
            int v = cal.hist[i][(cal.hpos + 63 - k) % 64];
            sum += v;
            if (v < lo) lo = v;
            if (v > hi) hi = v;
        }
        int h = (r->omax - r->omin) / 2, oc = (r->omin + r->omax) / 2, avg = iround(sum / 48);
        if (hi - lo > h / 25 || avg < oc - h * 3 / 10 || avg > oc + h * 3 / 10) {
            cal_set_status("Let go of the stick and keep it still, then try again.");
            return;
        }
    }
    for (int a = 0; a < 2; a++) {
        int i = cal.stick * 2 + a;
        double sum = 0;
        for (int k = 0; k < 48; k++)
            sum += cal.hist[i][(cal.hpos + 63 - k) % 64];
        CalRange *r = &cal.edit[i];
        int half = (r->max - r->min) / 2, c = iround(sum / 48);
        r->min = c - half;
        r->max = c + half;
    }
    cal_set_status("Centred on where the stick rests. Save to keep it.");
}

static void cal_driver(void)
{
    for (int a = 0; a < 2; a++) {
        CalRange *r = &cal.edit[cal.stick * 2 + a];
        if (r->have) {
            r->min = r->omin;
            r->max = r->omax;
        }
    }
    cal_set_status("The driver's own range. Save to keep it.");
}

static void cal_undo(void)
{
    for (int i = 0; i < 4; i++)
        if (cal.cur[i].have)
            cal.edit[i] = cal.cur[i];
    cal_set_status("Back to what the pad has now.");
}

static void cal_save(void)
{
    if (cal.saver || !cal_dirty())
        return;
    char nums[8][16];
    char *args[16];
    int n = 0, k = 0;
    args[n++] = "pocket-sticks";
    args[n++] = "set";
    for (int i = 0; i < 4; i++) {
        if (!cal.edit[i].have)
            continue;
        args[n++] = (char *)abs_name(stick_codes[i]);
        snprintf(nums[k], sizeof nums[k], "%d", cal.edit[i].min);
        args[n++] = nums[k++];
        snprintf(nums[k], sizeof nums[k], "%d", cal.edit[i].max);
        args[n++] = nums[k++];
    }
    args[n] = NULL;
    extern char **environ;
    int err = posix_spawnp(&cal.saver, "pocket-sticks", NULL, NULL, args, environ);
    if (err) {
        cal.saver = 0;
        cal_set_status("Can't run pocket-sticks: %s", strerror(err));
        return;
    }
    cal_set_status("Saving... InputPlumber restarts, so the pad pauses for a moment.");
}

static void cal_check_saver(void)
{
    int st;
    if (!cal.saver || waitpid(cal.saver, &st, WNOHANG) != cal.saver)
        return;
    cal.saver = 0;
    if (WIFEXITED(st) && WEXITSTATUS(st) == 0)
        cal_set_status("Saved. Games now use this range.");
    else
        cal_set_status("Couldn't save. Run pocket-sticks set over SSH to see why.");
}

static void cal_enter(void)
{
    cal_view = true;
    cal_open();
}

static void cal_leave(void)
{
    cal_view = false;
    cal_close();
}

static void cal_stick_panel(float x, float y, float size, int s, bool selected)
{
    const CalRange *rx = &cal.edit[s * 2], *ry = &cal.edit[s * 2 + 1];
    float cx = x + size / 2, cy = y + size / 2, r = size * 0.42f;
    fill(x, y, size, size, C_PANEL);
    if (selected)
        for (int t = 0; t < 2; t++)
            frame_rect(x - t, y - t, size + 2 * t, size + 2 * t, C_ACC);
    color(C_GRID);
    SDL_RenderLine(R, cx - r, cy, cx + r, cy);
    SDL_RenderLine(R, cx, cy - r, cx, cy + r);
    for (int i = 1; i <= 3; i++)
        circle(cx, cy, r * i / 4, C_GRID);
    circle(cx, cy, r, C_RING);
    text(x + 6 * U, y + 6 * U, 1, selected ? C_ACC : C_DIM, s ? "RIGHT STICK" : "LEFT STICK");
    hit_add(x, y, size, size, s ? H_RIGHT : H_LEFT);
    if (!rx->have || !ry->have) {
        text(x + 10 * U, cy - 4 * U, 1, C_DIM, cal.pipe ? "Waiting for values..." : "No values");
        return;
    }

    /* Position as games will see it with the edited range */
    float hx = (rx->max - rx->min) / 2.0f, hy = (ry->max - ry->min) / 2.0f;
    float nx = (cal.val[s * 2] - (rx->min + rx->max) / 2.0f) / hx;
    float ny = (cal.val[s * 2 + 1] - (ry->min + ry->max) / 2.0f) / hy;
    float px = nx, py = ny;
    if (px > 1.2f) px = 1.2f;
    if (px < -1.2f) px = -1.2f;
    if (py > 1.2f) py = 1.2f;
    if (py < -1.2f) py = -1.2f;
    float m = SDL_sqrtf(nx * nx + ny * ny);
    color(C_HOT);
    SDL_RenderLine(R, cx, cy, cx + px * r, cy + py * r);
    fill(cx + px * r - 4 * U, cy + py * r - 4 * U, 8 * U, 8 * U, m >= 0.99f ? C_ACC : C_HOT);

    /* Zoomed centre: the box spans +-10% of the range */
    float zs = 64 * U, zx = x + size - zs - 6 * U, zy = y + 6 * U, zc = zs / 2;
    fill(zx, zy, zs, zs, C_BG);
    frame_rect(zx, zy, zs, zs, C_GRID);
    color(C_GRID);
    SDL_RenderLine(R, zx + zc, zy, zx + zc, zy + zs);
    SDL_RenderLine(R, zx, zy + zc, zx + zs, zy + zc);
    float qx = nx / 0.1f, qy = ny / 0.1f;
    if (qx > 1) qx = 1;
    if (qx < -1) qx = -1;
    if (qy > 1) qy = 1;
    if (qy < -1) qy = -1;
    bool centred = nx * nx + ny * ny < 0.01f * 0.01f;
    fill(zx + zc + qx * (zc - 3 * U) - 3 * U, zy + zc + qy * (zc - 3 * U) - 3 * U, 6 * U, 6 * U,
         centred ? C_ACC : C_WARN);
    text(zx, zy + zs + 3 * U, 0.75f, C_DIM, "centre x10");

    float ty = y + size + 8 * U, lh = 11 * U;
    text(x, ty, 1.25f, C_TEXT, "%+6.1f%%  %+6.1f%%  %3.0f%%", nx * 100, ny * 100, m * 100);
    ty += lh * 1.3f;
    text(x, ty, 1, C_DIM, "raw %+5d, %+5d", cal.val[s * 2], cal.val[s * 2 + 1]);
    ty += lh;
    text(x, ty, 1, C_DIM, "centre %+d, %+d", (rx->min + rx->max) / 2, (ry->min + ry->max) / 2);
    ty += lh;
    text(x, ty, 1, C_DIM, "range +-%d, +-%d", (rx->max - rx->min) / 2, (ry->max - ry->min) / 2);
}

static void draw_cal(int W, int H, float top, float size, float m)
{
    (void)H;
    cal_stick_panel(m, top, size, 0, cal.stick == 0);
    cal_stick_panel(W - m - size, top, size, 1, cal.stick == 1);

    float mx = m + size + 18 * U, mw = W - 2 * (m + size + 18 * U), y = top;
    float half = (mw - 6 * U) / 2;
    button(mx, y, half, 22 * U, "Left stick", H_LEFT, cal.stick == 0);
    button(mx + half + 6 * U, y, half, 22 * U, "Right stick", H_RIGHT, cal.stick == 1);
    y += 32 * U;

    static const char *rows[] = { "Centre X", "Centre Y", "Range X", "Range Y" };
    float rh = 24 * U, bw = 34 * U;
    for (int row = 0; row < 4; row++) {
        const CalRange *r = &cal.edit[cal.stick * 2 + (row & 1)];
        const CalRange *c = &cal.cur[cal.stick * 2 + (row & 1)];
        bool sel = cal.row == row;
        if (sel)
            fill(mx, y, mw, rh, C_PANEL);
        hit_add(mx, y, mw - 2 * bw - 12 * U, rh, H_ROW + row);
        text(mx + 8 * U, y + 8 * U, 1, sel ? C_ACC : C_TEXT, "%s", rows[row]);
        if (r->have) {
            int v = row < 2 ? (r->min + r->max) / 2 : (r->max - r->min) / 2;
            int was = row < 2 ? (c->min + c->max) / 2 : (c->max - c->min) / 2;
            int drv = row < 2 ? (r->omin + r->omax) / 2 : (r->omax - r->omin) / 2;
            text(mx + 100 * U, y + 8 * U, 1, v != was ? C_WARN : C_TEXT, row < 2 ? "%+d" : "+-%d", v);
            text(mx + 170 * U, y + 8 * U, 0.85f, C_DIM, row < 2 ? "driver %+d" : "driver +-%d", drv);
        }
        button(mx + mw - 2 * bw - 6 * U, y + 2 * U, bw, rh - 4 * U, "-", H_MINUS + row, false);
        button(mx + mw - bw, y + 2 * U, bw, rh - 4 * U, "+", H_PLUS + row, false);
        y += rh + 4 * U;
    }
    y += 6 * U;
    float third = (mw - 12 * U) / 3;
    button(mx, y, third, 22 * U, "Centre here", H_HERE, false);
    button(mx + third + 6 * U, y, third, 22 * U, "Driver's", H_DRIVER, false);
    button(mx + 2 * (third + 6 * U), y, third, 22 * U, "Undo", H_UNDO, false);
    y += 30 * U;
    bool dirty = cal_dirty();
    button(mx, y, mw, 26 * U, cal.saver ? "Saving..." : dirty ? "Save" : "Saved", H_SAVE, dirty && !cal.saver);
    y += 36 * U;

    /* Status, wrapped to the column */
    int cols = (int)(mw / (8 * U));
    const char *st = cal.status[0] ? cal.status
                     : dirty ? "Not saved yet." : "Let go of the sticks: the dot in the small box should sit in the middle.";
    char line[256];
    while (*st && cols > 10) {
        int len = (int)strlen(st);
        if (len > cols) {
            len = cols;
            while (len > 0 && st[len] != ' ')
                len--;
            if (len == 0)
                len = cols;
        }
        snprintf(line, sizeof line, "%.*s", len, st);
        text(mx, y, 1, C_DIM, "%s", line);
        y += 11 * U;
        st += len;
        while (*st == ' ')
            st++;
    }

    y = top + size + 64 * U;
    fill(m, y - 6 * U, W - 2 * m, 1, C_GRID);
    text(m, y, 1, C_DIM, "L1/R1 stick   Up/Down row   Left/Right change   A centre here   Y undo   X save   B back");
    y += 14 * U;
    text(m, y, 1, C_DIM, "Centre moves the middle to where the stick rests; Range sets how far counts as a full push.");
    y += 12 * U;
    text(m, y, 1, C_DIM, "Smaller range = full push sooner. Auto calibration over SSH: pocket-sticks calibrate");
    if (cal.dev[0]) {
        y += 12 * U;
        text(m, y, 1, C_DIM, "Pad: %s", cal.dev);
    }
}

static void demo_cal(void)
{
    int vals[4] = { 6, -10, 61, -4 };
    for (int i = 0; i < 4; i++) {
        cal.cur[i] = (CalRange){ -1120, 1120, -1408, 1408, true };
        cal.edit[i] = cal.cur[i];
        cal.val[i] = vals[i];
    }
    cal.edit[2].min += 60;
    cal.edit[2].max += 60;
    cal.stick = 1;
    snprintf(cal.dev, sizeof cal.dev, "Retroid Pocket Gamepad");
}

static const char *btn_names[] = {
    [SDL_GAMEPAD_BUTTON_SOUTH] = "South", [SDL_GAMEPAD_BUTTON_EAST] = "East",
    [SDL_GAMEPAD_BUTTON_WEST] = "West", [SDL_GAMEPAD_BUTTON_NORTH] = "North",
    [SDL_GAMEPAD_BUTTON_BACK] = "Select", [SDL_GAMEPAD_BUTTON_GUIDE] = "Home",
    [SDL_GAMEPAD_BUTTON_START] = "Start", [SDL_GAMEPAD_BUTTON_LEFT_STICK] = "L3",
    [SDL_GAMEPAD_BUTTON_RIGHT_STICK] = "R3", [SDL_GAMEPAD_BUTTON_LEFT_SHOULDER] = "L1",
    [SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER] = "R1", [SDL_GAMEPAD_BUTTON_DPAD_UP] = "Up",
    [SDL_GAMEPAD_BUTTON_DPAD_DOWN] = "Down", [SDL_GAMEPAD_BUTTON_DPAD_LEFT] = "Left",
    [SDL_GAMEPAD_BUTTON_DPAD_RIGHT] = "Right", [SDL_GAMEPAD_BUTTON_MISC1] = "Misc",
    [SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1] = "R4", [SDL_GAMEPAD_BUTTON_LEFT_PADDLE1] = "L4",
    [SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2] = "R5", [SDL_GAMEPAD_BUTTON_LEFT_PADDLE2] = "L5",
    [SDL_GAMEPAD_BUTTON_TOUCHPAD] = "Touchpad",
};

static void draw(int W, int H, bool demo)
{
    U = H / 540.0f;
    if (W < H)
        U = W / 540.0f;
    color(C_BG);
    SDL_RenderClear(R);
    nhits = 0;

    SDL_Gamepad *pad = active >= 0 ? pads[active] : NULL;
    float m = 14 * U;
    const char *name = pad ? SDL_GetGamepadName(pad) : (demo ? "Microsoft X-Box 360 pad 0" : NULL);
    int v = SDL_GetVersion();
    text(m, m, 1.5f, C_TEXT, cal_view ? "Calibrate" : "Gamepad Tester");
    if (name && !cal_view)
        text(m + 15 * 12 * U, m + 2 * U, 1, C_DIM, "%s  %04x:%04x  %s  SDL %d.%d.%d", name,
             pad ? SDL_GetGamepadVendor(pad) : 0x045e, pad ? SDL_GetGamepadProduct(pad) : 0x028e,
             pad ? SDL_GetGamepadStringForType(SDL_GetGamepadType(pad)) : "xbox360",
             SDL_VERSIONNUM_MAJOR(v), SDL_VERSIONNUM_MINOR(v), SDL_VERSIONNUM_MICRO(v));
    if (cal_view)
        text(m + 10 * 12 * U, m + 2 * U, 1, C_DIM, "Tune where each stick's centre and edge are");
    text(m, m + 16 * U, 1, C_DIM, cal_view ? "Hold Start + Select: quit   B: back to the tester"
                                           : "Hold Start + Select: quit   Select + X: reset   Select + Y: calibrate");

    float bx = W - m - 60 * U;
    button(bx, m, 60 * U, 22 * U, "Quit", H_QUIT, false);
    if (cal_view) {
        button(bx - 70 * U, m, 60 * U, 22 * U, "Back", H_BACK, false);
    } else {
        button(bx - 70 * U, m, 60 * U, 22 * U, "Reset", H_RESET, false);
        button(bx - 170 * U, m, 90 * U, 22 * U, "Calibrate", H_CAL, false);
    }

    float top = 48 * U, size = 250 * U;
    if (size > W * 0.3f)
        size = W * 0.3f;
    if (cal_view) {
        draw_cal(W, H, top, size, m);
        return;
    }

    if (!pad && !demo) {
        text(m, H / 2.0f - 20 * U, 2, C_TEXT, "No gamepad found");
        text(m, H / 2.0f + 6 * U, 1, C_DIM, "Waiting for one to connect...");
        return;
    }

    Sint16 lx = 0, ly = 0, rx = 0, ry = 0, lt = 0, rt = 0;
    if (pad) {
        lx = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTX);
        ly = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTY);
        rx = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHTX);
        ry = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHTY);
        lt = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFT_TRIGGER);
        rt = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER);
    } else {
        lx = 24000; ly = -14500; rx = -3000; ry = 32767; lt = 32767; rt = 9000;
    }

    float tw = 300 * U;                       /* stats text is wider than the panel */
    draw_stick(m, top, size, m, "LEFT STICK", lx, ly, &sticks[0]);
    draw_stick(W - m - size, top, size, W - m - (tw > size ? tw : size), "RIGHT STICK", rx, ry, &sticks[1]);

    /* Middle: triggers, buttons, joystick axes */
    float mx = m + size + 18 * U, mw = W - 2 * (m + size + 18 * U), y = top;
    draw_bar(mx, y, mw / 2 - 4 * U, 20 * U, "LT", lt, trig_max[0]);
    draw_bar(mx + mw / 2 + 4 * U, y, mw / 2 - 4 * U, 20 * U, "RT", rt, trig_max[1]);
    y += 30 * U;

    int cols = 4;
    float bw = (mw - (cols - 1) * 6 * U) / cols, bh = 20 * U;
    int n = 0;
    for (int b = 0; b < SDL_GAMEPAD_BUTTON_COUNT; b++) {
        if (pad && !SDL_GamepadHasButton(pad, b))
            continue;
        if (!pad && b > SDL_GAMEPAD_BUTTON_DPAD_RIGHT)
            continue;
        bool down = pad ? SDL_GetGamepadButton(pad, b) : b == SDL_GAMEPAD_BUTTON_SOUTH;
        const char *bn = b < (int)(sizeof btn_names / sizeof *btn_names) ? btn_names[b] : NULL;
        if (!pad && b <= SDL_GAMEPAD_BUTTON_NORTH)
            bn = (const char *[]){ "A", "B", "X", "Y" }[b];
        if (pad && b <= SDL_GAMEPAD_BUTTON_NORTH) {
            switch (SDL_GetGamepadButtonLabel(pad, b)) {
            case SDL_GAMEPAD_BUTTON_LABEL_A: bn = "A"; break;
            case SDL_GAMEPAD_BUTTON_LABEL_B: bn = "B"; break;
            case SDL_GAMEPAD_BUTTON_LABEL_X: bn = "X"; break;
            case SDL_GAMEPAD_BUTTON_LABEL_Y: bn = "Y"; break;
            default: break;
            }
        }
        float bx = mx + (n % cols) * (bw + 6 * U), by = y + (n / cols) * (bh + 6 * U);
        fill(bx, by, bw, bh, down ? C_ACC : C_PANEL);
        if (btn_seen[b] && !down)
            frame_rect(bx, by, bw, bh, C_ACC);
        text(bx + 5 * U, by + 6 * U, 1, down ? C_BG : (btn_seen[b] ? C_TEXT : C_DIM), "%s", bn ? bn : "?");
        n++;
    }
    y += ((n + cols - 1) / cols) * (bh + 6 * U) + 6 * U;

    text(mx, y, 1, C_DIM, "SDL joystick axes (before gamepad mapping)");
    y += 12 * U;
    SDL_Joystick *joy = pad ? SDL_GetGamepadJoystick(pad) : NULL;
    int na = joy ? SDL_GetNumJoystickAxes(joy) : 6;
    char line[256];
    for (int a = 0; a < na; a += 3) {
        int len = 0;
        for (int k = a; k < na && k < a + 3; k++)
            len += snprintf(line + len, sizeof line - len, "a%d %+6d   ", k,
                            joy ? SDL_GetJoystickAxis(joy, k) : 0);
        text(mx, y, 1, C_TEXT, "%s", line);
        y += 11 * U;
    }

    /* Bottom: kernel values */
    y = top + size + 64 * U;
    if (y < top + size + 64 * U)
        y = top + size + 64 * U;
    fill(m, y - 6 * U, W - 2 * m, 1, C_GRID);
    text(m, y, 1, C_DIM, "Kernel values (evdev): reach toward each end of the device's own range");
    y += 13 * U;
    if (nraw == 0) {
        text(m, y, 1, C_DIM, "No gamepad devices found under /dev/input");
        return;
    }
    for (int i = 0; i < nraw && y < H - 12 * U; i++) {
        RawDev *d = &raw[i];
        text(m, y, 1, C_TEXT, "%s  %s", d->name, d->node);
        y += 11 * U;
        if (d->fd < 0) {
            text(m + 12 * U, y, 1, C_WARN, "can't read (%s): run  sudo pocket-padtest --raw  over SSH",
                 strerror(d->err));
            y += 13 * U;
            continue;
        }
        int shown = 0;
        float colw = (W - 2 * m) / 2;
        for (int k = 0; k < d->nax; k++) {
            if (d->ax[k].code >= ABS_HAT0X && d->ax[k].code <= ABS_HAT3Y)
                continue;
            raw_line(&d->ax[k], line, sizeof line);
            text(m + 12 * U + (shown % 2) * colw, y, 0.85f, C_TEXT, "%s", line);
            if (shown++ % 2)
                y += 10 * U;
        }
        if (shown % 2)
            y += 10 * U;
        y += 4 * U;
    }
}

static void usage(void)
{
    printf("Usage: pocket-padtest [--raw | --calibrate | --set AXIS MIN MAX ... | --apply [NODE] | --reset]\n\n"
           "  (no option)    full-screen tester: sticks, triggers, buttons, as apps see them\n"
           "  --raw          terminal table of the kernel's axis values (sudo for hidden pads)\n"
           "  --calibrate    measure the sticks' real reach and save it as their range (sudo)\n"
           "  --apply [NODE] put the saved range on the pad (sudo; udev runs this)\n"
           "  --set AXIS MIN MAX ...  save hand-picked ranges, AXIS X Y RX RY (sudo)\n"
           "  --reset        back to the driver's own range (sudo)\n\n"
           "After --calibrate, --set or --reset, restart InputPlumber; pocket-sticks does both.\n");
}

int main(int argc, char **argv)
{
    const char *shot = NULL;
    if (argc > 1) {
        if (!strcmp(argv[1], "--raw"))
            return raw_main();
        if (!strcmp(argv[1], "--calibrate"))
            return calibrate_main();
        if (!strcmp(argv[1], "--apply"))
            return apply_main(argc > 2 ? argv[2] : NULL);
        if (!strcmp(argv[1], "--reset"))
            return reset_main();
        if (!strcmp(argv[1], "--stream"))
            return stream_main();
        if (!strcmp(argv[1], "--set"))
            return set_main(argc - 2, argv + 2);
        if (!strcmp(argv[1], "--shot") && argc > 2)
            shot = argv[2];
        else {
            usage();
            return strcmp(argv[1], "-h") && strcmp(argv[1], "--help") ? 2 : 0;
        }
    }

    SDL_SetAppMetadata("Gamepad Tester", "1", "pocket-padtest");
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
        fprintf(stderr, "pocket-padtest: SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }
    SDL_Window *win = NULL;
    SDL_WindowFlags flags = SDL_WINDOW_HIGH_PIXEL_DENSITY | (shot ? 0 : SDL_WINDOW_FULLSCREEN);
    if (!SDL_CreateWindowAndRenderer("Gamepad Tester", shot ? 1920 : 960, shot ? 1080 : 540, flags, &win, &R)) {
        fprintf(stderr, "pocket-padtest: can't open a window: %s\n", SDL_GetError());
        return 1;
    }
    SDL_SetRenderVSync(R, 1);
    open_pads();

    if (shot) {
        demo_fill();
        if (argc > 3 && !strcmp(argv[3], "cal")) {
            demo_cal();
            cal_view = true;
        }
        int W, H;
        SDL_GetCurrentRenderOutputSize(R, &W, &H);
        draw(W, H, true);
        SDL_Surface *s = SDL_RenderReadPixels(R, NULL);
        if (!s || !SDL_SaveBMP(s, shot))
            fprintf(stderr, "pocket-padtest: %s\n", SDL_GetError());
        SDL_Quit();
        return 0;
    }

    bool running = true;
    Uint64 quit_since = 0, held_since = 0, held_rep = 0;
    bool reset_combo = false, cal_was = false;
    int held_dir = 0;
    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            switch (e.type) {
            case SDL_EVENT_QUIT:
                running = false;
                break;
            case SDL_EVENT_GAMEPAD_ADDED:
            case SDL_EVENT_GAMEPAD_REMOVED:
                open_pads();
                reset_all();
                break;
            case SDL_EVENT_GAMEPAD_AXIS_MOTION:
                make_active(e.gaxis.which);
                break;
            case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
                make_active(e.gbutton.which);
                if (e.gbutton.button < SDL_GAMEPAD_BUTTON_COUNT)
                    btn_seen[e.gbutton.button] = true;
                if (cal_view && active >= 0 && pads[active]) {
                    SDL_Gamepad *gp = pads[active];
                    if (SDL_GetGamepadButton(gp, SDL_GAMEPAD_BUTTON_BACK))
                        break;               /* Select + ... belongs to the combos */
                    switch (e.gbutton.button) {
                    case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER:  cal.stick = 0; break;
                    case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: cal.stick = 1; break;
                    case SDL_GAMEPAD_BUTTON_DPAD_UP:        cal.row = (cal.row + 3) % 4; break;
                    case SDL_GAMEPAD_BUTTON_DPAD_DOWN:      cal.row = (cal.row + 1) % 4; break;
                    case SDL_GAMEPAD_BUTTON_DPAD_LEFT:      cal_adjust(cal.row, -1); break;
                    case SDL_GAMEPAD_BUTTON_DPAD_RIGHT:     cal_adjust(cal.row, 1); break;
                    default:
                        switch (face(gp, e.gbutton.button)) {
                        case 'A': cal_centre_here(); break;
                        case 'B': cal_leave(); break;
                        case 'X': cal_save(); break;
                        case 'Y': cal_undo(); break;
                        default: break;
                        }
                    }
                }
                break;
            case SDL_EVENT_KEY_DOWN:
                if (cal_view && e.key.key == SDLK_ESCAPE)
                    cal_leave();
                else if (e.key.key == SDLK_ESCAPE || e.key.key == SDLK_Q)
                    running = false;
                else if (e.key.key == SDLK_R)
                    reset_all();
                break;
            case SDL_EVENT_FINGER_DOWN:
            case SDL_EVENT_MOUSE_BUTTON_DOWN: {
                if (e.type == SDL_EVENT_MOUSE_BUTTON_DOWN && e.button.which == SDL_TOUCH_MOUSEID)
                    break;
                int W, H, ww, wh;
                SDL_GetCurrentRenderOutputSize(R, &W, &H);
                SDL_GetWindowSize(win, &ww, &wh);
                float px, py;
                if (e.type == SDL_EVENT_FINGER_DOWN) {
                    px = e.tfinger.x * W;
                    py = e.tfinger.y * H;
                } else {
                    px = e.button.x * W / (ww ? ww : 1);
                    py = e.button.y * H / (wh ? wh : 1);
                }
                int id = hit_at(px, py);
                if (id == H_QUIT)
                    running = false;
                else if (id == H_RESET)
                    reset_all();
                else if (id == H_CAL)
                    cal_enter();
                else if (id == H_BACK)
                    cal_leave();
                else if (id == H_LEFT || id == H_RIGHT)
                    cal.stick = id == H_RIGHT;
                else if (id == H_HERE)
                    cal_centre_here();
                else if (id == H_DRIVER)
                    cal_driver();
                else if (id == H_UNDO)
                    cal_undo();
                else if (id == H_SAVE)
                    cal_save();
                else if (id >= H_PLUS && id < H_PLUS + 4)
                    cal_adjust(cal.row = id - H_PLUS, 1);
                else if (id >= H_MINUS && id < H_MINUS + 4)
                    cal_adjust(cal.row = id - H_MINUS, -1);
                else if (id >= H_ROW && id < H_ROW + 4)
                    cal.row = id - H_ROW;
                break;
            }
            default:
                break;
            }
        }

        SDL_Gamepad *pad = active >= 0 ? pads[active] : NULL;
        if (pad) {
            stick_track(&sticks[0], SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTX),
                        SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFTY));
            stick_track(&sticks[1], SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHTX),
                        SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHTY));
            int t;
            if ((t = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_LEFT_TRIGGER)) > trig_max[0]) trig_max[0] = t;
            if ((t = SDL_GetGamepadAxis(pad, SDL_GAMEPAD_AXIS_RIGHT_TRIGGER)) > trig_max[1]) trig_max[1] = t;

            bool sel = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_BACK);
            bool start = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_START);
            if (sel && start) {
                if (!quit_since)
                    quit_since = SDL_GetTicks();
                else if (SDL_GetTicks() - quit_since > 1000)
                    running = false;
            } else {
                quit_since = 0;
            }
            bool combo = sel && SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_WEST);
            if (combo && !reset_combo && !cal_view)
                reset_all();
            reset_combo = combo;
            bool cal_combo = sel && SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_NORTH);
            if (cal_combo && !cal_was && !cal_view)
                cal_enter();
            cal_was = cal_combo;

            /* Holding Left/Right keeps changing the value */
            int dir = SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_RIGHT) -
                      SDL_GetGamepadButton(pad, SDL_GAMEPAD_BUTTON_DPAD_LEFT);
            Uint64 now = SDL_GetTicks();
            if (dir != held_dir) {
                held_dir = dir;
                held_since = now;
            } else if (cal_view && dir && now - held_since > 350 && now - held_rep > 40) {
                cal_adjust(cal.row, dir);
                held_rep = now;
            }
        }
        raw_poll();
        cal_poll();
        cal_check_saver();

        int W, H;
        SDL_GetCurrentRenderOutputSize(R, &W, &H);
        draw(W, H, false);
        if (quit_since)
            text(W / 2.0f - 60 * U, 30 * U, 1.25f, C_WARN, "Quitting...");
        SDL_RenderPresent(R);
    }

    cal_close();
    print_summary();
    raw_close();
    SDL_Quit();
    return 0;
}
