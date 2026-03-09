FROM kong:3.4

# Install custom Lua plugin into Kong's plugin path
COPY plugins/custom-lua-plugin/handler.lua /usr/local/share/lua/5.1/kong/plugins/custom-lua-plugin/handler.lua
COPY plugins/custom-lua-plugin/schema.lua /usr/local/share/lua/5.1/kong/plugins/custom-lua-plugin/schema.lua
