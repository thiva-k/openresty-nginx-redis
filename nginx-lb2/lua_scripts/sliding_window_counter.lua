local mysql = require "resty.mysql"
local cjson = require "cjson"

local db, err = mysql:new()
if not db then
    ngx.log(ngx.ERR, "Failed to instantiate mysql: ", err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

db:set_timeout(1000) -- 1 second timeout

local ok, err, errno, sqlstate = db:connect{
    host = "mysql",
    port = 3306,
    database = "rate_limits",
    user = "root",
    password = "root",
    charset = "utf8",
    max_packet_size = 1024 * 1024,
}

if not ok then
    ngx.log(ngx.ERR, "Failed to connect to MySQL: ", err, ": ", errno, " ", sqlstate)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local token_param_name = "token" -- Name of the URL parameter containing the token
local rate_limit_field = "rate_limit"
local rate_timestamps_field = "rate_timestamps"

-- Fetch the token from the URL parameter
local token = ngx.var.arg_token
if not token then
    ngx.log(ngx.ERR, "Token not provided")
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- Construct the SQL query to fetch rate limit and timestamps
local query = string.format("SELECT %s, %s FROM rate_limits WHERE token = '%s'", rate_limit_field, rate_timestamps_field, token)

local res, err, errno, sqlstate = db:query(query)
if not res then
    ngx.log(ngx.ERR, "Failed to run query: ", err, ": ", errno, " ", sqlstate)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

local default_rate_limit = 10 -- Default rate limit if not found in MySQL
local rate_limit = default_rate_limit -- Initialize rate_limit with default
local timestamps = {}

-- Check if the query returned any results
if #res > 0 then
    rate_limit = tonumber(res[1][rate_limit_field]) or default_rate_limit
    local timestamps_json = res[1][rate_timestamps_field]
    if timestamps_json then
        timestamps = cjson.decode(timestamps_json)
    end
else
    -- Insert a new record with the default rate limit and an empty timestamp array
    local initial_timestamps_json = cjson.encode({})
    local insert_query = string.format(
        "INSERT INTO rate_limits (token, %s, %s) VALUES ('%s', %d, '%s')",
        rate_limit_field, rate_timestamps_field, token, default_rate_limit, initial_timestamps_json
    )
    local insert_res, err, errno, sqlstate = db:query(insert_query)
    if not insert_res then
        ngx.log(ngx.ERR, "Failed to insert new token: ", err, ": ", errno, " ", sqlstate)
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
end

local current_time = ngx.now()
local window_size = 60 -- 1 minute window

-- Remove timestamps outside the current window
local new_timestamps = {}
for _, timestamp in ipairs(timestamps) do
    if current_time - timestamp < window_size then
        table.insert(new_timestamps, timestamp)
    end
end

-- Add the current request timestamp
table.insert(new_timestamps, current_time)

-- Check if the number of requests exceeds the rate limit
if #new_timestamps > rate_limit then
    ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
end

-- Save the updated timestamps back to MySQL
local new_timestamps_json = cjson.encode(new_timestamps)
local update_query = string.format("UPDATE rate_limits SET %s = '%s' WHERE token = '%s'", rate_timestamps_field, new_timestamps_json, token)

local res, err, errno, sqlstate = db:query(update_query)
if not res then
    ngx.log(ngx.ERR, "Failed to update query: ", err, ": ", errno, " ", sqlstate)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Set the proxy_pass directive dynamically
local upstream_servers = { "server3:8080", "server4:8080" } -- Define your upstream servers
local last_used_server_index = ngx.shared.round_robin:get(token) or 0
local next_server_index = (last_used_server_index % #upstream_servers) + 1
ngx.shared.round_robin:set(token, next_server_index)

local next_server = upstream_servers[next_server_index]
ngx.var.proxy = next_server -- Correctly set the proxy variable

-- Close the database connection
local ok, err = db:set_keepalive(10000, 100)
if not ok then
    ngx.log(ngx.ERR, "Failed to set keepalive: ", err)
end
