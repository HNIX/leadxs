# Pin npm packages by running ./bin/importmap
pin "application", preload: true
pin_all_from "app/javascript/channels", under: "channels"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/src", under: "src"
pin_all_from "vendor/javascript"

# From gems
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "trix" # @2.1.11

# Vendor libraries
pin "@hotwired/hotwire-native-bridge", to: "@hotwired--hotwire-native-bridge.js" # @1.0.0
pin "clipboard" # @2.0.11
pin "local-time", to: "local-time.es2017-esm.js"
pin "tailwindcss-stimulus-components" # @6.1.3
pin "tributejs" # @5.1.3
pin "@floating-ui/dom", to: "@floating-ui--dom.js" # @1.6.12
pin "@floating-ui/core", to: "@floating-ui--core.js" # @1.6.8
pin "@floating-ui/utils", to: "@floating-ui--utils.js" # @0.2.8
pin "@floating-ui/utils/dom", to: "@floating-ui--utils--dom.js" # @0.2.8
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.11
pin "sortablejs" # @1.15.6pin "codemirror" # @6.0.1

# Pin Ace Editor core
pin "ace-builds", to: "node_modules/ace-builds/src-min-noconflict/ace.js"

# Pin common modes and themes
pin "ace-builds/mode-ruby", to: "node_modules/ace-builds/src-min-noconflict/mode-ruby.js"
pin "ace-builds/mode-javascript", to: "node_modules/ace-builds/src-min-noconflict/mode-javascript.js"
pin "ace-builds/mode-html", to: "node_modules/ace-builds/src-min-noconflict/mode-html.js"
pin "ace-builds/mode-css", to: "node_modules/ace-builds/src-min-noconflict/mode-css.js"
pin "ace-builds/theme-monokai", to: "node_modules/ace-builds/src-min-noconflict/theme-monokai.js"
pin "ace-builds/theme-github", to: "node_modules/ace-builds/src-min-noconflict/theme-github.js"

