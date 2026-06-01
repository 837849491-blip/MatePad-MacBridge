#include <ApplicationServices/ApplicationServices.h>
#include <CoreGraphics/CoreGraphics.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define PORT 18765
#define BUF_SIZE 8192

static const char *HTML =
"<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'>"
"<meta name='viewport' content='width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no'>"
"<title>MatePad Control</title><style>"
":root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text',sans-serif}"
"html,body{margin:0;height:100%;background:#101214;color:#f5f5f5;overflow:hidden}"
"body{display:grid;grid-template-rows:auto 1fr auto;gap:12px;padding:16px;box-sizing:border-box}"
".top{display:flex;gap:10px;align-items:center;justify-content:space-between}h1{font-size:22px;margin:0}.status{font-size:14px;color:#9ee7b3}"
"#pad{touch-action:none;user-select:none;border:1px solid #30363d;background:#181b20;border-radius:10px;position:relative;overflow:hidden}"
"#pad:after{content:'触控板';position:absolute;inset:0;display:grid;place-items:center;color:#5e6875;font-size:36px;letter-spacing:4px;pointer-events:none}"
".controls{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px}button{height:72px;border:0;border-radius:10px;color:#fff;font-size:20px;font-weight:700;background:#2b3138}"
"button:active{transform:scale(.98);filter:brightness(1.2)}.voice{background:#1778ff}.click{background:#2f7d46}.right{background:#5b4ab7}.hint{color:#9ca3af;font-size:13px;line-height:1.5;margin-top:8px}"
"</style></head><body><div class='top'><h1>MatePad 控制 Mac</h1><div class='status' id='status'>已连接</div></div>"
"<div id='pad'></div><div><div class='controls'><button class='click' id='left'>点击</button><button class='voice' id='voice'>豆包语音</button><button class='right' id='right'>右键</button></div>"
"<div class='hint'>单指滑动移动鼠标；轻点触控板=点击；双指上下滑动=滚动；“豆包语音”会双击右 Option，调用豆包免按语音输入。</div></div>"
"<script>"
"const s=document.getElementById('status'),pad=document.getElementById('pad');let ps=new Map();"
"async function api(p){try{await fetch(p,{cache:'no-store'});s.textContent='已连接'}catch(e){s.textContent='连接断开'}}"
"pad.addEventListener('pointerdown',e=>{pad.setPointerCapture(e.pointerId);ps.set(e.pointerId,{x:e.clientX,y:e.clientY,t:performance.now(),sx:e.clientX,sy:e.clientY})});"
"pad.addEventListener('pointermove',e=>{let p=ps.get(e.pointerId);if(!p)return;let dx=e.clientX-p.x,dy=e.clientY-p.y;ps.set(e.pointerId,{...p,x:e.clientX,y:e.clientY});if(ps.size>=2){api('/scroll?dy='+encodeURIComponent(dy))}else if(Math.abs(dx)+Math.abs(dy)>.5){api('/move?dx='+encodeURIComponent(dx)+'&dy='+encodeURIComponent(dy))}});"
"pad.addEventListener('pointerup',e=>{let p=ps.get(e.pointerId);ps.delete(e.pointerId);if(!p)return;let dt=performance.now()-p.t,m=Math.hypot(e.clientX-p.sx,e.clientY-p.sy);if(dt<260&&m<10)api('/click')});"
"pad.addEventListener('pointercancel',e=>ps.delete(e.pointerId));document.getElementById('left').onclick=()=>api('/click');document.getElementById('right').onclick=()=>api('/rightclick');document.getElementById('voice').onclick=()=>api('/voice');"
"</script></body></html>";

static CGEventSourceRef source;
static int touch_down = 0;

static double qnum(const char *path, const char *key) {
    char pattern[64];
    snprintf(pattern, sizeof(pattern), "%s=", key);
    char *p = strstr(path, pattern);
    if (!p) return 0.0;
    return atof(p + strlen(pattern));
}

static CGPoint mouse_pos(void) {
    CGEventRef e = CGEventCreate(NULL);
    CGPoint p = e ? CGEventGetLocation(e) : CGPointMake(0, 0);
    if (e) CFRelease(e);
    return p;
}

static void move_mouse(double dx, double dy) {
    CGPoint p = mouse_pos();
    CGPoint n = CGPointMake(p.x + dx * 1.35, p.y + dy * 1.35);
    CGEventRef e = CGEventCreateMouseEvent(source, kCGEventMouseMoved, n, kCGMouseButtonLeft);
    if (e) { CGEventPost(kCGHIDEventTap, e); CFRelease(e); }
}

static void click_mouse(CGMouseButton button, CGEventType downType, CGEventType upType) {
    CGPoint p = mouse_pos();
    CGEventRef d = CGEventCreateMouseEvent(source, downType, p, button);
    CGEventRef u = CGEventCreateMouseEvent(source, upType, p, button);
    if (d) { CGEventPost(kCGHIDEventTap, d); CFRelease(d); }
    usleep(30000);
    if (u) { CGEventPost(kCGHIDEventTap, u); CFRelease(u); }
}

static void scroll_mouse(double dy) {
    int32_t units = (int32_t)(-dy / 3.0);
    if (units > 12) units = 12;
    if (units < -12) units = -12;
    CGEventRef e = CGEventCreateScrollWheelEvent(source, kCGScrollEventUnitPixel, 1, units);
    if (e) { CGEventPost(kCGHIDEventTap, e); CFRelease(e); }
}

static CGRect target_display_bounds(void) {
    CGDirectDisplayID displays[16];
    uint32_t count = 0;
    CGDirectDisplayID mainDisplay = CGMainDisplayID();
    if (CGGetActiveDisplayList(16, displays, &count) != kCGErrorSuccess || count == 0) {
        return CGDisplayBounds(mainDisplay);
    }

    for (uint32_t i = 0; i < count; i++) {
        if (displays[i] == mainDisplay) continue;
        CGRect b = CGDisplayBounds(displays[i]);
        if ((b.size.width == 1920 && b.size.height == 1200) ||
            (b.size.width == 1200 && b.size.height == 1920)) {
            return b;
        }
    }

    for (uint32_t i = 0; i < count; i++) {
        if (displays[i] != mainDisplay) {
            return CGDisplayBounds(displays[i]);
        }
    }
    return CGDisplayBounds(mainDisplay);
}

static void direct_touch(double x, double y, int type) {
    if (x < 0.0) x = 0.0;
    if (x > 1.0) x = 1.0;
    if (y < 0.0) y = 0.0;
    if (y > 1.0) y = 1.0;

    CGRect b = target_display_bounds();
    CGPoint p = CGPointMake(b.origin.x + x * b.size.width, b.origin.y + y * b.size.height);
    CGEventType eventType = kCGEventMouseMoved;
    if (type == 0) {
        eventType = kCGEventLeftMouseDown;
        touch_down = 1;
    } else if (type == 1) {
        eventType = touch_down ? kCGEventLeftMouseDragged : kCGEventMouseMoved;
    } else {
        eventType = touch_down ? kCGEventLeftMouseUp : kCGEventMouseMoved;
        touch_down = 0;
    }

    CGEventRef e = CGEventCreateMouseEvent(source, eventType, p, kCGMouseButtonLeft);
    if (e) { CGEventPost(kCGHIDEventTap, e); CFRelease(e); }
}

static void tap_key(CGKeyCode key) {
    CGEventRef d = CGEventCreateKeyboardEvent(source, key, true);
    CGEventRef u = CGEventCreateKeyboardEvent(source, key, false);
    if (d) { CGEventPost(kCGHIDEventTap, d); CFRelease(d); }
    usleep(45000);
    if (u) { CGEventPost(kCGHIDEventTap, u); CFRelease(u); }
}

static void doubao_voice(void) {
    tap_key(61);
    usleep(90000);
    tap_key(61);
}

static void send_response(int fd, const char *body, const char *type) {
    char header[512];
    size_t len = strlen(body);
    int n = snprintf(header, sizeof(header),
        "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %zu\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
        type, len);
    write(fd, header, n);
    write(fd, body, len);
}

static void send_json_status(int fd) {
    char body[512];
    CGPoint p = mouse_pos();
    snprintf(body, sizeof(body),
        "{\"ok\":true,\"axTrusted\":%s,\"x\":%.1f,\"y\":%.1f,\"port\":%d}",
        AXIsProcessTrusted() ? "true" : "false", p.x, p.y, PORT);
    send_response(fd, body, "application/json; charset=utf-8");
}

static void handle_client(int fd) {
    char buf[BUF_SIZE] = {0};
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    if (n <= 0) return;
    char method[16] = {0}, path[2048] = {0};
    sscanf(buf, "%15s %2047s", method, path);

    if (strcmp(path, "/") == 0 || strncmp(path, "/?", 2) == 0) {
        send_response(fd, HTML, "text/html; charset=utf-8");
    } else if (strncmp(path, "/health", 7) == 0) {
        send_json_status(fd);
    } else if (strncmp(path, "/move", 5) == 0) {
        move_mouse(qnum(path, "dx"), qnum(path, "dy"));
        send_response(fd, "ok", "text/plain; charset=utf-8");
    } else if (strncmp(path, "/click", 6) == 0) {
        click_mouse(kCGMouseButtonLeft, kCGEventLeftMouseDown, kCGEventLeftMouseUp);
        send_response(fd, "ok", "text/plain; charset=utf-8");
    } else if (strncmp(path, "/rightclick", 11) == 0) {
        click_mouse(kCGMouseButtonRight, kCGEventRightMouseDown, kCGEventRightMouseUp);
        send_response(fd, "ok", "text/plain; charset=utf-8");
    } else if (strncmp(path, "/scroll", 7) == 0) {
        scroll_mouse(qnum(path, "dy"));
        send_response(fd, "ok", "text/plain; charset=utf-8");
    } else if (strncmp(path, "/touch", 6) == 0) {
        direct_touch(qnum(path, "x"), qnum(path, "y"), (int)qnum(path, "type"));
        send_response(fd, "ok", "text/plain; charset=utf-8");
    } else if (strncmp(path, "/voice", 6) == 0) {
        doubao_voice();
        send_response(fd, "ok", "text/plain; charset=utf-8");
    } else {
        send_response(fd, "not found", "text/plain; charset=utf-8");
    }
}

int main(void) {
    source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    const void *keys[] = { kAXTrustedCheckOptionPrompt };
    const void *vals[] = { kCFBooleanTrue };
    CFDictionaryRef opts = CFDictionaryCreate(NULL, keys, vals, 1, NULL, NULL);
    AXIsProcessTrustedWithOptions(opts);
    CFRelease(opts);

    int server = socket(AF_INET, SOCK_STREAM, 0);
    int yes = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(PORT);
    if (bind(server, (struct sockaddr *)&addr, sizeof(addr)) != 0) { perror("bind"); return 1; }
    if (listen(server, 16) != 0) { perror("listen"); return 1; }
    printf("MatePad Control running: http://127.0.0.1:%d\n", PORT);
    fflush(stdout);
    while (1) {
        int client = accept(server, NULL, NULL);
        if (client >= 0) {
            handle_client(client);
            close(client);
        }
    }
    return 0;
}
