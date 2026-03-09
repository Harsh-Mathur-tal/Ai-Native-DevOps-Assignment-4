-- Custom Kong Lua Plugin: schema
-- Defines configuration fields for the custom-lua-plugin

local typedefs = require "kong.db.schema.typedefs"

return {
  name = "custom-lua-plugin",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    {
      config = {
        type = "record",
        fields = {
          {
            inject_header = {
              type = "boolean",
              default = true,
              required = true,
            },
          },
          {
            header_name = {
              type = "string",
              default = "X-Request-ID",
              required = false,
            },
          },
          {
            log_requests = {
              type = "boolean",
              default = true,
              required = true,
            },
          },
        },
      },
    },
  },
}
