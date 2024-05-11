local upstream_servers = { "server3:8080", "server4:8080" }
                
-- Import the Redis client library
local redis = require "resty.redis"

-- Define the Redis host and port
local redis_host = "redis"
local redis_port = 6379

-- Connect to Redis
local red = redis:new()
red:set_timeout(1000) -- 1 second timeout

local ok, err = red:connect(redis_host, redis_port)
if not ok then
    ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Define the key for rate limiting (you may want to use a more specific key)
local key = ngx.var.remote_addr

-- Check the current rate from Redis
local current_rate, err = red:get(key)
if err then
    ngx.log(ngx.ERR, "Failed to get rate from Redis: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

if current_rate == ngx.null then
    current_rate = 0
end

ngx.log(ngx.INFO, "Current rate: ", current_rate)

-- Define the rate limit threshold
local rate_limit = 10

-- Increment the rate in Redis
local new_rate = current_rate + 1
local _, err = red:set(key, new_rate)
if err then
    ngx.log(ngx.ERR, "Failed to set rate in Redis: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Set the expiration time for the key in Redis (1 minute)
local _, err = red:expire(key, 60)
if err then
    ngx.log(ngx.ERR, "Failed to set expiration for rate key in Redis: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Check if the rate exceeds the limit
if new_rate > rate_limit then
    ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
end

-- Get the last used server index from shared memory
local last_used_server_index = ngx.shared.round_robin:get("last_used_server_index") or 0

-- Calculate the next server index in round-robin fashion
local next_server_index = (last_used_server_index % 2) + 1
ngx.shared.round_robin:set("last_used_server_index", next_server_index)

-- Set the proxy_pass directive dynamically
local next_server = upstream_servers[next_server_index]
ngx.var.proxy = next_server