# TODOs
 * Path to cfg.js is always in root

 * Wenn die WebUI mit Ctrl-C abgebrochen wird, beendet sich die UV Loop nicht. Da sind also noch Elemente drin.

 * Vielleicht eine "Reboot" Möglichkeit? Das waere praktisch für Remote Stations.
   Vielleicht mit einem Kommando aus der Config? Dann kann das auf einem Laptop deaktiviert werden.


# Noch aktuell?

* Insufficient permissions in depack folder produces no error message.

* Passing multiple Kafka server results in a crash (table passed? concat with comma?).

* Pegasus was updated!

* "Test running" indicator keeps spinning if a test step fails to validate its parameters.


# DONE

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
