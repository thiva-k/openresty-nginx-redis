-- Import the Redis client library
local redis = require "resty.redis"

-- Define the Redis host and port
local redis_host = "127.0.0.1"
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

if not current_rate then
    current_rate = 0
end

-- Define the rate limit threshold
local rate_limit = 10

-- Increment the rate in Redis
current_rate = current_rate + 1
local _, err = red:set(key, current_rate)
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
if current_rate > rate_limit then
    ngx.exit(ngx.HTTP_FORBIDDEN)
    
ngx.say( " Rate available")
end
