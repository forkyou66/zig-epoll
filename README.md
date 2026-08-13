# epoll-zig

A lil playground project for messing about with Linux `epoll` in Zig.

Runs a basic TCP echo server on `127.0.0.1:4040` using an epoll event loop —
accepts connections, reads whatever you send, and writes it straight back.

## Running

```zsh
zig build run
```

Then in another terminal:

```zsh
nc 127.0.0.1 4040
```

Type something and it'll echo back.

## Status

Just a learning project, nothing fancy. No error handling to write home about,
built purely to get a feel for `epoll_create`, `epoll_ctl`, and `epoll_wait`.
