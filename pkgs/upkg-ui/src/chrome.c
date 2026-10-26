/* chrome.c: pure line builders for upkg-ui; see chrome.h. */
#include "chrome.h"

#include <string.h>

static int imax(int a, int b) { return a > b ? a : b; }
static int imin(int a, int b) { return a < b ? a : b; }

/* append up to n bytes of s to out at *at, never past cap - 1 */
static void put(char *out, size_t cap, size_t *at, const char *s, size_t n)
{
	size_t room = cap - 1 - *at;
	if (n > room)
		n = room;
	memcpy(out + *at, s, n);
	*at += n;
}

void ch_mast_layout(ch_mast *m, int width, const char *rail, const char *title, const char *value)
{
	int rl = (int)strlen(rail), tl = (int)strlen(title), vl = (int)strlen(value);
	int left = rl ? rl + 1 + tl : tl;
	int room = width - left - vl - 2;
	memset(m, 0, sizeof *m);
	if (width <= 0)
		return;
	m->rail_len = imin(rl, width);
	m->title_col = rl ? rl + 1 : 0;
	if (room < 1) {
		int trimmed = imax(0, width - rl - vl - 3);
		m->title_len = imax(0, imin(imin(tl, trimmed), width - m->title_col));
		m->value_col = m->title_col + m->title_len + 1;
		m->value_len = imax(0, imin(vl, width - m->value_col));
		return;
	}
	m->title_len = tl;
	m->lead_col = left + 1;
	m->lead_n = room;
	m->value_col = m->lead_col + room + 1;
	m->value_len = vl;
}

size_t ch_masthead_line(char *out, size_t cap, int width, const char *rail, const char *title,
                        const char *value, const char *leader)
{
	ch_mast m;
	size_t at = 0, ll = strlen(leader);
	int i, cells = 0;

	if (cap == 0)
		return 0;
	out[0] = 0;
	if (width <= 0)
		return 0;
	ch_mast_layout(&m, width, rail, title, value);
	if (m.lead_n == 0) {
		/* (head + " " + right).slice(0, width).padEnd(width) */
		char tmp[512];
		size_t t = 0;
		put(tmp, sizeof tmp, &t, rail, strlen(rail));
		if (*rail)
			put(tmp, sizeof tmp, &t, " ", 1);
		put(tmp, sizeof tmp, &t, title, (size_t)m.title_len);
		put(tmp, sizeof tmp, &t, " ", 1);
		put(tmp, sizeof tmp, &t, value, strlen(value));
		if ((int)t > width)
			t = (size_t)width;
		put(out, cap, &at, tmp, t);
		cells = (int)t;
	} else {
		if (*rail) {
			put(out, cap, &at, rail, strlen(rail));
			put(out, cap, &at, " ", 1);
		}
		put(out, cap, &at, title, strlen(title));
		put(out, cap, &at, " ", 1);
		for (i = 0; i < m.lead_n; i++)
			put(out, cap, &at, leader, ll);
		put(out, cap, &at, " ", 1);
		put(out, cap, &at, value, strlen(value));
		cells = width;
	}
	for (; cells < width; cells++)
		put(out, cap, &at, " ", 1);
	out[at] = 0;
	return at;
}

void ch_rail_pattern(char *out, size_t cap, const char *rail, int width, int gap, int offset)
{
	char unit[128];
	size_t ul = strlen(rail), n = 0;
	int shift, i;

	if (cap == 0)
		return;
	out[0] = 0;
	if (!ul || width <= 0 || ul + (size_t)gap >= sizeof unit)
		return;
	memcpy(unit, rail, ul);
	for (i = 0; i < gap; i++)
		unit[ul++] = ' ';
	shift = ((offset % (int)ul) + (int)ul) % (int)ul;
	for (i = 0; i < width && n + 1 < cap; i++)
		out[n++] = unit[(shift + i) % (int)ul];
	out[n] = 0;
}

void ch_rail_frame(char *out, size_t cap, const char *rail, int tick)
{
	int period = (int)strlen(rail), shift, i;
	size_t n = 0;

	if (cap == 0)
		return;
	out[0] = 0;
	if (!period)
		return;
	shift = ((tick % period) + period) % period;
	for (i = 0; i < shift && n + 1 < cap; i++)
		out[n++] = ' ';
	for (i = 0; i < period - shift && n + 1 < cap; i++)
		out[n++] = rail[i];
	out[n] = 0;
}

static int plain_len(const ch_hint *h, int n, unsigned shown, int tail)
{
	int i, len = 0, count = 0;
	for (i = 0; i < n; i++) {
		if (!(shown & (1u << i)))
			continue;
		len += (int)strlen(h[i].key) + 2 + (int)strlen(h[i].does);
		count++;
	}
	if (count > 1)
		len += 2 * (count - 1);
	if (tail)
		len += 2 + tail;
	return len;
}

ch_foot ch_footer_fit(const ch_hint *hints, int n, const char *rail, int fit)
{
	ch_foot f;
	int tail = (int)strlen(rail), i;

	if (n > 32)
		n = 32;
	f.shown = n == 32 ? 0xffffffffu : (1u << n) - 1;
	f.rail = tail > 0;
	if (fit >= 0) {
		if (plain_len(hints, n, f.shown, f.rail ? tail : 0) > fit)
			f.rail = 0;
		while (plain_len(hints, n, f.shown, f.rail ? tail : 0) > fit) {
			int drop = -1;
			for (i = n - 1; i >= 0; i--) {
				if ((f.shown & (1u << i)) && !hints[i].keep) {
					drop = i;
					break;
				}
			}
			if (drop < 0)
				break;
			f.shown &= ~(1u << drop);
		}
	}
	f.len = plain_len(hints, n, f.shown, f.rail ? tail : 0);
	return f;
}

void ch_footer_text(char *out, size_t cap, const ch_hint *hints, int n, const char *rail, ch_foot f)
{
	size_t at = 0;
	int i, first = 1;

	if (cap == 0)
		return;
	for (i = 0; i < n && i < 32; i++) {
		if (!(f.shown & (1u << i)))
			continue;
		if (!first)
			put(out, cap, &at, "  ", 2);
		first = 0;
		put(out, cap, &at, hints[i].key, strlen(hints[i].key));
		put(out, cap, &at, ": ", 2);
		put(out, cap, &at, hints[i].does, strlen(hints[i].does));
	}
	if (f.rail) {
		put(out, cap, &at, "  ", 2);
		put(out, cap, &at, rail, strlen(rail));
	}
	out[at] = 0;
}

int ch_wrap_words(const char *text, int width, ch_span *out, int max)
{
	int n = 0, i = 0, len = (int)strlen(text);

	if (width < 1)
		width = 1;
	while (n < max) {
		int ls = i, le = i; /* current line: [ls, le) */
		int brk = 0;
		/* skip the spaces a wrap left at a line start (not after a newline: indentation stays) */
		while (i < len) {
			int ws, we;
			if (text[i] == '\n') {
				i++;
				brk = 1;
				break;
			}
			if (text[i] == ' ') {
				i++;
				continue;
			}
			ws = i;
			while (i < len && text[i] != ' ' && text[i] != '\n')
				i++;
			we = i;
			if (le == ls) {
				/* first word of the line: cut it only when wider than a line */
				if (we - ws > width) {
					ls = ws;
					le = ws + width;
					i = le;
					break;
				}
				ls = ws;
				le = we;
			} else if (we - ls <= width) {
				le = we;
			} else {
				i = ws;
				break;
			}
		}
		if (le == ls && !brk && i >= len)
			break;
		out[n].start = ls;
		out[n].len = le - ls;
		n++;
		if (i >= len && !brk)
			break;
		if (i >= len && brk)
			break;
	}
	return n;
}

int ch_vis_len(const char *s, int colors)
{
	int n = 0;
	if (!colors)
		return (int)strlen(s);
	for (; *s; s++, n++)
		if (s[0] == '\\' && s[1] == 'Z' && s[2])
			s += 2, n--;
	return n;
}

int ch_widest(const char *const *s, int n, int stride, int colors)
{
	int i, w = 0;
	for (i = 0; i < n; i++) {
		int l = ch_vis_len(s[i * stride], colors);
		if (l > w)
			w = l;
	}
	return w;
}

ch_osd ch_osd_layout(int lines, int cols, int top, int filter, int gap, int bottom, int pad)
{
	ch_osd o;
	o.filter_row = top;
	o.first_row = top + filter + gap;
	o.rows = lines - o.first_row - bottom;
	if (o.rows < 1)
		o.rows = 1;
	o.bar_x = 0;
	o.bar_w = cols;
	o.text_x = pad;
	o.item_end = cols - pad;
	return o;
}

int ch_menu_hints(ch_hint *out, unsigned flags)
{
	int n = 0;

	out[n].key = "Up/Down", out[n].does = "Move", out[n++].keep = 0;
	out[n].key = "Enter", out[n].does = (flags & CH_ENTRY_LAUNCH) ? "Launch" : "Accept", out[n++].keep = 1;
	if (flags & CH_ENTRY_INSTALLED)
		out[n].key = "Delete", out[n].does = "Remove", out[n++].keep = 0;
	out[n].key = "Escape", out[n].does = "Cancel", out[n++].keep = 1;
	return n;
}
