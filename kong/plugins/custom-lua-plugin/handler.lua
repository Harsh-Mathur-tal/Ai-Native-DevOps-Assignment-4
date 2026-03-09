-- Custom Kong Lua Plugin: handler
-- Provides structured request logging and custom header injection
-- Compatible with Kong 3.x plugin API

local cjson = require("cjson")

local CustomLuaHandler = {
  PRIORITY = 1000,
  VERSION = "1.0.0",
}

function CustomLuaHandler:access(conf)
  -- Generate unique request ID
  local request_id = kong.request.get_header("X-Request-ID")
  if not request_id then
    request_id = kong.node.get_id() .. "-" .. ngx.now() .. "-" .. math.random(1000, 9999)
  end

  -- Inject request ID as upstream header so the backend can use it
  if conf.inject_header then
    kong.service.request.set_header(conf.header_name or "X-Request-ID", request_id)
  end

  -- Store request_id in Kong's shared context for header_filter phase
  kong.ctx.plugin.request_id = request_id

  -- Structured request logging
  if conf.log_requests then
    local log_data = {
      timestamp  = ngx.localtime(),
      method     = kong.request.get_method(),
      uri        = kong.request.get_path(),
      remote_addr = kong.client.get_ip(),
      request_id = request_id,
      user_agent = kong.request.get_header("User-Agent") or "unknown",
    }
    kong.log.info("Custom Plugin Log: ", cjson.encode(log_data))
  end
end

function CustomLuaHandler:header_filter(conf)
  -- Add request ID to response headers so clients can trace requests
  if conf.inject_header then
    local request_id = kong.ctx.plugin.request_id
    if request_id then
      kong.response.set_header(conf.header_name or "X-Request-ID", request_id)
    end
  end

  -- Add a custom header indicating the request passed through Kong
  kong.response.set_header("X-Kong-Custom-Plugin", "active")
end

return CustomLuaHandler
