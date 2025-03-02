# Pin npm packages by running ./bin/importmap

pin "application"
pin_all_from "app/javascript/channels", under: "channels"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/src", under: "src"

# From gems
pin "@hotwired/stimulus", to: "stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "trix" # @2.1.11

# # CodeMirror for formula editor
# pin "codemirror", to: "https://unpkg.com/codemirror@5.65.13/lib/codemirror.js"
# pin "codemirror/mode/javascript/javascript", to: "https://unpkg.com/codemirror@5.65.13/mode/javascript/javascript.js"
# pin "codemirror/addon/hint/show-hint", to: "https://unpkg.com/codemirror@5.65.13/addon/hint/show-hint.js"
# pin "codemirror/addon/edit/matchbrackets", to: "https://unpkg.com/codemirror@5.65.13/addon/edit/matchbrackets.js"
# pin "codemirror/addon/edit/closebrackets", to: "https://unpkg.com/codemirror@5.65.13/addon/edit/closebrackets.js"

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
pin "sortablejs" # @1.15.6
