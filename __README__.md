# TODOs

 * Vielleicht eine "Reboot" Möglichkeit? Das waere praktisch für Remote Stations.
   Vielleicht mit einem Kommando aus der Config? Dann kann das auf einem Laptop deaktiviert werden.

 * Mimetypes von Lunarmodules verwenden.
   Da ist aber auch kein Mime Type für "woff" oder "woff2" drin.

# Noch aktuell?

* Insufficient permissions in depack folder produces no error message.

* Passing multiple Kafka server results in a crash (table passed? concat with comma?).

* Pegasus was updated!


# DONE
 * Events und Logs per API abliefern.

 * Heartbeat per API in Yugamooga schreiben.

 * Dataprovider auf API V2 mit Auth umbauen.

 * Matrixaufkleber mit Orderinfo prüfen. Auch Seriennummer berücksichtigen.

 * Orderinfo aus /tmp/muhkuh/orderinfo.json lesen.

 * Titel und Subtitel aus Orderinfo nehmen.

 * In Firefox: downloadable font rejected by sanitizer
 Ist das wegen dem Mime-Type? Muss "font/woff2" sein. Vielleict ein Update für mimetypes? Ja, gibt's ier: https://github.com/lunarmodules/lua-mimetypes
 Da ist aber auc kein Typ für woff und woff2 drin.
Das ist es aber nict. Im www/webui Ordner sind nur "woff" und "woff2" Files, die eine Art JS Verweis aben. Die kompletten Files sind unter "www/webui/fonts".
https://stackoverflow.com/questions/70149253/why-is-webpack-emitting-font-files-that-are-actually-javascript
-> Wechsel auf Assets.

 * If the test process crashed, CTRL-C does not work anymore:
```
/home/cthelen/workspace/org.muhkuh.tools-webui/targets/webui-0.0.6/lua5.4: ...g.muhkuh.tools-webui/targets/webui-0.0.6/lua/process.lua:89: calling 'kill' on bad self (Lua-UV Handle closed)
```

 * If a test step fails to validate te parameters, there is no error message. The test just restarts. Switching to the logs show te error.
ZMQ Verbindung wird gesclossen. Das kann in test_system.lua mit einer Interaction angezeigt werden.

 * "Test running" indicator keeps spinning if a test step fails to validate its parameters.

 * When the WebUI is cancelled with Ctrl-C, the UV loop does not terminate.

 * Path to cfg.js is served in root, but requested in the path configured in "webserver_path".

* Deselected tests are still deselected in the cow heads for the next board, but they are really active.

* Center running test? -> Not with SVG.

* Get GIT Version in a shell script, not JS
  *** get_version = 0.0.4 ***
  *** get_vcsversion = GIT47e328f93836 ***
  (node:4335) [DEP_WEBPACK_COMPILATION_ASSETS] DeprecationWarning: Compilation.assets will be frozen in future, all modifications are deprecated.
  BREAKING CHANGE: No more changes should happen to Compilation.assets after sealing the Compilation.
    Do changes to assets earlier, e. g. in Compilation.hooks.processAssets.
    Make sure to select an appropriate stage from Compilation.PROCESS_ASSETS_STAGE_*.

* Update MUI:
https://mui.com/guides/migration-v4/

* Github Action in Build Web Frontend und Rest aufspalten, wie beim romloader_pt build mit der Firmware.

* babel-standalone is now @babel/standalone
https://stackoverflow.com/questions/14515078/how-i-can-access-to-package-json-config-section

* Replace the stinking old react-image-magnify with http://malaman.github.io/react-image-zoom/example/index.html
