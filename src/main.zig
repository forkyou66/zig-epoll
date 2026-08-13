const builtin = @import("builtin");
const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const native_os = builtin.os.tag;

const linux = std.os.linux;
const accept = linux.accept;
const read = linux.read;
const write = linux.write;
const close = linux.close;
const epoll_create1 = linux.epoll_create1;
const epoll_ctl = linux.epoll_ctl;
const epoll_wait = linux.epoll_wait;
const epoll_event = linux.epoll_event;
const Epoll = linux.EPOLL;

const address: []const u8 = "127.0.0.1";
const port: u16 = 4040;
const rbuf_size: usize = 1024;
const max_events: usize = 1024;
const max_connections: usize = max_events * 2;

fn epollCreate() !i32 {
    debug.print("[epollCreate]: creating epoll fd\n", .{});
    const raw: usize = epoll_create1(0);
    const signed: isize = @bitCast(raw);

    if (signed > -4096 and signed < 0)
        return error.EpollCreateFailed;

    const epoll_fd: i32 = @intCast(signed);
    debug.print("[epollCreate]: epoll fd created: {any}\n", .{epoll_fd});
    return epoll_fd;
}

fn acceptConn(epoll_fd: i32, listen_fd: i32) i32 {
    const client_fd = accept(listen_fd, null, null);
    assert(client_fd >= 0);

    var ev: epoll_event = .{ .events = Epoll.IN, .data = .{ .fd = @intCast(client_fd) } };
    const result: usize = epoll_ctl(epoll_fd, Epoll.CTL_ADD, @intCast(client_fd), &ev);
    assert(result == 0);

    debug.print("[acceptConn]: epoll_ctl added socket with result: {any}\n", .{result});
    return @intCast(client_fd);
}

fn addListenFd(epoll_fd: i32, listen_fd: i32) void {
    var ev: epoll_event = .{ .events = Epoll.IN, .data = .{ .fd = @intCast(listen_fd) } };
    const result: usize = epoll_ctl(epoll_fd, Epoll.CTL_ADD, @intCast(listen_fd), &ev);
    assert(result == 0);

    debug.print("[addListenFd]: epoll_ctl added listen socket with result: {any}\n", .{result});
}

fn handleConn(epoll_fd: i32, client_fd: i32) !void {
    var buf: [rbuf_size]u8 = undefined;
    const n: usize = read(client_fd, &buf, rbuf_size);
    debug.print("[handleConn]: read {any} bytes from the socket\n", .{n});
    if (n <= 0) {
        debug.print("[handleConn]: closing connection\n", .{});
        assert(epoll_ctl(epoll_fd, Epoll.CTL_DEL, client_fd, null) == 0);
        assert(close(client_fd) == 0);
        debug.print("[handleConn]: connection closed\n", .{});
        return error.ConnectionClosed;
    }
    const written = write(client_fd, buf[0..n].ptr, n);
    assert(written == n);
    debug.print("[handleConn]: wrote {any} bytes to the socket\n", .{written});
}

fn eventLoop(alloc: std.mem.Allocator, epoll_fd: i32, listen_fd: i32) void {
    var active_fds = std.AutoHashMap(i32, void).init(alloc);
    defer active_fds.deinit();

    var events: [max_events]epoll_event = undefined;
    debug.print("[eventLoop]: events buffer allocated\n", .{});

    while (true) {
        debug.print("[eventLoop]: waiting for events\n", .{});
        const n = epoll_wait(epoll_fd, &events, max_events, -1);
        debug.print("[eventLoop]: epoll_wait returned: {any}\n", .{n});
        if (n <= 0) continue;

        for (events[0..n]) |event| {
            if (event.data.fd == listen_fd) {
                debug.print("[eventLoop]: accepting new connection\n", .{});
                const client_fd = acceptConn(epoll_fd, listen_fd);
                active_fds.put(client_fd, {}) catch unreachable;
            } else {
                debug.print("[eventLoop]: handling existing connection\n", .{});
                handleConn(epoll_fd, event.data.fd) catch {
                    assert(active_fds.remove(event.data.fd));
                };
            }
        }
    }
}

pub fn main(init: std.process.Init) !void {
    assert(native_os == .linux);

    const addr = try std.Io.net.IpAddress.parse(address, port);
    var server = try addr.listen(init.io, .{});
    defer server.deinit(init.io);

    debug.print("[main]: server listening on {s}:{any}\n", .{ address, port });

    const listen_fd: std.c.fd_t = server.socket.handle;
    assert(@TypeOf(listen_fd) == i32);

    const epoll_fd: i32 = try epollCreate();
    defer assert(close(epoll_fd) == 0);

    addListenFd(epoll_fd, listen_fd);
    eventLoop(init.gpa, epoll_fd, listen_fd);
}
