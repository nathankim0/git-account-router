# Contributing

Pull requests are welcome. Keep changes focused and preserve the security boundary: never read, print, persist, or transmit GitHub tokens from the app.

```sh
./scripts/check.sh
./scripts/create-dmg.sh 0.1.0
```

Core routing logic belongs in `GitAccountRouterCore` and should have a deterministic test in `Tests/GitAccountRouterCoreTests/main.swift`. UI code should remain in small AppKit view controllers.
